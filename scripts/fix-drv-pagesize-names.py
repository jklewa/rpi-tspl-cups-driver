#!/usr/bin/env python3
"""
Fix DRV page size names to use Zebra-style convention.

Converts CustomMedia names like:
    w100h150/4"x6"(101.6mm x 152.4mm)
To:
    w288h432/4"x6" 101.6x152.4mm

Where w288h432 matches the actual dimensions in points.
"""

import re
import sys
from pathlib import Path


def process_drv_file(filepath):
    """Process a DRV file and fix page size names."""

    with open(filepath, 'r') as f:
        content = f.read()

    lines = content.split('\n')

    # First pass: count dimensions for duplicate detection
    dimension_count = {}
    for line in lines:
        match = re.match(
            r'^(\s*\*?CustomMedia\s+)"(w\d+h\d+)/((?:[^"\\]|\\.)*)"\s+(\d+\.?\d*)\s+(\d+\.?\d*)\s+(.*)$',
            line
        )
        if match:
            width = int(float(match.group(4)))
            height = int(float(match.group(5)))
            dim_key = f"w{width}h{height}"
            dimension_count[dim_key] = dimension_count.get(dim_key, 0) + 1

    # Second pass: apply changes
    new_lines = []
    dimension_seen = {}

    for line in lines:
        # Match CustomMedia lines (note: quotes may be escaped as \" in DRV files)
        match = re.match(
            r'^(\s*\*?CustomMedia\s+)"(w\d+h\d+)/((?:[^"\\]|\\.)*)"\s+(\d+\.?\d*)\s+(\d+\.?\d*)\s+(.*)$',
            line
        )
        if match:
            prefix = match.group(1)
            old_name = match.group(2)  # e.g., w100h150
            old_label = match.group(3)  # e.g., 4"x6"(101.6mm x 152.4mm)
            width = int(float(match.group(4)))
            height = int(float(match.group(5)))
            rest = match.group(6)

            dim_key = f"w{width}h{height}"

            # Handle duplicates with suffix
            if dimension_count[dim_key] > 1:
                seen = dimension_seen.get(dim_key, 0)
                dimension_seen[dim_key] = seen + 1
                suffix = chr(ord('a') + seen)
                new_name = f"w{width}h{height}{suffix}"
            else:
                new_name = dim_key

            # Clean up the label
            # From: 4\"x6\"(101.6mm x 152.4mm)
            # To: 4\"x6\" 101.6x152.4mm

            # Extract inch part (handle escaped quotes)
            inch_match = re.match(r'((?:[^(\\]|\\.)+)', old_label)
            inch_part = inch_match.group(1).strip() if inch_match else ""

            # Extract mm dimensions
            mm_match = re.search(r'\((\d+\.?\d*)mm\s*x\s*(\d+\.?\d*)mm\)', old_label)
            if mm_match:
                mm_part = f"{mm_match.group(1)}x{mm_match.group(2)}mm"
            else:
                mm_part = ""

            if inch_part and mm_part:
                new_label = f"{inch_part} {mm_part}"
            elif inch_part:
                new_label = inch_part
            else:
                new_label = old_label

            new_line = f'{prefix}"{new_name}/{new_label}" {match.group(4)} {match.group(5)} {rest}'
            new_lines.append(new_line)

            if old_name != new_name:
                print(f"    {old_name} -> {new_name}")
        else:
            new_lines.append(line)

    new_content = '\n'.join(new_lines)

    # Write back
    with open(filepath, 'w') as f:
        f.write(new_content)

    return content != new_content


def main():
    drv_dir = Path(__file__).parent.parent / 'drv'

    if not drv_dir.exists():
        print(f"Error: DRV directory not found: {drv_dir}")
        sys.exit(1)

    print("Fixing DRV page size names to Zebra-style convention...")
    print()

    changed = 0
    for drv_file in sorted(drv_dir.glob('*.drv')):
        print(f"  Processing {drv_file.name}:")
        if process_drv_file(drv_file):
            changed += 1

    print()
    print(f"Done. Modified {changed} files.")


if __name__ == '__main__':
    main()
