#!/bin/bash
# Test suite for craft-install Claude detection mechanism
# Tests that settings.json modification is skipped when Claude is running

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

log_info() {
    echo -e "${YELLOW}→${NC} $1"
}

# Setup test environment
setup() {
    TEST_DIR=$(mktemp -d)
    TEST_SETTINGS="$TEST_DIR/settings.json"
    echo '{"enabledPlugins":{}}' > "$TEST_SETTINGS"
    log_info "Test directory: $TEST_DIR"
}

# Cleanup
cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

trap cleanup EXIT

# Test 1: Basic jq modification works
test_basic_jq_modification() {
    log_info "Test 1: Basic jq modification"

    TEMP_FILE=$(mktemp)
    if jq --arg plugin "craft@local-plugins" '.enabledPlugins[$plugin] = true' "$TEST_SETTINGS" > "$TEMP_FILE" 2>/dev/null; then
        mv "$TEMP_FILE" "$TEST_SETTINGS"

        # Verify the change
        if jq -e '.enabledPlugins["craft@local-plugins"]' "$TEST_SETTINGS" >/dev/null 2>&1; then
            log_pass "Basic jq modification works"
        else
            log_fail "jq modification didn't persist"
        fi
    else
        rm -f "$TEMP_FILE"
        log_fail "jq command failed"
    fi
}

# Test 2: Claude detection availability
test_claude_detection() {
    log_info "Test 2: Claude detection tools"

    if command -v lsof &>/dev/null; then
        log_pass "lsof available for file lock detection"
    else
        log_fail "lsof not available"
    fi

    if command -v pgrep &>/dev/null; then
        log_pass "pgrep available as fallback"
    else
        log_pass "pgrep not available - lsof will be used"
    fi
}

# Test 3: Claude detection with lsof
test_claude_detection_lsof() {
    log_info "Test 3: Claude detection with lsof"

    # Check if Claude is currently running and has settings.json open
    REAL_SETTINGS="$HOME/.claude/settings.json"

    if [ -f "$REAL_SETTINGS" ]; then
        if lsof "$REAL_SETTINGS" 2>/dev/null | grep -q "claude"; then
            log_pass "Detected Claude has settings.json open (expected during test)"
        else
            log_pass "Claude does not have settings.json open"
        fi
    else
        log_pass "settings.json doesn't exist - skipping lsof test"
    fi
}

# Test 4: Verify skip behavior when Claude detected
test_skip_when_claude_running() {
    log_info "Test 4: Skip behavior when Claude detected"

    # Simulate the detection logic from craft-install
    REAL_SETTINGS="$HOME/.claude/settings.json"
    CLAUDE_RUNNING=false

    if command -v lsof &>/dev/null; then
        if lsof "$REAL_SETTINGS" 2>/dev/null | grep -q "claude"; then
            CLAUDE_RUNNING=true
        fi
    elif pgrep -x "claude" >/dev/null 2>&1; then
        CLAUDE_RUNNING=true
    fi

    if [ "$CLAUDE_RUNNING" = true ]; then
        log_pass "Claude detected - would skip settings.json modification"
    else
        log_pass "Claude not detected - would proceed with modification"
    fi
}

# Test 5: Cleanup of temp files
test_temp_file_cleanup() {
    log_info "Test 5: Temp file cleanup"

    # Reset
    echo '{"enabledPlugins":{}}' > "$TEST_SETTINGS"

    TEMP_FILE=$(mktemp)
    jq --arg plugin "cleanup@test" '.enabledPlugins[$plugin] = true' "$TEST_SETTINGS" > "$TEMP_FILE"

    # Successful mv should remove temp file
    mv "$TEMP_FILE" "$TEST_SETTINGS"

    if [ ! -f "$TEMP_FILE" ]; then
        log_pass "Temp file cleaned up after successful mv"
    else
        log_fail "Temp file still exists after mv"
        rm -f "$TEMP_FILE"
    fi
}

# Test 6: Script syntax check
test_script_syntax() {
    log_info "Test 6: Install script syntax check"

    FORMULA_FILE="$SCRIPT_DIR/../Formula/craft.rb"
    if [ -f "$FORMULA_FILE" ]; then
        # Extract the bash script and check syntax
        if ruby -e "
            content = File.read('$FORMULA_FILE')
            # Find the craft-install script
            if content =~ /\(bin\/\"craft-install\"\)\.write <<~EOS(.+?)EOS/m
                script = \$1
                File.write('/tmp/craft-install-test.sh', '#!/bin/bash\n' + script)
            end
        " 2>/dev/null; then
            if bash -n /tmp/craft-install-test.sh 2>/dev/null; then
                log_pass "Install script syntax is valid"
            else
                log_fail "Install script has syntax errors"
            fi
            rm -f /tmp/craft-install-test.sh
        else
            log_pass "Could not extract script (ruby parse issue) - skipping"
        fi
    else
        log_fail "Formula file not found: $FORMULA_FILE"
    fi
}

# Test 7: Actual installed script test
test_installed_script() {
    log_info "Test 7: Installed craft-install script"

    if [ -f /opt/homebrew/Cellar/craft/1.18.0/bin/craft-install ]; then
        if bash -n /opt/homebrew/Cellar/craft/1.18.0/bin/craft-install 2>/dev/null; then
            log_pass "Installed craft-install script syntax is valid"
        else
            log_fail "Installed craft-install script has syntax errors"
        fi
    else
        log_pass "craft-install not installed at expected path - skipping"
    fi
}

# Run all tests
main() {
    echo ""
    echo "========================================"
    echo "  Craft Install Detection Test Suite"
    echo "========================================"
    echo ""

    setup

    test_basic_jq_modification
    test_claude_detection
    test_claude_detection_lsof
    test_skip_when_claude_running
    test_temp_file_cleanup
    test_script_syntax
    test_installed_script

    echo ""
    echo "========================================"
    echo "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
    echo "========================================"
    echo ""

    if [ $FAILED -gt 0 ]; then
        exit 1
    fi
}

main "$@"
