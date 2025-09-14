#!/bin/bash

# Local check script - mirrors CI pipeline checks
# Usage: ./check-local.sh [--quick] [--fix]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Parse arguments
QUICK_MODE=false
FIX_MODE=false

for arg in "$@"; do
    case $arg in
        --quick)
            QUICK_MODE=true
            ;;
        --fix)
            FIX_MODE=true
            ;;
        --help)
            echo "Usage: $0 [--quick] [--fix]"
            echo "  --quick  Skip tests for faster checking"
            echo "  --fix    Auto-fix formatting issues"
            exit 0
            ;;
    esac
done

echo -e "${MAGENTA}╔════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║   📋 Local CI Pipeline Check          ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════╝${NC}"

if [ "$QUICK_MODE" = true ]; then
    echo -e "${YELLOW}⚡ Quick mode enabled (skipping tests)${NC}"
fi
if [ "$FIX_MODE" = true ]; then
    echo -e "${YELLOW}🔧 Fix mode enabled${NC}"
fi

START_TIME=$(date +%s)
FAILED=false

# Function to print section headers
print_section() {
    echo -e "\n${CYAN}▶ $1${NC}"
    echo "─────────────────────────────────────"
}

# Function to print results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        FAILED=true
    fi
}

# 1. Dependencies check
print_section "1. Checking Dependencies"
flutter pub get --no-precompile > /dev/null 2>&1
print_result $? "Dependencies up to date"

# 2. Code formatting
print_section "2. Code Formatting"
if [ "$FIX_MODE" = true ]; then
    echo "Fixing formatting..."
    dart format .
    print_result 0 "Formatting fixed"
else
    dart format --output=none --set-exit-if-changed . > /dev/null 2>&1
    FORMAT_EXIT=$?
    if [ $FORMAT_EXIT -ne 0 ]; then
        print_result 1 "Formatting issues found (run with --fix to auto-fix)"
    else
        print_result 0 "Code properly formatted"
    fi
fi

# 3. Static analysis
print_section "3. Static Analysis"
ANALYZE_OUTPUT=$(flutter analyze --no-fatal-infos 2>&1)
ANALYZE_EXIT=$?

ERROR_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "error •" || true)
WARNING_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "warning •" || true)
INFO_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "info •" || true)

if [ $ERROR_COUNT -gt 0 ]; then
    print_result 1 "Found $ERROR_COUNT errors"
    echo "$ANALYZE_OUTPUT" | grep "error •" | head -10
else
    print_result 0 "No errors found"
fi

if [ $WARNING_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNING_COUNT warnings found${NC}"
fi
if [ $INFO_COUNT -gt 0 ]; then
    echo -e "${BLUE}ℹ️  $INFO_COUNT info messages${NC}"
fi

# 4. TODO comments check
print_section "4. TODO Comments"
TODO_COUNT=$(grep -r "TODO" lib/ --exclude-dir=.dart_tool 2>/dev/null | wc -l || echo "0")
if [ "$TODO_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $TODO_COUNT TODO comments${NC}"
    grep -r "TODO" lib/ --exclude-dir=.dart_tool | head -5
else
    print_result 0 "No TODO comments"
fi

# 5. Unit tests
if [ "$QUICK_MODE" = false ]; then
    print_section "5. Unit Tests"
    TEST_OUTPUT=$(flutter test --no-pub 2>&1)
    TEST_EXIT=$?

    if [ $TEST_EXIT -eq 0 ]; then
        TEST_SUMMARY=$(echo "$TEST_OUTPUT" | tail -1)
        print_result 0 "Tests passed: $TEST_SUMMARY"
    else
        print_result 1 "Tests failed"
        echo "$TEST_OUTPUT" | tail -20
    fi
else
    print_section "5. Unit Tests"
    echo -e "${YELLOW}⏭️  Skipped (quick mode)${NC}"
fi

# 6. Build verification (optional, very slow)
# Uncomment to enable build checks
# print_section "6. Build Verification"
# flutter build ios --debug --no-codesign > /dev/null 2>&1
# print_result $? "iOS build"
# flutter build apk --debug > /dev/null 2>&1
# print_result $? "Android build"

# Calculate elapsed time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# Final summary
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════╗${NC}"
if [ "$FAILED" = false ]; then
    echo -e "${MAGENTA}║   ${GREEN}✅ All checks passed!${MAGENTA}                ║${NC}"
else
    echo -e "${MAGENTA}║   ${RED}❌ Some checks failed${MAGENTA}                ║${NC}"
fi
echo -e "${MAGENTA}╚════════════════════════════════════════╝${NC}"
echo -e "Time elapsed: ${ELAPSED}s"

if [ "$FAILED" = true ]; then
    exit 1
fi
