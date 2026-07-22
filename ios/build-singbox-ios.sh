#!/bin/bash
# ============================================================================
# Build sing-box libbox iOS framework via the upstream mobile build command
# ============================================================================
# Prerequisites:
#   1. Go 1.22+ installed
#   2. mobile build tools installed:
#      go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.4
#      go install github.com/sagernet/gomobile/cmd/gobind@v0.1.4
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
FRAMEWORK_NAME="Libbox.xcframework"

echo "==> Building $FRAMEWORK_NAME for iOS..."
echo "    Source: $SINGBOX_SRC"
echo "    Output: $OUTPUT_DIR"

# Verify source exists
if [ ! -d "$SINGBOX_SRC/experimental/libbox" ]; then
    echo "ERROR: upstream libbox source not found at $SINGBOX_SRC/experimental/libbox"
    exit 1
fi

# Verify gomobile
if ! command -v gomobile &> /dev/null; then
    echo "ERROR: gomobile not found. Install it:"
    echo "  go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.4"
    echo "  go install github.com/sagernet/gomobile/cmd/gobind@v0.1.4"
    echo "  gomobile init"
    exit 1
fi

# Build the framework
cd "$SINGBOX_SRC"

echo "==> Building iOS framework (this may take a while)..."
go run ./cmd/internal/build_libbox -target ios
rm -rf "$OUTPUT_DIR/$FRAMEWORK_NAME"
mv "$FRAMEWORK_NAME" "$OUTPUT_DIR/$FRAMEWORK_NAME"

echo "==> ✅ Done! Framework created at:"
echo "    $OUTPUT_DIR/$FRAMEWORK_NAME"
echo ""
echo "==> Next steps:"
echo "  1. Open $IOS_DIR/Runner.xcworkspace in Xcode"
echo "  2. Go to Project > Runner > General > Frameworks, Libraries, and Embedded Content"
echo "  3. Click + and add Libbox.xcframework"
echo "  4. Set Embed to 'Embed & Sign'"
echo "  5. Build and run on device"
