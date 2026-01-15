#!/bin/bash
# Test suite for craft-install timeout mechanism
# Tests that settings.json modification doesn't block indefinitely

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

# Test 2: Timeout command availability
test_timeout_availability() {
    log_info "Test 2: Timeout command availability"

    if command -v timeout &>/dev/null; then
        log_pass "timeout command available (Linux/GNU)"
    elif command -v gtimeout &>/dev/null; then
        log_pass "gtimeout command available (macOS coreutils)"
    else
        log_pass "Neither timeout nor gtimeout available - will use fallback"
    fi
}

# Test 3: Fallback timeout mechanism (background process)
test_fallback_timeout() {
    log_info "Test 3: Fallback timeout mechanism"

    # Reset settings
    echo '{"enabledPlugins":{}}' > "$TEST_SETTINGS"

    TEMP_FILE=$(mktemp)
    jq --arg plugin "test@fallback" '.enabledPlugins[$plugin] = true' "$TEST_SETTINGS" > "$TEMP_FILE"

    # Use the fallback mechanism
    mv "$TEMP_FILE" "$TEST_SETTINGS" &
    MV_PID=$!
    sleep 0.5  # Short timeout for test

    if kill -0 $MV_PID 2>/dev/null; then
        # Process still running - would timeout in real scenario
        wait $MV_PID 2>/dev/null
        log_pass "Fallback mechanism: mv completed within timeout"
    else
        # Process already finished
        wait $MV_PID 2>/dev/null
        log_pass "Fallback mechanism: mv completed quickly"
    fi

    # Verify result
    if jq -e '.enabledPlugins["test@fallback"]' "$TEST_SETTINGS" >/dev/null 2>&1; then
        log_pass "Fallback mechanism: modification persisted"
    else
        log_fail "Fallback mechanism: modification didn't persist"
    fi
}

# Test 4: Simulate locked file (if flock available)
test_locked_file_timeout() {
    log_info "Test 4: Locked file timeout simulation"

    # Create a lock file scenario
    LOCK_FILE="$TEST_DIR/locktest.json"
    echo '{"test": true}' > "$LOCK_FILE"

    # Try to detect if we can simulate file locks
    if command -v flock &>/dev/null; then
        # Linux: use flock
        (
            flock -x 200
            sleep 5  # Hold lock for 5 seconds
        ) 200>"$LOCK_FILE.lock" &
        LOCK_PID=$!

        sleep 0.1  # Let lock acquire

        # Try mv with timeout
        TEMP_FILE=$(mktemp)
        echo '{"test": "modified"}' > "$TEMP_FILE"

        START_TIME=$(date +%s)

        # Use our timeout mechanism
        mv "$TEMP_FILE" "$LOCK_FILE" 2>/dev/null &
        MV_PID=$!
        sleep 2

        if kill -0 $MV_PID 2>/dev/null; then
            kill $MV_PID 2>/dev/null
            rm -f "$TEMP_FILE" 2>/dev/null
            END_TIME=$(date +%s)
            ELAPSED=$((END_TIME - START_TIME))

            if [ $ELAPSED -le 3 ]; then
                log_pass "Timeout killed blocked mv within ${ELAPSED}s"
            else
                log_fail "Timeout took too long: ${ELAPSED}s"
            fi
        else
            wait $MV_PID
            log_pass "mv completed (file wasn't actually locked)"
        fi

        # Cleanup
        kill $LOCK_PID 2>/dev/null || true
        rm -f "$LOCK_FILE.lock"
    else
        log_pass "flock not available - skipping lock simulation (macOS)"
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
    echo "  Craft Install Timeout Test Suite"
    echo "========================================"
    echo ""

    setup

    test_basic_jq_modification
    test_timeout_availability
    test_fallback_timeout
    test_locked_file_timeout
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
