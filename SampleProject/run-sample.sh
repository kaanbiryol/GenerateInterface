#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODULE_NAME="UserProfile"
PACKAGE_DIR="$SCRIPT_DIR/libraries/business/UserProfile"

PRINT_ONLY="--print-only"
if [ "${1:-}" = "--write" ]; then
    PRINT_ONLY=""
    echo "Running in WRITE mode - files will be created and modified."
    echo ""
fi

echo "=== Step 1: Build the generateInterface tool ==="
cd "$REPO_ROOT"
swift build -c debug 2>&1 | tail -1
TOOL_PATH="$(swift build -c debug --show-bin-path)/generateInterface"
echo "Tool built at: $TOOL_PATH"

echo ""
echo "=== Step 2: Build the sample UserProfile module ==="
cd "$PACKAGE_DIR"

# Clean and rebuild with verbose output to capture the swiftc invocation
swift package clean 2>/dev/null || true
VERBOSE_OUTPUT=$(swift build -v 2>&1)

echo "Module built."

echo ""
echo "=== Step 3: Extract compiler arguments ==="

# Extract the swiftc line that compiles the UserProfile module
SWIFTC_LINE=$(echo "$VERBOSE_OUTPUT" | grep "swiftc.*-module-name UserProfile " | head -1)

if [ -z "$SWIFTC_LINE" ]; then
    echo "ERROR: Could not find swiftc invocation for UserProfile module."
    echo "Verbose build output:"
    echo "$VERBOSE_OUTPUT"
    exit 1
fi

# Extract arguments: remove the swiftc binary path prefix, split into one-per-line,
# then remove -module-name and the module name itself (as the Ruby wrapper does)
ARGS_FILE=$(mktemp /tmp/compiler-args.XXXXXX)

echo "$SWIFTC_LINE" \
    | sed 's|^[^ ]*/swiftc ||' \
    | tr ' ' '\n' \
    | grep -v -e '^-module-name$' -e "^${MODULE_NAME}$" \
    | grep -v '^$' \
    > "$ARGS_FILE"

echo "Compiler arguments written to: $ARGS_FILE"
echo "$(wc -l < "$ARGS_FILE" | tr -d ' ') arguments extracted."

echo ""
echo "=== Step 4: Run generateInterface${PRINT_ONLY:+ (dry run)} ==="

# SourceKit requires the Xcode toolchain frameworks to be in the dynamic library path
TOOLCHAIN_LIB="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib"
export DYLD_FRAMEWORK_PATH="$TOOLCHAIN_LIB:${DYLD_FRAMEWORK_PATH:-}"

"$TOOL_PATH" \
    "$SCRIPT_DIR/Project.swift" \
    "$MODULE_NAME" \
    "$SCRIPT_DIR/libraries" \
    "$ARGS_FILE" \
    $PRINT_ONLY

# Clean up
rm -f "$ARGS_FILE"

echo ""
echo "=== Done! ==="
