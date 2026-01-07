#!/usr/bin/env python3
"""
Fix PPD page size names to use Zebra-style convention.

Converts names like:
    w100h150/4"x6"(101.6mm x 152.4mm)
To:
    w283h425/4"x6" 101.6x152.4mm

Where w283h425 matches the actual PageSize dimensions in points.
"""

import re
import sys
from pathlib import Path


def extract_dimensions(line):
    """Extract dimensions from PageSize[XXX YYY] in a line."""
    match = re.search(r'PageSize\[(\d+)\s+(\d+)\]', line)
    if match:
        return int(match.group(1)), int(match.group(2))
    return None, None


def create_new_name(old_name, width, height, new_base=None):
    """
    Convert old name to Zebra-style.

    Old: w100h150/4"x6"(101.6mm x 152.4mm)
    New: w283h425/4"x6" 101.6x152.4mm
    """
    if new_base is None:
        new_base = f"w{width}h{height}"

    # Extract the human-readable part after /
    if '/' in old_name:
        base, label = old_name.split('/', 1)
        # Clean up the label - extract inches and mm parts
        # Format: 4"x6"(101.6mm x 152.4mm)
        # We want: 4"x6" 101.6x152.4mm

        # Extract the inch part (e.g., 4"x6")
        inch_match = re.match(r'([^(]+)', label)
        inch_part = inch_match.group(1).strip() if inch_match else ""

        # Extract mm dimensions
        mm_match = re.search(r'\((\d+\.?\d*)mm\s*x\s*(\d+\.?\d*)mm\)', label)
        if mm_match:
            mm_part = f"{mm_match.group(1)}x{mm_match.group(2)}mm"
        else:
            mm_part = ""

        # Build new label
        if inch_part and mm_part:
            new_label = f"{inch_part} {mm_part}"
        elif inch_part:
            new_label = inch_part
        else:
            new_label = label
    else:
        new_label = old_name

    return f"{new_base}/{new_label}"


def process_ppd_file(filepath):
    """Process a PPD file and fix page size names."""

    with open(filepath, 'r') as f:
        content = f.read()

    # Build mapping of old names to new names
    # Track dimensions to detect duplicates
    name_mapping = {}
    dimension_count = {}

    # First pass: count how many times each dimension appears
    for match in re.finditer(
        r'\*PageSize\s+(w\d+h\d+)/([^:]+):\s*"[^"]*PageSize\[(\d+)\s+(\d+)\]',
        content
    ):
        width = int(match.group(3))
        height = int(match.group(4))
        dim_key = f"w{width}h{height}"
        dimension_count[dim_key] = dimension_count.get(dim_key, 0) + 1

    # Second pass: build mappings, handling duplicates
    dimension_seen = {}
    for match in re.finditer(
        r'\*PageSize\s+(w\d+h\d+)/([^:]+):\s*"[^"]*PageSize\[(\d+)\s+(\d+)\]',
        content
    ):
        old_base = match.group(1)  # e.g., w100h150
        old_label = match.group(2)  # e.g., 4"x6"(101.6mm x 152.4mm)
        width = int(match.group(3))
        height = int(match.group(4))

        dim_key = f"w{width}h{height}"

        # If this dimension appears multiple times, add a suffix
        if dimension_count[dim_key] > 1:
            seen = dimension_seen.get(dim_key, 0)
            dimension_seen[dim_key] = seen + 1
            # Use a letter suffix for duplicates (a, b, c, ...)
            suffix = chr(ord('a') + seen)
            new_base = f"w{width}h{height}{suffix}"
        else:
            new_base = dim_key

        old_full = f"{old_base}/{old_label}"
        new_name = create_new_name(old_full, width, height, new_base)

        if old_base != new_base:  # Only if it needs changing
            name_mapping[old_base] = (new_base, old_label, new_name)

    if not name_mapping:
        print(f"  No changes needed for {filepath}")
        return False

    print(f"  Processing {filepath.name}:")
    print(f"    Found {len(name_mapping)} page sizes to rename")

    # Apply replacements
    new_content = content

    for old_base, (new_base, old_label, new_full_name) in sorted(
        name_mapping.items(),
        key=lambda x: -len(x[0])  # Process longer names first
    ):
        # Get the new label part
        new_label = new_full_name.split('/', 1)[1] if '/' in new_full_name else ""

        # Replace in PageSize entries
        pattern = rf'(\*PageSize\s+){old_base}/[^:]+(:)'
        replacement = rf'\g<1>{new_base}/{new_label}\2'
        new_content = re.sub(pattern, replacement, new_content)

        # Replace in PageRegion entries
        pattern = rf'(\*PageRegion\s+){old_base}/[^:]+(:)'
        replacement = rf'\g<1>{new_base}/{new_label}\2'
        new_content = re.sub(pattern, replacement, new_content)

        # Replace in ImageableArea entries
        pattern = rf'(\*ImageableArea\s+){old_base}/[^:]+(:)'
        replacement = rf'\g<1>{new_base}/{new_label}\2'
        new_content = re.sub(pattern, replacement, new_content)

        # Replace in PaperDimension entries
        pattern = rf'(\*PaperDimension\s+){old_base}/[^:]+(:)'
        replacement = rf'\g<1>{new_base}/{new_label}\2'
        new_content = re.sub(pattern, replacement, new_content)

        # Replace DefaultPageSize
        new_content = re.sub(
            rf'(\*DefaultPageSize:\s*){old_base}\b',
            rf'\g<1>{new_base}',
            new_content
        )

        # Replace DefaultPageRegion
        new_content = re.sub(
            rf'(\*DefaultPageRegion:\s*){old_base}\b',
            rf'\g<1>{new_base}',
            new_content
        )

        # Replace DefaultImageableArea
        new_content = re.sub(
            rf'(\*DefaultImageableArea:\s*){old_base}\b',
            rf'\g<1>{new_base}',
            new_content
        )

        # Replace DefaultPaperDimension
        new_content = re.sub(
            rf'(\*DefaultPaperDimension:\s*){old_base}\b',
            rf'\g<1>{new_base}',
            new_content
        )

        print(f"      {old_base} -> {new_base}")

    # Write back
    with open(filepath, 'w') as f:
        f.write(new_content)

    return True


def main():
    ppd_dir = Path(__file__).parent.parent / 'ppd'

    if not ppd_dir.exists():
        print(f"Error: PPD directory not found: {ppd_dir}")
        sys.exit(1)

    print("Fixing PPD page size names to Zebra-style convention...")
    print()

    changed = 0
    for ppd_file in sorted(ppd_dir.glob('*.ppd')):
        if process_ppd_file(ppd_file):
            changed += 1

    print()
    print(f"Done. Modified {changed} files.")


if __name__ == '__main__':
    main()
