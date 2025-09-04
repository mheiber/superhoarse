#!/bin/bash

# Build and Run Script for Superhoarse
# Builds with Xcode and immediately launches the app

set -e

# Configuration
PROJECT="superhoarse.xcodeproj"
SCHEME="superhoarse"
CONFIGURATION="Debug"
BUILD_DIR="build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building and running Superhoarse...${NC}"

# Kill any existing instances first
echo -e "${YELLOW}Stopping any running instances...${NC}"
pkill -f "Superhoarse" || true
pkill -f "superhoarse" || true
# Also try killing by app bundle name
pkill -f "superhoarse.app" || true
sleep 2

# Clean and build
echo -e "${YELLOW}Building project...${NC}"
xcodebuild clean build -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -derivedDataPath "$BUILD_DIR" -quiet

# Find the built app
APP_PATH=$(find "$BUILD_DIR" -name "*.app" -type d | head -n 1)

if [[ -z "$APP_PATH" ]]; then
    echo -e "${RED}Error: Could not find built app${NC}"
    exit 1
fi

echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "Launching app from: ${APP_PATH}"

# Launch the app
open "$APP_PATH"

echo -e "${GREEN}Superhoarse launched!${NC}"
echo ""
echo "To stop the app, use: pkill -f Superhoarse"