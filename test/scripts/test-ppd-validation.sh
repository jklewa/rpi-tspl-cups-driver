#!/bin/bash
# Validate PPD files using cupstestppd
# This script runs in ARM Docker containers where the filter is installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

PPD_DIR="${PPD_DIR:-/opt/test/ppd}"
OUTPUT_DIR="${OUTPUT_DIR:-/opt/test/output}"

echo "PPD Validation Tests"
echo "===================="

# Verify filter is installed (required for cupstestppd to pass)
FILTER_PATH="/usr/lib/cups/filter/raster-tspl"
if [[ ! -x "$FILTER_PATH" ]]; then
    echo "ERROR: Filter not found at $FILTER_PATH"
    echo "cupstestppd requires the filter to be installed."
    exit 1
fi
echo "Filter installed: $FILTER_PATH"
echo ""

TOTAL=0
PASSED=0
FAILED=0

for ppd_file in "${PPD_DIR}"/*.ppd; do
    ((++TOTAL))
    ppd_name=$(basename "$ppd_file")
    ppd_passed=true

    echo "Testing ${ppd_name}..."

    # Run cupstestppd strictly - should pass now that filter is installed
    # and page size dimensions are correct
    if cupstestppd -W none "$ppd_file" > "${OUTPUT_DIR}/${ppd_name}.cupstestppd.log" 2>&1; then
        echo "  cupstestppd: PASS"
    else
        echo "  cupstestppd: FAIL"
        echo "  Log output:"
        grep -E "(FAIL|WARN)" "${OUTPUT_DIR}/${ppd_name}.cupstestppd.log" | head -20 | sed 's/^/    /'
        ppd_passed=false
    fi

    # Required validation: Check required attributes
    echo -n "  cupsModelNumber 20: "
    if grep -q "^\*cupsModelNumber:\s*20" "$ppd_file"; then
        echo "OK"
    else
        echo "WARN (expected 20)"
    fi

    echo -n "  cupsFilter raster-tspl: "
    if grep -q "raster-tspl" "$ppd_file"; then
        echo "OK"
    else
        echo "FAIL"
        ppd_passed=false
    fi

    # Check for required options
    echo -n "  Darkness option: "
    if grep -q "^\*OpenUI \*Darkness" "$ppd_file"; then
        echo "OK"
    else
        echo "WARN"
    fi

    echo -n "  zePrintRate option: "
    if grep -q "^\*OpenUI \*zePrintRate" "$ppd_file"; then
        echo "OK"
    else
        echo "WARN"
    fi

    echo -n "  zeMediaTracking option: "
    if grep -q "^\*OpenUI \*zeMediaTracking" "$ppd_file"; then
        echo "OK"
    else
        echo "WARN"
    fi

    if $ppd_passed; then
        ((++PASSED))
    else
        ((++FAILED))
    fi
    echo ""
done

echo "Results: ${PASSED}/${TOTAL} passed, ${FAILED} failed"

[[ $FAILED -eq 0 ]]
