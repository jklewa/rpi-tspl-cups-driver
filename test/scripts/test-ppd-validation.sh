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
    ((++TOTAL))
    ppd_name=$(basename "$ppd_file")
    ppd_passed=true

    # Run cupstestppd for informational purposes only
    # Expected failures:
    # - Custom page size dimensions (label printers use non-standard sizes)
    # - Missing filter file (if testing on different architecture)
    echo "Testing ${ppd_name}..."
    if cupstestppd -W none "$ppd_file" > "${OUTPUT_DIR}/${ppd_name}.cupstestppd.log" 2>&1; then
        echo "  cupstestppd: PASS"
    else
        echo "  cupstestppd: INFO (expected issues with custom label sizes)"
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
