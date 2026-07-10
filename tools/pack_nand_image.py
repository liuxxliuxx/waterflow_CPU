#!/usr/bin/env python3
"""Prepare a raw LoongArch image for the NAND boot loader.

The output contains only NAND main-area bytes. Program it starting at NAND
data-page offset zero (or the chosen --start-word offset); do not insert OOB
bytes between 2 KiB pages.
"""

from __future__ import annotations

import argparse
from pathlib import Path


PAGE_BYTES = 2048


def parse_number(value: str) -> int:
    return int(value, 0)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="raw little-endian program binary")
    parser.add_argument("output", type=Path, help="NAND main-area image")
    parser.add_argument(
        "--start-word",
        type=parse_number,
        default=0,
        help="NAND word index used by BOOT_NAND_START_WORD (default: 0)",
    )
    parser.add_argument(
        "--word-count",
        type=parse_number,
        help="exact BOOT_WORDS value; pads the image with 0xff",
    )
    args = parser.parse_args()

    if args.start_word < 0:
        parser.error("--start-word must be non-negative")

    image = args.input.read_bytes()
    word_bytes = (len(image) + 3) & ~3
    image = image.ljust(word_bytes, b"\xff")
    image_words = word_bytes // 4

    if args.word_count is None:
        word_count = image_words
    else:
        word_count = args.word_count
        if word_count < image_words:
            parser.error("--word-count is smaller than the input image")

    payload = image.ljust(word_count * 4, b"\xff")
    output = bytearray(args.start_word * 4)
    output.extend(payload)
    output.extend(b"\xff" * ((-len(output)) % PAGE_BYTES))
    args.output.write_bytes(output)

    print(f"image words: {image_words}")
    print(f"BOOT_NAND_START_WORD={args.start_word}")
    print(f"BOOT_WORDS={word_count}")
    print(f"output bytes: {len(output)} ({len(output) // PAGE_BYTES} NAND pages)")


if __name__ == "__main__":
    main()
