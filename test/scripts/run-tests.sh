#!/bin/bash
# Main test runner - orchestrates all test suites

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

# Parse arguments
RUN_PPD=false
RUN_DRV=false
RUN_FILTER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --ppd) RUN_PPD=true ;;
        --drv) RUN_DRV=true ;;
        --filter) RUN_FILTER=true ;;
        --all) RUN_PPD=true; RUN_DRV=true; RUN_FILTER=true ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Default to all tests if nothing specified
if ! $RUN_PPD && ! $RUN_DRV && ! $RUN_FILTER; then
    RUN_PPD=true
    RUN_DRV=true
    RUN_FILTER=true
fi

echo "=== TSPL CUPS Driver Test Suite ==="
echo "Architecture: ${ARCH:-native}"
echo "Date: $(date -Iseconds)"
echo ""

FAILURES=0

if $RUN_PPD; then
    echo "--- Running PPD Validation Tests ---"
    if "${SCRIPT_DIR}/test-ppd-validation.sh"; then
        echo ""
    else
        ((++FAILURES))
        echo ""
    fi
fi

if $RUN_DRV; then
    echo "--- Running DRV Compilation Tests ---"
    if "${SCRIPT_DIR}/test-drv-compilation.sh"; then
        echo ""
    else
        ((++FAILURES))
        echo ""
    fi
fi

if $RUN_FILTER; then
    echo "--- Running Filter Output Tests ---"
    if "${SCRIPT_DIR}/test-filter-output.sh"; then
        echo ""
    else
        ((++FAILURES))
        echo ""
    fi
fi

echo ""
echo "=== Test Summary ==="
if [[ $FAILURES -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "FAILED: $FAILURES test suite(s) failed"
    exit 1
fi
