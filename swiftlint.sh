#!/bin/bash

# SwiftLint build script for Xcode
# This script handles different installation locations and sandbox restrictions

# Function to find SwiftLint
find_swiftlint() {
    # Try common installation paths
    local paths=(
        "/opt/homebrew/bin/swiftlint"
        "/usr/local/bin/swiftlint"
        "$(which swiftlint 2>/dev/null)"
    )
    
    for path in "${paths[@]}"; do
        if [[ -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Find SwiftLint executable
SWIFTLINT_PATH=$(find_swiftlint)

if [[ -z "$SWIFTLINT_PATH" ]]; then
    echo "warning: SwiftLint not found. Install it with 'brew install swiftlint'"
    exit 0
fi

echo "Using SwiftLint at: $SWIFTLINT_PATH"

# Run SwiftLint
# Use SRCROOT if available (Xcode build), otherwise use current directory
CONFIG_PATH="${SRCROOT:-.}/.swiftlint.yml"

if [[ -f "$CONFIG_PATH" ]]; then
    "$SWIFTLINT_PATH" --config "$CONFIG_PATH"
else
    echo "warning: SwiftLint config not found at $CONFIG_PATH"
    "$SWIFTLINT_PATH"
fi
