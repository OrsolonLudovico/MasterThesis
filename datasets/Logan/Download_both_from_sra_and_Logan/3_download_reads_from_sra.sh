#!/bin/bash

# Script to download raw reads using SRA Toolkit (fasterq-dump)
# Usage: ./download_reads.sh <accessions_file.txt> [output_dir]

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <accessions_file.txt> [output_dir]"
    echo "Example: $0 human_20_random.txt ./reads_output"
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
echo "Downloading reads for $TOTAL accessions"
echo "Output directory: $OUTPUT_DIR"
echo "Start: $(date)"
echo "=========================================="

# Counter for progress
COUNT=0

# Download reads for each accession
while IFS= read -r accession; do
    COUNT=$((COUNT + 1))
    echo ""
    echo "[$COUNT/$TOTAL] Processing $accession..."
    
    # Use fasterq-dump to download reads
    # --concatenate-reads: force paired-end reads into a single interleaved file
    # --outdir: output directory
    # --threads: number of threads (adjust as needed)
    if fasterq-dump "$accession" --outdir "$OUTPUT_DIR" --concatenate-reads --threads 4 --progress; then
        echo "  ✓ Successfully downloaded $accession"
    else
        echo "  ✗ Error downloading $accession"
    fi
    
done < "$ACCESSIONS_FILE"

echo ""
echo "=========================================="
echo "Download completed: $(date)"
echo "Reads saved in: $OUTPUT_DIR"
echo "=========================================="

# Show summary of downloaded files
echo ""
echo "Summary of downloaded files:"
ls -lh "$OUTPUT_DIR"/*.fastq 2>/dev/null || echo "No FASTQ files found"
