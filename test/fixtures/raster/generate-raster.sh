#!/bin/bash
# Generate test CUPS raster files for filter testing
#
# This script creates CUPS raster files that can be fed to the raster-tspl filter.
# It uses ImageMagick to create test images and Ghostscript to convert them to
# CUPS raster format.
#
# Usage: ./generate-raster.sh [output_dir]
#
# Requirements:
#   - ImageMagick (convert command)
#   - Ghostscript with CUPS raster support
#   - A PPD file for page size information

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"
PPD_DIR="${PPD_DIR:-/opt/test/ppd}"

echo "CUPS Raster File Generator"
echo "=========================="

# Check for required tools
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "ERROR: $1 is not installed"
        return 1
    fi
    echo "  $1: OK"
}

echo ""
echo "Checking requirements..."
MISSING=0
check_command convert || MISSING=1
check_command gs || MISSING=1

if [[ $MISSING -eq 1 ]]; then
    echo ""
    echo "Missing required tools. Install with:"
    echo "  apt-get install imagemagick ghostscript"
    exit 1
fi

echo ""
echo "Output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Find a PPD file to use for page size info
PPD_FILE=""
for ppd in "$PPD_DIR"/*.ppd "${SCRIPT_DIR}/../../ppd"/*.ppd ppd/*.ppd; do
    if [[ -f "$ppd" ]]; then
        PPD_FILE="$ppd"
        break
    fi
done

if [[ -z "$PPD_FILE" ]]; then
    echo "WARNING: No PPD file found, using default dimensions"
fi

# Generate test raster files
# Each test case creates a different pattern for validation

generate_raster() {
    local name="$1"
    local width_pts="$2"
    local height_pts="$3"
    local description="$4"

    echo ""
    echo "Generating: $name ($description)"
    echo "  Size: ${width_pts}x${height_pts} points"

    local png_file="$OUTPUT_DIR/${name}.png"
    local pdf_file="$OUTPUT_DIR/${name}.pdf"
    local ras_file="$OUTPUT_DIR/${name}.ras"

    # Create test image with ImageMagick
    # Using a simple pattern that will be visible in TSPL output
    convert -size "${width_pts}x${height_pts}" \
        xc:white \
        -fill black \
        -draw "rectangle 10,10 $((width_pts-10)),$((height_pts-10))" \
        -fill white \
        -draw "rectangle 20,20 $((width_pts-20)),$((height_pts-20))" \
        "$png_file"

    echo "  Created PNG: $png_file"

    # Convert PNG to PDF (avoids ImageMagick PS security policy)
    convert "$png_file" -page "${width_pts}x${height_pts}+0+0" "$pdf_file" 2>/dev/null || {
        echo "  WARNING: PDF conversion failed, trying direct GS approach"
    }

    # Try to convert to CUPS raster using Ghostscript
    # First try with PDF if it exists, otherwise use PNG directly
    local input_file="$pdf_file"
    [[ -f "$pdf_file" ]] || input_file="$png_file"

    echo "  Converting to CUPS raster..."

    # The 'cups' device creates CUPS raster format
    if gs -q -dNOPAUSE -dBATCH -dSAFER \
        -sDEVICE=cups \
        -sOutputFile="$ras_file" \
        -dDEVICEWIDTHPOINTS="$width_pts" \
        -dDEVICEHEIGHTPOINTS="$height_pts" \
        -r203 \
        "$input_file" 2>/dev/null; then
        :
    else
        echo "  WARNING: Ghostscript CUPS device not available"

        # Alternative: Use cupsfilter if available (converts PNG to raster)
        if command -v cupsfilter &> /dev/null && [[ -n "$PPD_FILE" ]]; then
            echo "  Trying cupsfilter..."
            if cupsfilter -p "$PPD_FILE" -m "application/vnd.cups-raster" "$png_file" > "$ras_file" 2>/dev/null; then
                echo "  Used cupsfilter"
            else
                rm -f "$ras_file"
            fi
        fi

        # If still no raster, create a minimal valid CUPS raster file
        if [[ ! -f "$ras_file" ]]; then
            echo "  Creating minimal CUPS raster file..."
            create_minimal_raster "$ras_file" "$width_pts" "$height_pts"
        fi
    fi

    if [[ -f "$ras_file" ]]; then
        local size=$(stat -c%s "$ras_file" 2>/dev/null || stat -f%z "$ras_file" 2>/dev/null)
        echo "  Created RAS: $ras_file ($size bytes)"
    else
        echo "  WARNING: Failed to create raster file"
    fi

    # Clean up intermediate files
    rm -f "$png_file" "$pdf_file"
}

# Create a minimal valid CUPS raster file for testing
# This creates a simple grayscale raster that the filter can process
create_minimal_raster() {
    local output_file="$1"
    local width_pts="$2"
    local height_pts="$3"

    # Calculate dimensions at 203 DPI
    local width_px=$(( (width_pts * 203) / 72 ))
    local height_px=$(( (height_pts * 203) / 72 ))

    # CUPS raster v2 header (sync word + page header)
    # This is a simplified version - the filter may need specific header values
    python3 - "$output_file" "$width_px" "$height_px" << 'PYTHON_SCRIPT'
import sys
import struct

output_file = sys.argv[1]
width = int(sys.argv[2])
height = int(sys.argv[3])

# CUPS Raster file format (version 2)
# Sync word: "RaS2" for little-endian
sync_word = b'RaS2'

# Page header (simplified - 1796 bytes for CUPS raster v2)
# Most fields are 0 or have reasonable defaults
header = bytearray(1796)

# MediaClass (64 bytes at offset 0)
# MediaColor (64 bytes at offset 64)
# MediaType (64 bytes at offset 128)
# OutputType (64 bytes at offset 192)

# AdvanceDistance (4 bytes at offset 256)
# AdvanceMedia (4 bytes at offset 260)
# Collate (4 bytes at offset 264)
# CutMedia (4 bytes at offset 268)
# Duplex (4 bytes at offset 272)

# HWResolution (8 bytes at offset 276) - 203x203 DPI
struct.pack_into('<II', header, 276, 203, 203)

# ImagingBoundingBox (16 bytes at offset 284)
struct.pack_into('<IIII', header, 284, 0, 0, width, height)

# Margins (8 bytes at offset 316)
# ManualFeed (4 bytes at offset 324)
# MediaPosition (4 bytes at offset 328)
# MediaWeight (4 bytes at offset 332)
# MirrorPrint (4 bytes at offset 336)
# NegativePrint (4 bytes at offset 340)
# NumCopies (4 bytes at offset 344)
struct.pack_into('<I', header, 344, 1)

# Orientation (4 bytes at offset 348)
# OutputFaceUp (4 bytes at offset 352)

# PageSize (8 bytes at offset 356) - in points
struct.pack_into('<II', header, 356, width * 72 // 203, height * 72 // 203)

# Separations (4 bytes at offset 364)
# TraySwitch (4 bytes at offset 368)
# Tumble (4 bytes at offset 372)

# cupsWidth (4 bytes at offset 376)
struct.pack_into('<I', header, 376, width)

# cupsHeight (4 bytes at offset 380)
struct.pack_into('<I', header, 380, height)

# cupsMediaType (4 bytes at offset 384)
# cupsBitsPerColor (4 bytes at offset 388)
struct.pack_into('<I', header, 388, 8)

# cupsBitsPerPixel (4 bytes at offset 392)
struct.pack_into('<I', header, 392, 8)

# cupsBytesPerLine (4 bytes at offset 396)
struct.pack_into('<I', header, 396, width)

# cupsColorOrder (4 bytes at offset 400) - chunky
# cupsColorSpace (4 bytes at offset 404) - grayscale (3)
struct.pack_into('<I', header, 404, 3)

# cupsCompression (4 bytes at offset 408)
# cupsRowCount (4 bytes at offset 412)
# cupsRowFeed (4 bytes at offset 416)
# cupsRowStep (4 bytes at offset 420)

# cupsNumColors (4 bytes at offset 424)
struct.pack_into('<I', header, 424, 1)

# Remaining fields are 0

# Create simple grayscale image data (white background with black border)
row_data = bytearray(width)
for x in range(width):
    if x < 10 or x >= width - 10:
        row_data[x] = 0  # Black border
    else:
        row_data[x] = 255  # White interior

# Write the file
with open(output_file, 'wb') as f:
    f.write(sync_word)
    f.write(header)
    for y in range(height):
        if y < 10 or y >= height - 10:
            # Black row for top/bottom border
            f.write(bytes([0] * width))
        else:
            f.write(row_data)

print(f"  Created minimal raster: {width}x{height} pixels")
PYTHON_SCRIPT
}

# Common label sizes (width x height in points, 1 inch = 72 points)
# 4x6 inch label (common shipping label)
generate_raster "4x6-label" 288 432 "4x6 inch shipping label"

# 2x1 inch label (common product label)
generate_raster "2x1-label" 144 72 "2x1 inch product label"

# 100x150mm label (common European shipping)
# 100mm = 283 points, 150mm = 425 points
generate_raster "100x150mm-label" 283 425 "100x150mm shipping label"

echo ""
echo "Generation complete!"
echo ""

# List generated files
echo "Generated files:"
ls -la "$OUTPUT_DIR"/*.ras 2>/dev/null || echo "  (no .ras files generated)"

echo ""
echo "To run filter tests with these files, use:"
echo "  ./test/scripts/run-tests.sh --filter"
