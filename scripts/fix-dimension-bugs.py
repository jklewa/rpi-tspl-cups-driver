#!/usr/bin/env python3
"""
Fix pre-existing dimension bugs in PPD files.

These entries have incorrect names - they use 4" or 3" point dimensions
but are actually 2.5" or 2.75" labels:

- w213h90b/2.75"x1.25" should be w197h90 with PageSize[197 90]
- w283h142b/2.5"x2" should be w179h142 with PageSize[179 142]
- w283h71b/2.5"x1" should be w179h71 with PageSize[179 71]

In sp310/sp320 (no 4" labels):
- w283h142/2.5"x2" should be w179h142 with PageSize[179 142]
- w283h71/2.5"x1" should be w179h71 with PageSize[179 71]
"""

import re
import sys
from pathlib import Path


# Mapping of incorrect -> correct entries
FIXES = {
    # Pattern: (old_name_base, old_label_pattern, new_name_base, new_dimensions)
    # For entries with "b" suffix (in PPDs that have both 4" and 2.5" labels)
    (r'w213h90b', r'2\.75"x1\.25"'): ('w197h90', '197 90'),
    (r'w283h142b', r'2\.5"x2"'): ('w179h142', '179 142'),
    (r'w283h71b', r'2\.5"x1"'): ('w179h71', '179 71'),
    # For entries without "b" suffix (in PPDs that only have 2.5" labels)
    (r'w283h142(?!a|b)', r'2\.5"x2"'): ('w179h142', '179 142'),
    (r'w283h71(?!a|b)', r'2\.5"x1"'): ('w179h71', '179 71'),
}


def fix_ppd_file(filepath):
    """Fix dimension bugs in a PPD file."""
    with open(filepath, 'r') as f:
        content = f.read()

    original = content

    for (old_name_pattern, label_pattern), (new_name, new_dims) in FIXES.items():
        # Fix *PageSize entries
        pattern = rf'(\*PageSize\s+){old_name_pattern}(/[^:]*{label_pattern}[^:]*:.*PageSize\[)\d+ \d+(\])'
        content = re.sub(pattern, rf'\g<1>{new_name}\g<2>{new_dims}\g<3>', content)

        # Fix *PageRegion entries
        pattern = rf'(\*PageRegion\s+){old_name_pattern}(/[^:]*{label_pattern}[^:]*:.*PageSize\[)\d+ \d+(\])'
        content = re.sub(pattern, rf'\g<1>{new_name}\g<2>{new_dims}\g<3>', content)

        # Fix *ImageableArea entries
        pattern = rf'(\*ImageableArea\s+){old_name_pattern}(/[^:]*{label_pattern}[^:]*:)'
        content = re.sub(pattern, rf'\g<1>{new_name}\g<2>', content)

        # Fix *PaperDimension entries and their dimensions
        pattern = rf'(\*PaperDimension\s+){old_name_pattern}(/[^:]*{label_pattern}[^:]*:\s*")(\d+) (\d+)'
        content = re.sub(pattern, rf'\g<1>{new_name}\g<2>{new_dims}', content)

        # Fix *DefaultPageSize
        pattern = rf'(\*DefaultPageSize:\s*){old_name_pattern}\b'
        content = re.sub(pattern, rf'\g<1>{new_name}', content)

        # Fix *DefaultPageRegion
        pattern = rf'(\*DefaultPageRegion:\s*){old_name_pattern}\b'
        content = re.sub(pattern, rf'\g<1>{new_name}', content)

        # Fix *DefaultImageableArea
        pattern = rf'(\*DefaultImageableArea:\s*){old_name_pattern}\b'
        content = re.sub(pattern, rf'\g<1>{new_name}', content)

        # Fix *DefaultPaperDimension
        pattern = rf'(\*DefaultPaperDimension:\s*){old_name_pattern}\b'
        content = re.sub(pattern, rf'\g<1>{new_name}', content)

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False


def main():
    ppd_dir = Path(__file__).parent.parent / 'ppd'

    if not ppd_dir.exists():
        print(f"Error: PPD directory not found: {ppd_dir}")
        sys.exit(1)

    print("Fixing dimension bugs in PPD files...")
    print()

    changed = 0
    for ppd_file in sorted(ppd_dir.glob('*.ppd')):
        if fix_ppd_file(ppd_file):
            print(f"  Fixed: {ppd_file.name}")
            changed += 1

    print()
    print(f"Done. Modified {changed} files.")


if __name__ == '__main__':
    main()
