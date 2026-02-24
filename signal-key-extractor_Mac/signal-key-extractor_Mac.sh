#!/bin/bash

OUTPUT_DIR="output"
OUTPUT_FILE="$OUTPUT_DIR/signal-keychain.txt"

mkdir -p "$OUTPUT_DIR"

# Check for security tool (should always be present on macOS)
if ! command -v security &>/dev/null; then
    echo "ERROR: 'security' command not found. Are you on macOS?"
    exit 1
fi

# Extract Signal key from keychain
echo "Extracting Signal key from keychain..."
KEY=$(security find-generic-password -s 'Signal Safe Storage' -a 'Signal Key' -w 2>/dev/null)

if [ -z "$KEY" ]; then
    echo "ERROR: Could not retrieve Signal key from keychain."
    echo "Make sure Signal is installed and has been opened at least once."
    exit 1
fi

echo "$KEY" > "$OUTPUT_FILE"

# Verify output was created
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "ERROR: Process completed but output file was not created: $OUTPUT_FILE"
    exit 1
fi

echo ""
echo "Key successfully extracted to: $OUTPUT_FILE"