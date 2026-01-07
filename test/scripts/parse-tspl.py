#!/usr/bin/env python3
"""
TSPL Output Parser and Validator

Parses TSPL command output from the raster-tspl filter and validates
the command structure and values.
"""

import sys
import json
import re
from dataclasses import dataclass, asdict, field
from typing import Optional, List, Dict, Any

@dataclass
class TSPLOutput:
    """Parsed TSPL output structure"""
    size: Optional[Dict[str, Any]] = None
    reference: Optional[Dict[str, int]] = None
    direction: Optional[int] = None
    gap: Optional[Dict[str, Any]] = None
    bline: Optional[Dict[str, Any]] = None
    density: Optional[int] = None
    speed: Optional[int] = None
    offset: Optional[int] = None
    cls: bool = False
    bitmap: Optional[Dict[str, Any]] = None
    print_cmd: Optional[Dict[str, int]] = None
    raw_commands: List[str] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)

def parse_size(line: str) -> Optional[Dict[str, Any]]:
    """Parse SIZE command: SIZE 101 mm,152 mm"""
    match = re.match(r'SIZE\s+(\d+(?:\.\d+)?)\s*(mm|dots?)?,\s*(\d+(?:\.\d+)?)\s*(mm|dots?)?', line)
    if match:
        return {
            'width': float(match.group(1)),
            'width_unit': match.group(2) or 'dots',
            'height': float(match.group(3)),
            'height_unit': match.group(4) or 'dots'
        }
    return None

def parse_reference(line: str) -> Optional[Dict[str, int]]:
    """Parse REFERENCE command: REFERENCE x,y"""
    match = re.match(r'REFERENCE\s+(-?\d+),\s*(-?\d+)', line)
    if match:
        return {'x': int(match.group(1)), 'y': int(match.group(2))}
    return None

def parse_direction(line: str) -> Optional[int]:
    """Parse DIRECTION command: DIRECTION 0|1"""
    match = re.match(r'DIRECTION\s+(\d+)', line)
    if match:
        return int(match.group(1))
    return None

def parse_gap(line: str) -> Optional[Dict[str, Any]]:
    """Parse GAP command: GAP 3 mm,0 mm"""
    match = re.match(r'GAP\s+(\d+(?:\.\d+)?)\s*(mm|dots?)?,\s*(\d+(?:\.\d+)?)\s*(mm|dots?)?', line)
    if match:
        return {
            'height': float(match.group(1)),
            'height_unit': match.group(2) or 'dots',
            'offset': float(match.group(3)),
            'offset_unit': match.group(4) or 'dots'
        }
    return None

def parse_bline(line: str) -> Optional[Dict[str, Any]]:
    """Parse BLINE command: BLINE 3 mm,0 mm"""
    match = re.match(r'BLINE\s+(\d+(?:\.\d+)?)\s*(mm|dots?)?,\s*(\d+(?:\.\d+)?)\s*(mm|dots?)?', line)
    if match:
        return {
            'height': float(match.group(1)),
            'height_unit': match.group(2) or 'dots',
            'offset': float(match.group(3)),
            'offset_unit': match.group(4) or 'dots'
        }
    return None

def parse_density(line: str) -> Optional[int]:
    """Parse DENSITY command: DENSITY n"""
    match = re.match(r'DENSITY\s+(\d+)', line)
    if match:
        return int(match.group(1))
    return None

def parse_speed(line: str) -> Optional[int]:
    """Parse SPEED command: SPEED n"""
    match = re.match(r'SPEED\s+(\d+)', line)
    if match:
        return int(match.group(1))
    return None

def parse_offset(line: str) -> Optional[int]:
    """Parse OFFSET command: OFFSET n"""
    match = re.match(r'OFFSET\s+(-?\d+)', line)
    if match:
        return int(match.group(1))
    return None

def parse_bitmap(line: str) -> Optional[Dict[str, Any]]:
    """Parse BITMAP command header: BITMAP x,y,width,height,mode,..."""
    match = re.match(r'BITMAP\s+(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)', line)
    if match:
        return {
            'x': int(match.group(1)),
            'y': int(match.group(2)),
            'width_bytes': int(match.group(3)),
            'height': int(match.group(4)),
            'mode': int(match.group(5))
        }
    return None

def parse_print(line: str) -> Optional[Dict[str, int]]:
    """Parse PRINT command: PRINT sets,copies"""
    match = re.match(r'PRINT\s+(\d+),\s*(\d+)', line)
    if match:
        return {'sets': int(match.group(1)), 'copies': int(match.group(2))}
    return None

def parse_tspl_output(content: bytes) -> TSPLOutput:
    """Parse complete TSPL output"""
    result = TSPLOutput()

    # TSPL commands are typically ASCII, but there may be binary bitmap data
    # Try to decode text commands up to first binary data
    try:
        # Split on BITMAP command to separate text from binary
        text_portion = content.split(b'BITMAP')[0].decode('utf-8', errors='replace')
        lines = text_portion.strip().split('\n')
    except Exception as e:
        result.errors.append(f"Failed to decode output: {e}")
        return result

    for line in lines:
        line = line.strip()
        if not line:
            continue

        result.raw_commands.append(line)

        if line.startswith('SIZE'):
            result.size = parse_size(line)
        elif line.startswith('REFERENCE'):
            result.reference = parse_reference(line)
        elif line.startswith('DIRECTION'):
            result.direction = parse_direction(line)
        elif line.startswith('GAP'):
            result.gap = parse_gap(line)
        elif line.startswith('BLINE'):
            result.bline = parse_bline(line)
        elif line.startswith('DENSITY'):
            result.density = parse_density(line)
        elif line.startswith('SPEED'):
            result.speed = parse_speed(line)
        elif line.startswith('OFFSET'):
            result.offset = parse_offset(line)
        elif line == 'CLS':
            result.cls = True

    # Parse BITMAP from binary content
    if b'BITMAP' in content:
        bitmap_match = re.search(rb'BITMAP\s+(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)', content)
        if bitmap_match:
            result.bitmap = {
                'x': int(bitmap_match.group(1)),
                'y': int(bitmap_match.group(2)),
                'width_bytes': int(bitmap_match.group(3)),
                'height': int(bitmap_match.group(4)),
                'mode': int(bitmap_match.group(5))
            }

    # Parse PRINT command (at end)
    if b'PRINT' in content:
        print_match = re.search(rb'PRINT\s+(\d+),\s*(\d+)', content)
        if print_match:
            result.print_cmd = {
                'sets': int(print_match.group(1)),
                'copies': int(print_match.group(2))
            }

    # Validate required commands
    if result.size is None:
        result.errors.append("Missing SIZE command")
    if result.print_cmd is None:
        result.errors.append("Missing PRINT command")
    if not result.cls:
        result.errors.append("Missing CLS command")

    return result

def validate_options(result: TSPLOutput, expected: Dict[str, Any]) -> List[str]:
    """Validate parsed output against expected values"""
    errors = []

    if 'density' in expected and result.density != expected['density']:
        errors.append(f"DENSITY mismatch: expected {expected['density']}, got {result.density}")

    if 'speed' in expected and result.speed != expected['speed']:
        errors.append(f"SPEED mismatch: expected {expected['speed']}, got {result.speed}")

    if 'direction' in expected and result.direction != expected['direction']:
        errors.append(f"DIRECTION mismatch: expected {expected['direction']}, got {result.direction}")

    if 'media_tracking' in expected:
        if expected['media_tracking'] == 'Gap' and result.gap is None:
            errors.append("Expected GAP command but not found")
        elif expected['media_tracking'] == 'BLine' and result.bline is None:
            errors.append("Expected BLINE command but not found")

    return errors

def main():
    if len(sys.argv) < 2:
        print("Usage: parse-tspl.py <tspl_file> [expected.json]", file=sys.stderr)
        sys.exit(1)

    tspl_file = sys.argv[1]
    expected_file = sys.argv[2] if len(sys.argv) > 2 else None

    with open(tspl_file, 'rb') as f:
        content = f.read()

    result = parse_tspl_output(content)

    # Load and validate against expected values
    if expected_file:
        with open(expected_file, 'r') as f:
            expected = json.load(f)
        validation_errors = validate_options(result, expected)
        result.errors.extend(validation_errors)

    # Output as JSON
    output = asdict(result)
    print(json.dumps(output, indent=2))

    # Exit with error if validation failed
    if result.errors:
        print(f"\nValidation errors:", file=sys.stderr)
        for error in result.errors:
            print(f"  - {error}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
