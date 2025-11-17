#!/bin/bash

# Script to download unitigs from Logan and automatically extract them
# Usage: ./download_and_extract.sh <accessions_file.txt> [output_dir]

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <accessions_file.txt> [output_dir]"
    echo "Example: $0 accessions.txt ./unitigs"
    exit 1
fi

ACCESSIONS_FILE="$1"
OUTPUT_DIR="${2:-.}"  # Default: current directory

# Check if accessions file exists
if [ ! -f "$ACCESSIONS_FILE" ]; then
    echo "Error: File $ACCESSIONS_FILE not found!"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Count total number of accessions
TOTAL=$(wc -l < "$ACCESSIONS_FILE")
echo "=========================================="
echo "Downloading $TOTAL accessions to $OUTPUT_DIR"
echo "Start: $(date)"
echo "=========================================="

# Download unitigs
cat "$ACCESSIONS_FILE" | xargs -I{} aws s3 cp s3://logan-pub/u/{}/{}.unitigs.fa.zst "$OUTPUT_DIR/" --no-sign-request

echo ""
echo "=========================================="
echo "Download completed: $(date)"
echo "Starting extraction..."
echo "=========================================="

# Extract all downloaded files and remove compressed versions
COUNT=0
for file in "$OUTPUT_DIR"/*.unitigs.fa.zst; do
    if [ -f "$file" ]; then
        COUNT=$((COUNT + 1))
        echo "[$COUNT/$TOTAL] Extracting $(basename "$file")..."
        
        # Extract with zstd
        if zstd -d "$file" -o "${file%.zst}" -q; then
            # If extraction successful, remove compressed file
            rm "$file"
            echo "  ✓ Done"
        else
            echo "  ✗ Error extracting $(basename "$file")"
        fi
    fi
done

echo ""
echo "=========================================="
echo "All operations completed: $(date)"
echo "Extracted files in: $OUTPUT_DIR"
echo "=========================================="
