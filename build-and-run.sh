#!/bin/bash

# SystemVoiceMemos Build and Launch Script
# Builds the app with the specified configuration and automatically opens it on success

set -e

# Configuration
APP_NAME="SystemVoiceMemos"
SCHEME="SystemVoiceMemos"
CONFIGURATION="${1:-Debug}"
# Use a native APFS volume for derived data to avoid AppleDouble file issues on exFAT
DERIVED_DATA_PATH="/tmp/SystemVoiceMemos-build"
BUILD_OUTPUT_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
APP_PATH="$BUILD_OUTPUT_PATH/$APP_NAME.app"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}ℹ ${1}${NC}"
}

log_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

# Build the app
log_info "Building $APP_NAME ($CONFIGURATION)..."

# Use Developer ID Application certificate for proper code signing
log_info "Using Developer ID Application certificate..."

# Clean AppleDouble files that cause signing issues on exFAT volumes
log_info "Cleaning AppleDouble files..."
find "$DERIVED_DATA_PATH" -name "._*" -delete 2>/dev/null || true
find "$DERIVED_DATA_PATH" -name ".__*" -delete 2>/dev/null || true

xcodebuild -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    clean build \
    OTHER_CODE_SIGN_FLAGS="--timestamp" || {
    log_error "Build failed"
    exit 1
}

log_success "Build completed"

# Verify app was created
if [ ! -d "$APP_PATH" ]; then
    log_error "App not found at $APP_PATH"
    exit 1
fi

log_info "Opening $APP_NAME..."
open "$APP_PATH"

log_success "App launched!"
