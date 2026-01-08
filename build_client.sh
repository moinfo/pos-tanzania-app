#!/bin/bash

# ============================================
# POS Tanzania Mobile - Client Build Script
# ============================================
# Usage:
#   ./build_client.sh sada          # Build SADA APK
#   ./build_client.sh comeAndSave   # Build Come & Save APK
#   ./build_client.sh leruma        # Build Leruma APK
#   ./build_client.sh all           # Build all clients
#   ./build_client.sh               # Show help

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Available flavors
FLAVORS=("sada" "comeAndSave" "leruma")

# Display names
declare -A DISPLAY_NAMES
DISPLAY_NAMES["sada"]="SADA POS"
DISPLAY_NAMES["comeAndSave"]="Come & Save POS"
DISPLAY_NAMES["leruma"]="Leruma POS"

# Application IDs
declare -A APP_IDS
APP_IDS["sada"]="co.tz.sada.pos"
APP_IDS["comeAndSave"]="co.tz.comeandsave.pos"
APP_IDS["leruma"]="co.tz.leruma.pos"

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  POS Tanzania Mobile - Client Builder${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

print_help() {
    print_header
    echo "Usage: ./build_client.sh <flavor>"
    echo ""
    echo "Available flavors:"
    for flavor in "${FLAVORS[@]}"; do
        echo -e "  ${GREEN}$flavor${NC} - ${DISPLAY_NAMES[$flavor]} (${APP_IDS[$flavor]})"
    done
    echo ""
    echo -e "  ${YELLOW}all${NC} - Build all clients"
    echo ""
    echo "Examples:"
    echo "  ./build_client.sh sada          # Build SADA APK"
    echo "  ./build_client.sh comeAndSave   # Build Come & Save APK"
    echo "  ./build_client.sh leruma        # Build Leruma APK"
    echo "  ./build_client.sh all           # Build all clients"
    echo ""
}

build_flavor() {
    local flavor=$1
    local display_name=${DISPLAY_NAMES[$flavor]}
    local app_id=${APP_IDS[$flavor]}

    echo ""
    echo -e "${YELLOW}Building $display_name...${NC}"
    echo -e "  Flavor: ${GREEN}$flavor${NC}"
    echo -e "  App ID: ${GREEN}$app_id${NC}"
    echo ""

    # Build APK
    flutter build apk --flavor "$flavor" --dart-define=FLAVOR="$flavor" --release

    # Get output path
    local output_path="build/app/outputs/flutter-apk/app-${flavor}-release.apk"

    if [ -f "$output_path" ]; then
        # Create output directory if not exists
        mkdir -p "releases"

        # Copy with descriptive name
        local release_name="releases/${display_name// /_}_$(date +%Y%m%d).apk"
        cp "$output_path" "$release_name"

        echo ""
        echo -e "${GREEN}✓ Build successful!${NC}"
        echo -e "  APK: ${BLUE}$release_name${NC}"
        echo -e "  Size: $(du -h "$release_name" | cut -f1)"
    else
        echo -e "${RED}✗ Build failed! APK not found.${NC}"
        exit 1
    fi
}

# Main script
if [ $# -eq 0 ]; then
    print_help
    exit 0
fi

print_header

case "$1" in
    "all")
        echo -e "${YELLOW}Building all clients...${NC}"
        for flavor in "${FLAVORS[@]}"; do
            build_flavor "$flavor"
        done
        echo ""
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}  All builds completed successfully!${NC}"
        echo -e "${GREEN}============================================${NC}"
        echo ""
        echo "APKs are in the 'releases' folder:"
        ls -la releases/*.apk 2>/dev/null || echo "No APKs found"
        ;;
    "sada"|"comeAndSave"|"leruma")
        build_flavor "$1"
        ;;
    *)
        echo -e "${RED}Unknown flavor: $1${NC}"
        echo ""
        print_help
        exit 1
        ;;
esac