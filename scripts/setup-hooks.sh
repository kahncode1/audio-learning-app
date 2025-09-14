#!/bin/bash

# Setup script for development environment and git hooks
# Compatible with Mac and Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Audio Learning App - Development Setup${NC}"
echo "========================================="

# Check if we're in the project root
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: Not in project root directory${NC}"
    echo "Please run this script from the project root"
    exit 1
fi

# Check Flutter installation
echo -e "\n${YELLOW}Checking Flutter installation...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter not found${NC}"
    echo "Please install Flutter first: https://flutter.dev/docs/get-started/install"
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -n 1)
echo -e "${GREEN}✓ Flutter installed${NC}"
echo "  $FLUTTER_VERSION"

# Check Dart version
DART_VERSION=$(dart --version 2>&1)
echo -e "${GREEN}✓ Dart installed${NC}"
echo "  $DART_VERSION"

# Create hooks directory if it doesn't exist
HOOKS_DIR=".git/hooks"
if [ ! -d "$HOOKS_DIR" ]; then
    echo -e "\n${YELLOW}Creating hooks directory...${NC}"
    mkdir -p "$HOOKS_DIR"
fi

# Install pre-commit hook
echo -e "\n${YELLOW}Installing pre-commit hook...${NC}"
PRE_COMMIT_HOOK="$HOOKS_DIR/pre-commit"

cat > "$PRE_COMMIT_HOOK" << 'EOF'
#!/bin/bash

# Pre-commit hook for Flutter code quality
# Use --no-verify to bypass in emergencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🔍 Running pre-commit checks...${NC}"
echo "================================"

# Store start time
START_TIME=$(date +%s)

# Check if we're in the project root
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Not in Flutter project root${NC}"
    exit 1
fi

# Function to calculate elapsed time
elapsed_time() {
    local end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    echo "${elapsed}s"
}

# 1. Check Flutter analyze
echo -e "\n${CYAN}1. Running Flutter analyze...${NC}"
ANALYZE_OUTPUT=$(flutter analyze --no-pub 2>&1)
ANALYZE_EXIT=$?

if [ $ANALYZE_EXIT -ne 0 ]; then
    echo -e "${RED}❌ Flutter analyze found issues:${NC}"
    echo "$ANALYZE_OUTPUT" | grep -E "error •|warning •" | head -20
    echo -e "\n${YELLOW}Fix these issues or use 'git commit --no-verify' to bypass${NC}"
    echo -e "Time elapsed: $(elapsed_time)"
    exit 1
fi

# Count issues
ERROR_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "error •" || true)
WARNING_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "warning •" || true)
INFO_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "info •" || true)

if [ $ERROR_COUNT -gt 0 ]; then
    echo -e "${RED}❌ Found $ERROR_COUNT errors${NC}"
    echo -e "${YELLOW}Errors must be fixed before committing${NC}"
    echo -e "Time elapsed: $(elapsed_time)"
    exit 1
fi

echo -e "${GREEN}✓ No errors found${NC}"
if [ $WARNING_COUNT -gt 0 ]; then
    echo -e "${YELLOW}  ⚠️  $WARNING_COUNT warnings (not blocking)${NC}"
fi
if [ $INFO_COUNT -gt 0 ]; then
    echo -e "${BLUE}  ℹ️  $INFO_COUNT info messages${NC}"
fi

# 2. Check code formatting
echo -e "\n${CYAN}2. Checking code formatting...${NC}"
FORMAT_OUTPUT=$(dart format --output=none --set-exit-if-changed . 2>&1)
FORMAT_EXIT=$?

if [ $FORMAT_EXIT -ne 0 ]; then
    echo -e "${RED}❌ Code formatting issues found${NC}"
    echo -e "${YELLOW}Run 'dart format .' to fix formatting${NC}"
    echo -e "Time elapsed: $(elapsed_time)"
    exit 1
fi
echo -e "${GREEN}✓ Code formatting is correct${NC}"

# 3. Check for TODO comments (warning only)
echo -e "\n${CYAN}3. Checking for TODO comments...${NC}"
TODO_COUNT=$(grep -r "TODO" lib/ --exclude-dir=.dart_tool 2>/dev/null | wc -l || echo "0")
if [ "$TODO_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $TODO_COUNT TODO comments (not blocking)${NC}"
else
    echo -e "${GREEN}✓ No TODO comments found${NC}"
fi

# 4. Run tests (can be skipped with SKIP_TESTS=1)
if [ "${SKIP_TESTS}" != "1" ]; then
    echo -e "\n${CYAN}4. Running tests...${NC}"
    echo -e "${BLUE}  (Set SKIP_TESTS=1 to skip)${NC}"

    TEST_OUTPUT=$(flutter test --no-pub 2>&1)
    TEST_EXIT=$?

    if [ $TEST_EXIT -ne 0 ]; then
        echo -e "${RED}❌ Tests failed${NC}"
        echo "$TEST_OUTPUT" | tail -20
        echo -e "\n${YELLOW}Fix failing tests or use 'SKIP_TESTS=1 git commit' to skip tests${NC}"
        echo -e "Time elapsed: $(elapsed_time)"
        exit 1
    fi

    # Extract test summary
    TEST_SUMMARY=$(echo "$TEST_OUTPUT" | tail -1)
    echo -e "${GREEN}✓ Tests passed: $TEST_SUMMARY${NC}"
else
    echo -e "\n${YELLOW}4. Skipping tests (SKIP_TESTS=1 is set)${NC}"
fi

# 5. Check staged files only
echo -e "\n${CYAN}5. Checking staged files...${NC}"
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.dart$' || true)
if [ -z "$STAGED_DART_FILES" ]; then
    echo -e "${BLUE}  No Dart files staged${NC}"
else
    FILE_COUNT=$(echo "$STAGED_DART_FILES" | wc -l)
    echo -e "${GREEN}✓ $FILE_COUNT Dart file(s) staged for commit${NC}"
fi

# Final summary
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total time: $(elapsed_time)"
echo ""

exit 0
EOF

chmod +x "$PRE_COMMIT_HOOK"
echo -e "${GREEN}✓ Pre-commit hook installed${NC}"

# Create local check script
echo -e "\n${YELLOW}Creating local check script...${NC}"
LOCAL_CHECK_SCRIPT="check-local.sh"

cat > "$LOCAL_CHECK_SCRIPT" << 'EOF'
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
EOF

chmod +x "$LOCAL_CHECK_SCRIPT"
echo -e "${GREEN}✓ Local check script created${NC}"

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Development environment setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Pre-commit hook installed at: $PRE_COMMIT_HOOK"
echo "Local check script created: $LOCAL_CHECK_SCRIPT"
echo ""
echo -e "${BLUE}Usage:${NC}"
echo "  • Pre-commit hook will run automatically on 'git commit'"
echo "  • To skip hooks in emergency: git commit --no-verify"
echo "  • To run checks manually: ./check-local.sh"
echo "  • Quick check (no tests): ./check-local.sh --quick"
echo "  • Auto-fix formatting: ./check-local.sh --fix"
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo "  • Set SKIP_TESTS=1 before commit to skip tests temporarily"
echo "  • Use VS Code with Flutter extension for real-time feedback"
echo ""