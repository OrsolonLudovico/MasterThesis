#!/bin/bash

# Script to download unitigs from Logan
# Usage: ./download_unitigs.sh <accessions_file.txt> [output_dir]

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
echo "Downloading $TOTAL accessions to $OUTPUT_DIR"
echo "Start: $(date)"

# Download unitigs
cat "$ACCESSIONS_FILE" | xargs -I{} aws s3 cp s3://logan-pub/u/{}/{}.unitigs.fa.zst "$OUTPUT_DIR/" --no-sign-request

echo "Completed: $(date)"
echo "Files downloaded to: $OUTPUT_DIR"
