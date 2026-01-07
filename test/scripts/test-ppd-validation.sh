#!/bin/bash
# Validate PPD files using cupstestppd

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

PPD_DIR="${PPD_DIR:-/opt/test/ppd}"
OUTPUT_DIR="${OUTPUT_DIR:-/opt/test/output}"

echo "PPD Validation Tests"
echo "===================="

TOTAL=0
PASSED=0
FAILED=0

for ppd_file in "${PPD_DIR}"/*.ppd; do
    ((TOTAL++))
    ppd_name=$(basename "$ppd_file")
    echo -n "Testing ${ppd_name}... "

    # Run cupstestppd
    if cupstestppd -v "$ppd_file" > "${OUTPUT_DIR}/${ppd_name}.cupstestppd.log" 2>&1; then
        echo "PASS"
        ((PASSED++))
    else
        echo "FAIL"
        ((FAILED++))
        # Show first 10 lines of error
        head -n 10 "${OUTPUT_DIR}/${ppd_name}.cupstestppd.log"
    fi

    # Additional validation: Check required attributes
    echo -n "  Checking cupsModelNumber... "
    if grep -q "^\*cupsModelNumber:\s*20" "$ppd_file"; then
        echo "OK (20)"
    else
        echo "WARN (expected 20)"
    fi

    echo -n "  Checking cupsFilter... "
    if grep -q "raster-tspl" "$ppd_file"; then
        echo "OK"
    else
        echo "FAIL (missing raster-tspl filter)"
        ((FAILED++))
    fi

    # Check for required options
    echo -n "  Checking Darkness option... "
    if grep -q "^\*OpenUI \*Darkness" "$ppd_file"; then
        echo "OK"
    else
        echo "WARN (missing)"
    fi

    echo -n "  Checking zePrintRate option... "
    if grep -q "^\*OpenUI \*zePrintRate" "$ppd_file"; then
        echo "OK"
    else
        echo "WARN (missing)"
    fi

    echo -n "  Checking zeMediaTracking option... "
    if grep -q "^\*OpenUI \*zeMediaTracking" "$ppd_file"; then
        echo "OK"
    else
        echo "WARN (missing)"
    fi
done

echo ""
echo "Results: ${PASSED}/${TOTAL} passed, ${FAILED} failed"

[[ $FAILED -eq 0 ]]
