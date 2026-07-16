#!/bin/bash
# ============================================================================
# Build sing-box iOS framework via gomobile
# ============================================================================
# Prerequisites:
#   1. Go 1.22+ installed
#   2. gomobile installed: go install golang.org/x/mobile/cmd/gomobile@latest
#      gomobile init
#   3. sing-box source with iOS gomobile bindings
#
# Usage:
#   ./build-singbox-ios.sh [sing-box-source-dir]
#   Default source dir: ../sing-box

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(dirname "$SCRIPT_DIR")"
SINGBOX_SRC="${1:-$IOS_DIR/../sing-box}"
OUTPUT_DIR="$IOS_DIR/Runner"
FRAMEWORK_NAME="Singbox.xcframework"

echo "==> Building $FRAMEWORK_NAME for iOS..."
echo "    Source: $SINGBOX_SRC"
echo "    Output: $OUTPUT_DIR"

# Verify source exists
if [ ! -d "$SINGBOX_SRC/golib/ios" ]; then
    echo "ERROR: sing-box iOS gomobile bindings not found at $SINGBOX_SRC/golib/ios"
    echo ""
    echo "The sing-box repo should have a 'golib/ios' directory with the following"
    echo "Go package structure:"
    echo ""
    echo "  sing-box/"
    echo "    golib/"
    echo "      ios/"
    echo "        ios.go       # package main with gomobile bindings"
    echo "        stats.go     # optional stats tracking"
    echo ""
    echo "Create it if missing, or point to a different source path."
    exit 1
fi

# Verify gomobile
if ! command -v gomobile &> /dev/null; then
    echo "ERROR: gomobile not found. Install it:"
    echo "  go install golang.org/x/mobile/cmd/gomobile@latest"
    echo "  gomobile init"
    exit 1
fi

# Build the framework
cd "$SINGBOX_SRC"

echo "==> Building iOS framework (this may take a while)..."
gomobile bind \
    -v \
    -target=ios \
    -iosversion=14.0 \
    -ldflags='-s -w' \
    -o "$OUTPUT_DIR/$FRAMEWORK_NAME" \
    ./golib/ios

echo "==> ✅ Done! Framework created at:"
echo "    $OUTPUT_DIR/$FRAMEWORK_NAME"
echo ""
echo "==> Next steps:"
echo "  1. Open $IOS_DIR/Runner.xcworkspace in Xcode"
echo "  2. Go to Project > Runner > General > Frameworks, Libraries, and Embedded Content"
echo "  3. Click + and add Singbox.xcframework"
echo "  4. Set Embed to 'Embed & Sign'"
echo "  5. Build and run on device"
