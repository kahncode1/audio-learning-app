#!/bin/bash
# Flutter Development Helper Script
# This script ensures Flutter runs in foreground mode for proper hot reload support

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Flutter Development Helper${NC}"
echo "================================"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Navigate to project directory
PROJECT_DIR="/Users/kahnja/Projects/Modia/Audio Learning App"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}❌ Project directory not found: $PROJECT_DIR${NC}"
    exit 1
fi

cd "$PROJECT_DIR"
echo -e "${GREEN}📁 Working directory: $(pwd)${NC}"

# Kill any existing Flutter processes
echo -e "${YELLOW}🔄 Cleaning up existing Flutter processes...${NC}"
pkill -f "flutter run" 2>/dev/null
sleep 1

# Check for iOS Simulator
echo -e "${YELLOW}📱 Checking for iOS Simulator...${NC}"
if ! pgrep -x "Simulator" > /dev/null; then
    echo "Starting iOS Simulator..."
    open -a Simulator
    echo "Waiting for Simulator to boot..."
    sleep 5
fi

# Get dependencies if needed
if [ ! -d ".dart_tool" ]; then
    echo -e "${YELLOW}📦 Getting Flutter dependencies...${NC}"
    flutter pub get
fi

# Clear the terminal for clean output
clear

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}            🚀 Flutter App Starting                         ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Hot Reload Controls:${NC}"
echo "  • Press 'r' for hot reload 🔥"
echo "  • Press 'R' for hot restart"
echo "  • Press 'q' to quit"
echo "  • Press 'h' for more commands"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""

# Run Flutter in foreground mode
flutter run

# After Flutter exits
echo ""
echo -e "${GREEN}✅ Flutter session ended${NC}"