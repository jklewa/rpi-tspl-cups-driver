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
    local ps_file="$OUTPUT_DIR/${name}.ps"
    local ras_file="$OUTPUT_DIR/${name}.ras"

    # Create test image with ImageMagick
    # Using a simple pattern that will be visible in TSPL output
    convert -size "${width_pts}x${height_pts}" \
        -gravity center \
        -font Helvetica \
        -pointsize 24 \
        xc:white \
        -fill black \
        -draw "rectangle 10,10 $((width_pts-10)),$((height_pts-10))" \
        -fill white \
        -draw "rectangle 20,20 $((width_pts-20)),$((height_pts-20))" \
        -fill black \
        -annotate +0+0 "TEST: $name" \
        "$png_file" 2>/dev/null || {
            # Fallback if font not available
            convert -size "${width_pts}x${height_pts}" \
                xc:white \
                -fill black \
                -draw "rectangle 10,10 $((width_pts-10)),$((height_pts-10))" \
                -fill white \
                -draw "rectangle 20,20 $((width_pts-20)),$((height_pts-20))" \
                "$png_file"
        }

    echo "  Created PNG: $png_file"

    # Convert PNG to PostScript
    convert "$png_file" "$ps_file"
    echo "  Created PS: $ps_file"

    # Convert PostScript to CUPS raster using Ghostscript
    # The 'cups' device creates CUPS raster format
    # We need to set page size to match the label dimensions
    gs -q -dNOPAUSE -dBATCH -dSAFER \
        -sDEVICE=cups \
        -sOutputFile="$ras_file" \
        -dDEVICEWIDTHPOINTS="$width_pts" \
        -dDEVICEHEIGHTPOINTS="$height_pts" \
        -r203 \
        "$ps_file" 2>/dev/null || {
            echo "  WARNING: Ghostscript CUPS device failed, trying ppmraw fallback"
            # Fallback: create a raw bitmap that can be used for testing
            gs -q -dNOPAUSE -dBATCH -dSAFER \
                -sDEVICE=ppmraw \
                -sOutputFile="$OUTPUT_DIR/${name}.ppm" \
                -r203 \
                -g"${width_pts}x${height_pts}" \
                "$ps_file" 2>/dev/null || true
        }

    if [[ -f "$ras_file" ]]; then
        local size=$(stat -c%s "$ras_file" 2>/dev/null || stat -f%z "$ras_file" 2>/dev/null)
        echo "  Created RAS: $ras_file ($size bytes)"
    else
        echo "  WARNING: Failed to create raster file"
    fi

    # Clean up intermediate files
    rm -f "$png_file" "$ps_file"
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
