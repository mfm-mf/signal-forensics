#!/bin/bash

# Defaults
COLLECTION_TYPE="signaldesktop"
DEFAULT_SIGNAL_DIR="$HOME/Library/Application Support/Signal"
DEFAULT_OUTPUT_DIR="output"

usage() {
    cat <<-EOF
Usage: $(basename "$0") -e <encryption_password> [-c <custodian>] [-i <signal_dir>] [-o <output_dir>]

Options:
  -c  Custodian name (default: current username)
  -e  Encryption password (required)
  -i  Signal data directory (default: $DEFAULT_SIGNAL_DIR)
  -o  Output directory (default: $DEFAULT_OUTPUT_DIR)
  -h  Show this help message
EOF
    exit 1
}

# Parse arguments
CUSTODIAN=""
ENCRYPTION_PASSWORD=""
SIGNAL_DIR="$DEFAULT_SIGNAL_DIR"
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"

while getopts ":c:e:i:o:h" opt; do
    case $opt in
        c) CUSTODIAN="$OPTARG" ;;
        e) ENCRYPTION_PASSWORD="$OPTARG" ;;
        i) SIGNAL_DIR="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage ;;
        :) echo "Error: Option -$OPTARG requires an argument." >&2; usage ;;
        \?) echo "Error: Unknown option -$OPTARG" >&2; usage ;;
    esac
done

# Apply defaults and validate
CUSTODIAN="${CUSTODIAN:-$(whoami)}"

if [[ -z "$ENCRYPTION_PASSWORD" ]]; then
    echo "Error: Encryption password (-e) is required." >&2
    usage
fi

if [[ ! -d "$SIGNAL_DIR" ]]; then
    echo "Error: Signal directory not found: $SIGNAL_DIR" >&2
    exit 1
fi

# Derived paths
TIMESTAMP=$(date +%Y%m%d)
OUTPUT_JSON="$OUTPUT_DIR/$CUSTODIAN-$COLLECTION_TYPE-collection-metadata.json"
FINAL_ZIP="$OUTPUT_DIR/$CUSTODIAN-$COLLECTION_TYPE-$TIMESTAMP.zip"
HASH_FILE="$OUTPUT_DIR/$CUSTODIAN-$COLLECTION_TYPE-$TIMESTAMP.sha256"
SIGNAL_KEYCHAIN="$OUTPUT_DIR/signal-keychain.txt"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Set up logging
exec > "$OUTPUT_DIR/script_output.log"
exec 2> "$OUTPUT_DIR/script_error.log"

# Create status output function
status_message() {
    echo "$1" >> /dev/tty
}

# Error handling
set -euo pipefail
trap 'status_message "Error on line $LINENO"' ERR

# Calculate and display Signal directory size
SIGNAL_SIZE=$(du -sh "$SIGNAL_DIR" 2>/dev/null | cut -f1)
status_message "Signal directory size: $SIGNAL_SIZE"

get_password_from_keychain() {
    security find-generic-password -s "$1" -a "$2" -w 2>/dev/null || {
        status_message "Error: Failed to retrieve password from keychain"
        exit 1
    }
}

# Generate metadata JSON
status_message "Generating metadata JSON..."
{
    echo "["
    first=true
    while IFS= read -r -d '' file; do
        [[ "$first" = true ]] || echo ","
        first=false

        stat_info=($(stat -f "%SB %Sm %Sa %Sc %z" -t "%Y-%m-%d %H:%M:%S" "$file"))
        sha256=$(openssl dgst -sha256 -r "$file" | cut -d' ' -f1)

        cat <<-EOF
        {
            "filename": "$(basename "$file")",
            "created": "${stat_info[0]} ${stat_info[1]}",
            "modified": "${stat_info[2]} ${stat_info[3]}",
            "accessed": "${stat_info[4]} ${stat_info[5]}",
            "inode-changed": "${stat_info[6]} ${stat_info[7]}",
            "size": ${stat_info[8]},
            "sha256": "$sha256",
            "folder_path": "$(dirname "$file")"
        }
EOF
    done < <(find "$SIGNAL_DIR" -type f -print0)
    echo -e "\n]"
} > "$OUTPUT_JSON"

# Store Signal password
status_message "Retrieving Signal password from keychain..."
get_password_from_keychain 'Signal Safe Storage' 'Signal Key' > "$SIGNAL_KEYCHAIN"

# Create encrypted archive with all files
status_message "Creating encrypted archive..."
zip -r -P "$ENCRYPTION_PASSWORD" "$FINAL_ZIP" \
    "$SIGNAL_DIR" \
    "$OUTPUT_JSON" \
    "$SIGNAL_KEYCHAIN" \
    "$OUTPUT_DIR/"*.log \
    -x "*.DS_Store" >/dev/null

# Generate hash
status_message "Generating hash..."
openssl dgst -sha256 "$FINAL_ZIP" > "$HASH_FILE"

status_message "Backup complete. Files stored in $FINAL_ZIP"