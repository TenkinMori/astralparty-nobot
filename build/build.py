#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
NoBotStarter 生成脚本

自动定位 RoomWaitPanel 里所有 RequestStartGameC2S 调用点的 ldc.i4.1，
把前一个常量改成 0（即 IsAddBot = false）。

适配性设计：
  - 不写死方法名（<RequsetStart>b__16_0 是编译器生成的，游戏更新可能变）
  - 而是扫描整个程序集，找所有调用 RequestStartGameC2S 的方法
  - 在调用点前 1~4 条指令里找 ldc.i4（不管 true 还是 false 都归一成 false）

用法:
    python build.py                    # 使用默认路径
    python build.py --refdll <dll>     # 指定参考 DLL
    python build.py --out <bundle>     # 指定输出 bundle 路径
"""
import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.dirname(HERE)

# 默认路径
DEFAULT_REFLIVE = r"<本地项目目录>\work\live_refs\AstralParty.Runtime.dll"
DEFAULT_ORIG = (r"D:\steam\steamapps\common\Astral Party\8vJXn6CN\AstralParty_CN_Data"
                r"\com.unity.addressables\AssetBundles"
                r"\57a198703b66364d5420d39c0d251747\3486f99276eba77677d4880fd8d32918\__data.apa-orig")
DEFAULT_TOOLS = r"<旧 Extra 目录>\tools"
DEFAULT_DLLPATCH = os.path.join(DEFAULT_TOOLS, "dllpatch", "src", "bin", "Release", "net9.0", "dllpatch.exe")


def find_targets(refdll):
    """扫描程序集，找出所有 RequestStartGameC2S 调用点及其常量。"""
    cmd = _probe_exe()
    if cmd is None:
        print("[!] 找不到探针程序，跳过自动定位（使用保守方案）")
        return None
    out = subprocess.run([cmd, refdll], capture_output=True, text=True, encoding="utf-8")
    if out.returncode != 0:
        print("[!] 探针执行失败:", out.stderr[:300])
        return None
    targets = []
    for line in out.stdout.splitlines():
        line = line.strip()
        if line.startswith("TARGET\t"):
            _, typ, meth, offset, const = line.split("\t")
            targets.append((typ, meth, offset, const))
    return targets


def _probe_exe():
    """找或编译 IL 探针。"""
    probe_src = os.path.join(HERE, "src", "Probe.cs")
    probe_proj = os.path.join(HERE, "src", "Probe.csproj")
    probe_exe = os.path.join(HERE, "src", "bin", "Release", "net9.0", "Probe.dll")
    if not os.path.exists(probe_src):
        return None
    if os.path.exists(probe_exe):
        return probe_exe
    # 编译
    print("[*] 编译 IL 探针...")
    r = subprocess.run(["dotnet", "build", probe_proj, "-c", "Release", "--nologo", "-v", "q"],
                       cwd=os.path.join(HERE, "src"), capture_output=True, text=True)
    if r.returncode != 0:
        print("[!] 编译失败:", (r.stdout + r.stderr)[-500:])
        return None
    return probe_exe if os.path.exists(probe_exe) else None


def build_spec(targets):
    """根据目标生成 dllpatch spec。"""
    swaps = []
    if targets:
        for typ, meth, offset, const in targets:
            # 每个方法里的 ldc.i4.1 只有一个（用于 IsAddBot）
            swaps.append({
                "Type": typ,
                "Method": meth,
                "From": int(const),
                "To": 0,
                "Occurrence": 1,
            })
    else:
        # 保守方案：按已知方法名
        for m in ("<RequsetStart>b__16_0", "<RequsetStart>b__16_1"):
            swaps.append({
                "Type": "UI.RoomWaitPanel",
                "Method": m,
                "From": 1,
                "To": 0,
                "Occurrence": 1,
            })

    import json
    spec = {
        "_说明": "NoBotStarter：开房间不补 Bot，点开始直接开始",
        "ConstSwaps": swaps,
    }
    return json.dumps(spec, ensure_ascii=False, indent=2), len(swaps)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--refdll", default=DEFAULT_REFLIVE)
    ap.add_argument("--orig", default=DEFAULT_ORIG)
    ap.add_argument("--tools", default=DEFAULT_TOOLS)
    ap.add_argument("--dllpatch", default=DEFAULT_DLLPATCH)
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    if not os.path.exists(args.refdll):
        print("[!] 参考 DLL 不存在:", args.refdll)
        return 1
    if not os.path.exists(args.orig):
        print("[!] 原版 bundle 不存在:", args.orig)
        return 1
    if not os.path.exists(args.dllpatch):
        print("[!] dllpatch 不存在:", args.dllpatch)
        return 1

    out_dir = os.path.join(HERE, "out")
    os.makedirs(out_dir, exist_ok=True)

    print("[1/4] 扫描目标方法...")
    targets = find_targets(args.refdll)
    if targets:
        print("    找到 %d 个调用点:" % len(targets))
        for t in targets:
            print("      %s::%s  %s  const=%s" % t)
    else:
        print("    未找到，使用保守方案（按已知方法名）")

    print("[2/4] 生成 spec...")
    spec, n = build_spec(targets)
    spec_path = os.path.join(out_dir, "spec_nobot.json")
    with open(spec_path, "w", encoding="utf-8") as f:
        f.write(spec)
    print("    补丁 %d 处 -> %s" % (n, spec_path))

    print("[3/4] 打补丁...")
    patched_dll = os.path.join(out_dir, "AstralParty.Runtime.dll")
    work_dir = os.path.join(r"<旧 Extra 目录>\work", "nobot")
    os.makedirs(work_dir, exist_ok=True)
    patched_dll = os.path.join(work_dir, "AstralParty.Runtime.dll")
    if os.path.exists(patched_dll):
        os.remove(patched_dll)
    r = subprocess.run([args.dllpatch, "apply", args.refdll, patched_dll, spec_path],
                       capture_output=True, text=True, encoding="utf-8")
    out = r.stdout + r.stderr
    for line in out.splitlines():
        if "ConstSwap" in line or "wrote" in line or "FATAL" in line:
            print("    " + line.strip())
    if r.returncode != 0:
        print("[!] 打补丁失败")
        return 1

    print("[4/4] 打包 bundle...")
    sys.path.insert(0, args.tools)
    import bundle  # noqa: E402
    out_bundle = args.out or os.path.join(out_dir, "NoBotStarter.hotfix__data")
    with open(patched_dll, "rb") as f:
        dll_bytes = f.read()
    bundle.write_dll(args.orig, dll_bytes, out_bundle, "AstralParty.Runtime.dll")
    print("    -> %s (%d 字节)" % (out_bundle, os.path.getsize(out_bundle)))

    print()
    print("完成。安装方法：")
    print("  1. 把 %s" % out_bundle)
    print("     复制到 游戏目录\\AstralPartyExtra\\NoBotStarter.hotfix__data")
    print("  2. 运行 install.py 完成安装（会自动备份原版）")
    return 0


if __name__ == "__main__":
    sys.exit(main())