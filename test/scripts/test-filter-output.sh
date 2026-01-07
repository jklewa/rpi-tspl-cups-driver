#!/bin/bash
# Test filter output by running cupsfilter and validating TSPL commands

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

FIXTURES_DIR="${FIXTURES_DIR:-/opt/test/fixtures}"
OUTPUT_DIR="${OUTPUT_DIR:-/opt/test/output}"
PPD_DIR="${PPD_DIR:-/opt/test/ppd}"
FILTER_PATH="/usr/lib/cups/filter/raster-tspl"

echo "Filter Output Tests"
echo "==================="

# Check filter exists and is executable
echo -n "Checking filter binary... "
if [[ -x "$FILTER_PATH" ]]; then
    echo "OK"
    file "$FILTER_PATH"
else
    echo "FAIL (not found or not executable)"
    exit 1
fi

TOTAL=0
PASSED=0
FAILED=0

echo ""
echo "Note: Filter output tests require raster input files."
echo "Run test/fixtures/raster/generate-raster.sh to create them."
echo ""

# Check if raster files exist
if [[ ! -d "${FIXTURES_DIR}/raster" ]] || [[ -z "$(ls -A "${FIXTURES_DIR}/raster"/*.ras 2>/dev/null)" ]]; then
    echo "SKIP: No raster test files found"
    echo "To generate raster files, run: test/fixtures/raster/generate-raster.sh"
    exit 0
fi

# Test case: Run filter with a PPD
run_filter_test() {
    local test_name="$1"
    local ppd_file="$2"
    local raster_file="$3"
    local options="$4"

    ((TOTAL++))
    echo ""
    echo "Test: ${test_name}"
    echo "  PPD: $(basename "$ppd_file")"
    echo "  Raster: $(basename "$raster_file")"
    echo "  Options: ${options:-default}"

    local output_file="${OUTPUT_DIR}/${test_name}.tspl"
    local log_file="${OUTPUT_DIR}/${test_name}.log"

    # Run filter directly
    # Filter invocation format: filter JOB USER TITLE COPIES OPTIONS [FILE]
    echo -n "  Running filter... "

    if PPD="$ppd_file" "$FILTER_PATH" 1 user test 1 "$options" < "$raster_file" > "$output_file" 2> "$log_file"; then
        echo "OK"
    else
        echo "FAILED (exit code $?)"
        cat "$log_file"
        ((FAILED++))
        return 1
    fi

    # Validate TSPL output structure
    echo -n "  Validating TSPL structure... "
    if python3 "${SCRIPT_DIR}/parse-tspl.py" "$output_file" > "${OUTPUT_DIR}/${test_name}.parsed.json" 2>&1; then
        echo "PASS"
        ((PASSED++))
    else
        echo "FAIL"
        cat "${OUTPUT_DIR}/${test_name}.parsed.json"
        ((FAILED++))
        return 1
    fi

    # Check specific TSPL commands
    echo "  TSPL Commands Found:"
    grep -E "^(SIZE|REFERENCE|DIRECTION|GAP|BLINE|DENSITY|SPEED|OFFSET|CLS|BITMAP|PRINT)" "$output_file" | head -10 || true
}

# Run test cases for the first PPD found
for ppd_file in "${PPD_DIR}"/*.ppd; do
    ppd_name=$(basename "$ppd_file" .ppd)

    # Only test with first available raster file
    for raster_file in "${FIXTURES_DIR}/raster"/*.ras; do
        # Test 1: Default options
        run_filter_test "${ppd_name}-default" "$ppd_file" "$raster_file" ""
        break  # Only test with one raster file per PPD
    done

    break  # Only test with one PPD for now
done

echo ""
echo "Results: ${PASSED}/${TOTAL} passed, ${FAILED} failed"

[[ $FAILED -eq 0 ]]
