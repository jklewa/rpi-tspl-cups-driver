#!/bin/bash
# Common test utilities

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_pass() {
    echo -e "${GREEN}PASS${NC}: $1"
}

log_fail() {
    echo -e "${RED}FAIL${NC}: $1"
}

log_warn() {
    echo -e "${YELLOW}WARN${NC}: $1"
}

log_info() {
    echo "INFO: $1"
}

# Check if running on ARM architecture (real or emulated)
is_arm() {
    case "$(uname -m)" in
        aarch64|arm64|armv7l|armhf) return 0 ;;
        *) return 1 ;;
    esac
}

# Create temporary file and register cleanup
create_temp() {
    local prefix="${1:-test}"
    local tmpfile
    tmpfile=$(mktemp "/tmp/${prefix}.XXXXXX")
    echo "$tmpfile"
}

# Assert file contains pattern
assert_contains() {
    local file="$1"
    local pattern="$2"
    local msg="${3:-Pattern not found}"

    if grep -q "$pattern" "$file"; then
        return 0
    else
        log_fail "$msg"
        return 1
    fi
}

# Assert command succeeds
assert_success() {
    local msg="$1"
    shift

    if "$@" >/dev/null 2>&1; then
        log_pass "$msg"
        return 0
    else
        log_fail "$msg"
        return 1
    fi
}
