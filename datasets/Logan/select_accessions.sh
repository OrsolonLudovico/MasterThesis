#!/bin/bash

# Script to select N accessions from a list, checking they exist in Logan CSV
# Usage: ./select_accessions.sh <num_accessions> <accessions_list.txt> [output_file]

set -e

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <num_accessions> <accessions_list.txt> [output_file]"
    echo "Example: $0 20 list_accessions_human.txt selected_accessions.txt"
    exit 1
fi

NUM_ACCESSIONS="$1"
ACCESSIONS_FILE="$2"
OUTPUT_FILE="${3:-selected_accessions.txt}"
LOGAN_CSV="logan_accessions_v1.1_SRA2023.csv"

# Check if accessions file exists
if [ ! -f "$ACCESSIONS_FILE" ]; then
    echo "Error: File $ACCESSIONS_FILE not found!"
    exit 1
fi

# Check if Logan CSV exists

if [ ! -f "$LOGAN_CSV" ]; then
    echo "Error: Logan CSV file $LOGAN_CSV not found!"
    echo "Please extract it first: zstdcat logan_accessions_v1.1_SRA2023.csv.zst > logan_accessions_v1.1_SRA2023.csv"
    exit 1
fi

# Temporary file for Logan accessions
TEMP_LOGAN_ACCESSIONS="temp_logan_accessions_list.txt"

echo "=========================================="
echo "SELECT ACCESSIONS FROM LIST"
echo "=========================================="
echo "Requested number: $NUM_ACCESSIONS"
echo "Source file: $ACCESSIONS_FILE"
echo "Output file: $OUTPUT_FILE"
echo "Start: $(date)"
echo "=========================================="
echo ""

# Extract accessions from Logan CSV (first column, remove quotes)
echo "Step 1: Extracting accessions available in Logan..."
cut -d',' -f1 "$LOGAN_CSV" | tr -d '"' | tail -n +2 > "$TEMP_LOGAN_ACCESSIONS"
LOGAN_TOTAL=$(wc -l < "$TEMP_LOGAN_ACCESSIONS")
echo "  ✓ Found $LOGAN_TOTAL accessions available in Logan"
echo ""

# Count total accessions in source file
TOTAL_IN_FILE=$(wc -l < "$ACCESSIONS_FILE")
echo "Step 2: Checking source file..."
echo "  Total accessions in source file: $TOTAL_IN_FILE"
echo ""

# Select random accessions from the list that also exist in Logan
echo "Step 3: Selecting $NUM_ACCESSIONS random accessions..."
echo "  Filtering to keep only accessions available in Logan..."

# Extract accessions from input file (first column if CSV, remove quotes)
# Shuffle, filter against Logan list, and take the requested number
cut -d',' -f1 "$ACCESSIONS_FILE" | tr -d '"' | \
grep -F -f "$TEMP_LOGAN_ACCESSIONS" | \
shuf -n "$NUM_ACCESSIONS" > "$OUTPUT_FILE"

SELECTED_COUNT=$(wc -l < "$OUTPUT_FILE")

echo ""
echo "=========================================="
echo "SELECTION COMPLETED"
echo "=========================================="
echo "Selected accessions: $SELECTED_COUNT"
echo "Output file: $OUTPUT_FILE"
echo "End: $(date)"
echo "=========================================="
echo ""

if [ "$SELECTED_COUNT" -lt "$NUM_ACCESSIONS" ]; then
    echo "⚠️  Warning: Only found $SELECTED_COUNT accessions (requested: $NUM_ACCESSIONS)"
    echo "   This means there are fewer matching accessions available in both files."
else
    echo "✓ Successfully selected $SELECTED_COUNT accessions"
fi

# Clean up temp file
rm -f "$TEMP_LOGAN_ACCESSIONS"

echo ""
echo "✓ Done!"
