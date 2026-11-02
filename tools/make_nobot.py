#!/usr/bin/env python3
"""把 no-bot payload 追加到 nobot 的 hid.dll 里，并写入目标客户端主包大小。

用法:
    python make_nobot.py --stub single/hid.dll --payload payload_cn.bin \
        --target-size 8300784 --out dist_cn/hid.dll

原理:
    nobot 的 hid.dll = 编译产物(stub) + NBP1 footer + 内嵌 payload
    footer 结构: b"NBP1" + <Q 偏移> + <Q 长度>
    目标主包大小是 stub 里的一个 64 位常量(默认 8339710)，这里直接改掉。
"""
import argparse
import struct
import sys

DEFAULT_TARGET_SIZE = 8339710


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stub", required=True, help="未追加 payload 的 hid.dll（或已追加的也行，会自动截断）")
    ap.add_argument("--payload", required=True, help="补丁后的 __data")
    ap.add_argument("--target-size", type=int, required=True, help="目标客户端原版 __data 大小")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    raw = open(args.stub, "rb").read()
    if len(raw) > 20 and raw[-20:-16] == b"NBP1":
        off, ln = struct.unpack("<QQ", raw[-16:])
        if off + ln <= len(raw):
            raw = raw[:off]
            print("已有 payload，已截断为 %d 字节" % off)

    old = struct.pack("<Q", DEFAULT_TARGET_SIZE)
    if raw.count(old) != 1:
        print("警告: stub 里找到 %d 处目标大小常量（期望 1 处）" % raw.count(old))
        if raw.count(old) == 0:
            print("失败: 找不到目标大小常量", file=sys.stderr)
            return 1

    stub = raw.replace(old, struct.pack("<Q", args.target_size), 1)
    payload = open(args.payload, "rb").read()
    off = len(stub)
    out = stub + payload + b"NBP1" + struct.pack("<QQ", off, len(payload))
    open(args.out, "wb").write(out)
    print("stub %d + payload %d -> %s (%d 字节), target=%d"
          % (off, len(payload), args.out, len(out), args.target_size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
