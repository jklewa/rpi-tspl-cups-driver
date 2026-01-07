#!/bin/bash
# Test DRV to PPD compilation using ppdc

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

DRV_DIR="${DRV_DIR:-/opt/test/drv}"
OUTPUT_DIR="${OUTPUT_DIR:-/opt/test/output}"
COMPILED_PPD_DIR="${OUTPUT_DIR}/compiled_ppd"

echo "DRV Compilation Tests"
echo "====================="

mkdir -p "${COMPILED_PPD_DIR}"

TOTAL=0
PASSED=0
FAILED=0

for drv_file in "${DRV_DIR}"/*.drv; do
    ((++TOTAL))
    drv_name=$(basename "$drv_file")
    echo -n "Compiling ${drv_name}... "

    # Run ppdc
    if ppdc -d "${COMPILED_PPD_DIR}" -l en --lf -v "$drv_file" > "${OUTPUT_DIR}/${drv_name}.ppdc.log" 2>&1; then
        echo "PASS"
        ((++PASSED))

        # Validate the generated PPD with strict cupstestppd
        # -W translations: suppress missing translation warnings
        for compiled_ppd in "${COMPILED_PPD_DIR}"/*.ppd; do
            if [[ -f "$compiled_ppd" ]]; then
                compiled_name=$(basename "$compiled_ppd")
                echo -n "  Validating generated ${compiled_name}... "
                if cupstestppd -W translations "$compiled_ppd" > "${OUTPUT_DIR}/${compiled_name}.cupstestppd.log" 2>&1; then
                    echo "PASS"
                else
                    echo "FAIL"
                    grep -E "(FAIL|WARN)" "${OUTPUT_DIR}/${compiled_name}.cupstestppd.log" | head -10 | sed 's/^/    /'
                    ((++FAILED))
                fi
            fi
        done
    else
        echo "FAIL"
        ((++FAILED))
        cat "${OUTPUT_DIR}/${drv_name}.ppdc.log"
    fi
done

echo ""
echo "Results: ${PASSED}/${TOTAL} passed, ${FAILED} failed"

[[ $FAILED -eq 0 ]]
