#!/usr/bin/env python3
"""把多份 no-bot payload 追加到 nobot 的 hid.dll（NBP2 格式）。

用法:
    python make_nobot.py --stub single/hid.dll --out dist/hid.dll \
        --add 8300784:payload_cn.bin \
        --add 8276448:payload_int.bin

格式:
    hid.dll = stub + payload1 + payload2 + ... + 表 + footer(20B)
    footer = b"NBP2" + <I count> + <Q 表偏移> + <I 表长度>
    表项   = <Q 目标大小> + <Q payload 偏移> + <Q payload 长度>
"""
import argparse
import struct
import sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stub", required=True, help="未追加 payload 的 hid.dll（已追加会自动截掉）")
    ap.add_argument("--out", required=True)
    ap.add_argument("--add", action="append", default=[], metavar="SIZE:PATH",
                    help="目标原版 __data 大小 : 补丁包路径")
    args = ap.parse_args()

    if not args.add:
        print("至少需要一个 --add", file=sys.stderr)
        return 1

    raw = open(args.stub, "rb").read()
    if len(raw) > 20:
        magic = raw[-20:-16]
        if magic == b"NBP1":
            raw = raw[:struct.unpack("<Q", raw[-16:-8])[0]]
            print("已有 NBP1 payload，截断为 %d 字节" % len(raw))
        elif magic == b"NBP2":
            raw = raw[:struct.unpack("<Q", raw[-12:-4])[0]]
            print("已有 NBP2 payload，截断为 %d 字节" % len(raw))

    items = []
    for spec in args.add:
        size_s, path = spec.split(":", 1)
        size = int(size_s)
        data = open(path, "rb").read()
        if not data:
            print("payload 为空: " + path, file=sys.stderr)
            return 1
        items.append((size, data))

    body = bytearray(raw)
    table = bytearray()
    for size, data in items:
        off = len(body)
        body += data
        table += struct.pack("<QQQ", size, off, len(data))

    tbl_off = len(body)
    body += table
    footer = b"NBP2" + struct.pack("<I", len(items)) + struct.pack("<Q", tbl_off) \
             + struct.pack("<I", len(table))
    assert len(footer) == 20
    body += footer

    open(args.out, "wb").write(body)
    total = sum(len(d) for _, d in items)
    print("%s (%d 字节, payload %d 份 / %d 字节): %s"
          % (args.out, len(body), len(items), total,
             ", ".join("%d" % s for s, _ in items)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
