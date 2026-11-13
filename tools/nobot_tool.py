# -*- coding: utf-8 -*-
"""NoBot 独立工具 —— 自动识别当前客户端的热更包大小，生成对应的 hid.dll。

用法：
    python tools\\nobot_tool.py [--game <游戏目录>] [--stub dist\\hid.dll]
                               [--out dist\\hid.dll] [--install] [--no-patch] [--keep-all]

流程：
  1. 找游戏目录（--game / 常见 Steam 路径 / steamapps 扫描）
  2. 在 Addressables 缓存里按**内容**找当前这颗热更 __data
     （bundle 里含 TextAsset `AstralParty.Runtime.dll`）
  3. 读出它的字节大小 —— hid.dll 就是要匹配这个大小
  4. 抽出 Runtime.dll，用内置 dllpatch + `nobot_patch.json` 把两处常量 1→0
  5. 换回 bundle 得到 payload
  6. 重建 hid.dll（保留其它服务器的 payload，替换同尺寸那份；NBP2）
  7. --install 时装进游戏根目录（自动备份旧 hid.dll）

依赖：Python 3.9+、UnityPy、.NET 9 运行时（跑内置 dllpatch；仅生成时需要）。
"""
import argparse
import os
import shutil
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


# ---------------------------------------------------------------- UnityPy
def _load_unitypy():
    try:
        import UnityPy  # noqa
        return UnityPy
    except ImportError:
        pass
    cands = [
        os.path.join(ROOT, "pylibs"),
        os.path.join(HERE, "pylibs"),
        r"C:\Users\DELL\Documents\AstralParty Extra\work\pylibs",
    ]
    for p in cands:
        if os.path.isdir(p) and p not in sys.path:
            sys.path.insert(0, p)
    import UnityPy  # noqa
    return UnityPy


UnityPy = _load_unitypy()


def find_tool(name):
    """dllpatch 位置：优先内置 tools/dllpatch，其次隔壁 Extra 工程。"""
    cands = [
        os.path.join(HERE, "dllpatch", name),
        r"C:\Users\DELL\Documents\AstralParty Extra\tools\dllpatch\src\bin\Release\net9.0" + os.sep + name,
    ]
    for p in cands:
        if os.path.isfile(p):
            return p
    return None


# ---------------------------------------------------------------- bundle
def text_asset_names(path):
    names = set()
    try:
        env = UnityPy.load(path)
        for obj in env.objects:
            if obj.type.name != "TextAsset":
                continue
            try:
                names.add(obj.read().m_Name or "")
            except Exception:
                pass
    except Exception:
        pass
    return names


def find_hotfix(game_dir):
    roots = [
        os.path.join(game_dir, "AstralParty_CN_Data", "com.unity.addressables"),
        os.path.join(game_dir, "AstralParty_INT_Data", "com.unity.addressables"),
        os.path.join(os.environ.get("USERPROFILE", ""), "AppData", "LocalLow", "feimo",
                     "AstralParty_CN", "com.unity.addressables"),
        os.path.join(os.environ.get("USERPROFILE", ""), "AppData", "LocalLow", "feimo",
                     "AstralParty_INT", "com.unity.addressables"),
    ]
    cands = []
    for root in roots:
        if not os.path.isdir(root):
            continue
        for dp, _dn, fns in os.walk(root):
            for fn in fns:
                if fn != "__data":
                    continue
                try:
                    sz = os.path.getsize(os.path.join(dp, fn))
                except OSError:
                    continue
                if (4 << 20) <= sz <= (24 << 20):
                    cands.append((os.path.getmtime(os.path.join(dp, fn)), sz, os.path.join(dp, fn)))
    cands.sort(reverse=True)
    for _mt, sz, p in cands:
        if "AstralParty.Runtime.dll" in text_asset_names(p):
            return p, sz
    return None, None


def read_dll(bundle):
    env = UnityPy.load(bundle)
    for obj in env.objects:
        if obj.type.name != "TextAsset":
            continue
        d = obj.read()
        if (d.m_Name or "") == "AstralParty.Runtime.dll":
            raw = d.m_Script
            return raw.encode("utf-8", "surrogateescape") if isinstance(raw, str) else bytes(raw)
    raise RuntimeError("bundle 里没有 AstralParty.Runtime.dll")


def write_payload(stock, dll_bytes, out):
    env = UnityPy.load(stock)
    hit = 0
    for obj in env.objects:
        if obj.type.name != "TextAsset":
            continue
        d = obj.read()
        if (d.m_Name or "") == "AstralParty.Runtime.dll":
            d.m_Script = dll_bytes.decode("utf-8", "surrogateescape")
            d.save()
            hit += 1
    if hit != 1:
        raise RuntimeError("DLL 命中 %d 次（应为 1）" % hit)
    data = env.file.save(packer="lz4")
    raw = bytes(list(data.values())[0]) if isinstance(data, dict) else bytes(data)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    open(out, "wb").write(raw)
    return out


def extract_all_dlls(bundle, outdir):
    """把 bundle 里 18 个 TextAsset（热更 DLL）全部抽到同一目录，Cecil 解析引用要用。"""
    env = UnityPy.load(bundle)
    os.makedirs(outdir, exist_ok=True)
    names = []
    for obj in env.objects:
        if obj.type.name != "TextAsset":
            continue
        d = obj.read()
        nm = d.m_Name or ""
        raw = d.m_Script
        raw = raw.encode("utf-8", "surrogateescape") if isinstance(raw, str) else bytes(raw)
        open(os.path.join(outdir, nm), "wb").write(raw)
        names.append(nm)
    return sorted(names)


# ---------------------------------------------------------------- patch
def patch_dll(src_dll, dst_dll):
    """用内置 dllpatch + nobot_patch.json 打补丁。"""
    exe = find_tool("dllpatch.exe")
    if not exe:
        raise RuntimeError("找不到 dllpatch.exe（需要 .NET 9）。可以放到 tools/dllpatch/ 下。")
    spec = os.path.join(HERE, "nobot_patch.json")
    r = subprocess.run([exe, "apply", src_dll, dst_dll, spec],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise RuntimeError("dllpatch 失败：\n" + (r.stdout or "") + (r.stderr or ""))
    return r.stdout.strip()


# ---------------------------------------------------------------- hid.dll
def parse_nbp(raw):
    if len(raw) < 20 or raw[-20:-16] != b"NBP2":
        return []
    cnt = struct.unpack_from("<I", raw, len(raw) - 16)[0]
    toff = struct.unpack_from("<Q", raw, len(raw) - 12)[0]
    out = []
    for i in range(cnt):
        sz, off, ln = struct.unpack_from("<QQQ", raw, toff + 24 * i)
        out.append((sz, raw[off:off + ln]))
    return out


def strip_nbp(raw):
    """去掉已有 NBP2 payload，只留裸 DLL（否则重建会把旧 payload 再包一层）。"""
    if len(raw) < 20 or raw[-20:-16] != b"NBP2":
        return raw
    cnt = struct.unpack_from("<I", raw, len(raw) - 16)[0]
    toff = struct.unpack_from("<Q", raw, len(raw) - 12)[0]
    offs = [struct.unpack_from("<Q", raw, toff + 24 * i + 8)[0] for i in range(cnt)]
    return raw[:min(offs)] if offs else raw[:toff]


def build_hid(stub_bytes, items, out):
    items = sorted(items, key=lambda kv: kv[0])
    body = bytearray(stub_bytes)
    table = bytearray()
    for size, data in items:
        off = len(body)
        body += data
        table += struct.pack("<QQQ", size, off, len(data))
    toff = len(body)
    body += table
    body += b"NBP2" + struct.pack("<I", len(items)) + struct.pack("<Q", toff) + struct.pack("<I", len(table))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    open(out, "wb").write(body)
    return out


def game_running():
    try:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq AstralParty_CN.exe", "/NH"],
                             capture_output=True, text=True, timeout=15).stdout
        return "AstralParty_CN.exe" in out
    except Exception:
        return False


def find_game():
    for p in (r"D:\Steam\steamapps\common\Astral Party\8vJXn6CN",
              r"D:\steam\steamapps\common\Astral Party\8vJXn6CN"):
        if os.path.isfile(os.path.join(p, "AstralParty_CN.exe")):
            return p
    for root in (r"D:\Steam\steamapps\common", r"C:\Program Files (x86)\Steam\steamapps\common"):
        if not os.path.isdir(root):
            continue
        for name in os.listdir(root):
            base = os.path.join(root, name)
            if not os.path.isdir(base) or "astral" not in name.lower():
                continue
            for sub in (base, *[os.path.join(base, d) for d in os.listdir(base)]):
                if os.path.isfile(os.path.join(sub, "AstralParty_CN.exe")):
                    return sub
    return None


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", help="游戏目录（含 AstralParty_CN.exe）")
    ap.add_argument("--stub", default=os.path.join(ROOT, "dist", "hid.dll"),
                    help="现有 hid.dll（保留其它服务器的 payload）")
    ap.add_argument("--out", default=os.path.join(ROOT, "dist", "hid.dll"))
    ap.add_argument("--install", action="store_true", help="生成后装进游戏根目录（备份旧 hid.dll）")
    ap.add_argument("--no-patch", action="store_true", help="不重新打补丁，只按检测到的尺寸重建 hid.dll")
    ap.add_argument("--keep-all", action="store_true", help="保留 stub 里全部旧 payload（默认替换同尺寸的）")
    args = ap.parse_args(argv)

    game = os.path.abspath(args.game) if args.game else find_game()
    if not game or not os.path.isfile(os.path.join(game, "AstralParty_CN.exe")):
        print("[!] 找不到游戏目录，请用 --game 指定")
        return 2
    print("[*] 游戏目录:", game)

    stock, size = find_hotfix(game)
    if not stock:
        print("[!] 没找到热更 __data。先启动一次游戏让它下载资源，再重试。")
        return 3
    print("[*] 热更包:", stock)
    print("[*] 目标尺寸:", size)

    stub = args.stub if os.path.isfile(args.stub) else (os.path.join(ROOT, "single", "hid.dll") if os.path.isfile(os.path.join(ROOT, "single", "hid.dll")) else os.path.join(ROOT, "stub", "hid.dll"))
    stub_bytes = open(stub, "rb").read()
    old = parse_nbp(stub_bytes)
    stub_base = strip_nbp(stub_bytes)
    print("[*] stub:", stub, "已有 payload:", [s for s, _ in old])

    if args.keep_all:
        items = list(old)
    else:
        items = [kv for kv in old if kv[0] != size]

    if args.no_patch:
        have = dict(old)
        if size not in have:
            print("[!] --no-patch 但 stub 里没有 %d 的 payload" % size)
            return 4
        items.append((size, have[size]))
    else:
        work = os.path.join(ROOT, "work")
        refs = os.path.join(work, "refs")
        os.makedirs(refs, exist_ok=True)
        # Cecil 解析引用需要 18 个 DLL 放在同一目录
        names = extract_all_dlls(stock, refs)
        src_dll = os.path.join(refs, "AstralParty.Runtime.dll")
        patched = os.path.join(refs, "AstralParty.Runtime.patched.dll")
        log = patch_dll(src_dll, patched)
        print("[*] 补丁:", "OK", "(%d 个参考 DLL)" % len(names))
        for line in log.splitlines():
            if "ConstSwap" in line:
                print("    " + line.strip())
        payload_path = os.path.join(work, "payload_cn_%d.bin" % size)
        write_payload(stock, open(patched, "rb").read(), payload_path)
        print("[*] payload:", payload_path, os.path.getsize(payload_path))
        items.append((size, open(payload_path, "rb").read()))

    out = build_hid(stub_base, items, args.out)
    print("[+] hid.dll:", out, os.path.getsize(out), "payloads:", [s for s, _ in items])

    if args.install:
        if game_running():
            print("[!] 游戏在运行，先关掉再装")
            return 5
        dst = os.path.join(game, "hid.dll")
        if os.path.isfile(dst):
            import time
            bak = dst + time.strftime(".bak-%Y%m%d-%H%M%S")
            os.replace(dst, bak)
            print("[*] 备份旧 hid.dll ->", bak)
        shutil.copy2(out, dst)
        print("[+] 已安装:", dst)
    return 0


if __name__ == "__main__":
    sys.exit(main())
