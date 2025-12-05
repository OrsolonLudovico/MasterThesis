#!/bin/bash

# Script to download N accessions from both SRA and Logan
# Only downloads from Logan those successfully downloaded from SRA
# Usage: ./download_paired_sra_logan.sh <num_files> <accessions_list.txt> [sra_output_dir] [logan_output_dir] [logan_csv]

set -e

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <num_files> <accessions_list.txt> [sra_output_dir] [logan_output_dir] [logan_csv]"
    echo "Example: $0 10 list_accessions_human.txt ./sra_reads ./logan_unitigs"
    echo "Example: $0 10 list_accessions_human.txt ./sra_reads ./logan_unitigs custom_logan.csv"
    exit 1
fi

NUM_FILES="$1"
ACCESSIONS_FILE="$2"
SRA_OUTPUT_DIR="${3:-./sra_reads}"
LOGAN_OUTPUT_DIR="${4:-./logan_unitigs}"
LOGAN_CSV="${5:-logan_accessions_v1.1_SRA2023.csv}"

# Check if accessions file exists
if [ ! -f "$ACCESSIONS_FILE" ]; then
    echo "Error: File $ACCESSIONS_FILE not found!"
    exit 1
fi

# Check if Logan CSV exists
if [ ! -f "$LOGAN_CSV" ]; then
    echo "Error: Logan CSV file $LOGAN_CSV not found!"
    if [ "$LOGAN_CSV" = "logan_accessions_v1.1_SRA2023.csv" ]; then
        echo "Please extract it first: zstdcat logan_accessions_v1.1_SRA2023.csv.zst > logan_accessions_v1.1_SRA2023.csv"
    fi
    exit 1
fi

# Create output directories
mkdir -p "$SRA_OUTPUT_DIR"
mkdir -p "$LOGAN_OUTPUT_DIR"

# Temporary files
TEMP_ACCESSIONS="temp_accessions_to_download.txt"
TEMP_LOGAN_ACCESSIONS="temp_logan_accessions.txt"
SUCCESSFUL_ACCESSIONS="successful_accessions.txt"
FAILED_ACCESSIONS="failed_accessions.txt"

# Clean up previous temp files
rm -f "$TEMP_ACCESSIONS" "$TEMP_LOGAN_ACCESSIONS" "$SUCCESSFUL_ACCESSIONS" "$FAILED_ACCESSIONS"

# Extract accessions from Logan CSV (first column, remove quotes) - do this once at start
echo "Extracting accessions available in Logan..."
cut -d',' -f1 "$LOGAN_CSV" | tr -d '"' > "$TEMP_LOGAN_ACCESSIONS"
LOGAN_TOTAL=$(wc -l < "$TEMP_LOGAN_ACCESSIONS")
echo "  ✓ Found $LOGAN_TOTAL accessions available in Logan"
echo ""

# Count total available accessions in input file that are also in Logan
TOTAL_AVAILABLE=$(cut -d',' -f1 "$ACCESSIONS_FILE" | tr -d '"' | grep -F -f "$TEMP_LOGAN_ACCESSIONS" | wc -l)
echo "Total accessions available in both input file and Logan: $TOTAL_AVAILABLE"
if [ "$TOTAL_AVAILABLE" -lt "$NUM_FILES" ]; then
    echo "⚠ WARNING: Only $TOTAL_AVAILABLE accessions available, but you requested $NUM_FILES files."
    echo "⚠ The script will download as many as possible."
fi
echo ""

echo "=========================================="
echo "DOWNLOAD PAIRED SRA + LOGAN FILES"
echo "=========================================="
echo "Target number of files: $NUM_FILES"
echo "Accessions source: $ACCESSIONS_FILE"
echo "Logan CSV reference: $LOGAN_CSV"
echo "SRA output directory: $SRA_OUTPUT_DIR"
echo "Logan output directory: $LOGAN_OUTPUT_DIR"
echo "Start: $(date)"
echo "=========================================="
echo ""

# Function to get random accessions from the list
get_random_accessions() {
    local count=$1
    # Extract only the first column (accession ID) from CSV, remove quotes
    # Then filter to keep only accessions that exist in Logan
    shuf -n "$((count * 3))" "$ACCESSIONS_FILE" | cut -d',' -f1 | tr -d '"' | \
    grep -F -f "$TEMP_LOGAN_ACCESSIONS" | head -n "$count" >> "$TEMP_ACCESSIONS"
    # Remove duplicates
    sort -u "$TEMP_ACCESSIONS" -o "$TEMP_ACCESSIONS"
}

# Function to count successfully downloaded files
count_successful_downloads() {
    # Count only non-empty fasta files
    local count=0
    for file in "$SRA_OUTPUT_DIR"/*.fasta; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            count=$((count + 1))
        fi
    done
    echo "$count"
}

# Function to get accession from fasta filename
get_accession_from_file() {
    basename "$1" .fasta
}

# Initialize with first batch
echo "Step 1: Selecting initial batch of $NUM_FILES random accessions..."
get_random_accessions "$NUM_FILES"
echo "  ✓ Selected $(wc -l < "$TEMP_ACCESSIONS") accessions"
echo ""

# Loop until we have enough successful downloads
ITERATION=1
while true; do
    echo "=========================================="
    echo "ITERATION $ITERATION"
    echo "=========================================="
    
    # Download from SRA
    echo "Step 2: Downloading from SRA..."
    COUNT=0
    TOTAL=$(wc -l < "$TEMP_ACCESSIONS")
    
    while IFS= read -r accession; do
        COUNT=$((COUNT + 1))
        
        # Skip if already successfully downloaded
        if [ -f "$SRA_OUTPUT_DIR/${accession}.fasta" ]; then
            echo "  [$COUNT/$TOTAL] $accession - Already downloaded, skipping"
            continue
        fi
        
        echo "  [$COUNT/$TOTAL] Processing $accession..."
        
        # Try to download in FASTQ format with progress bar
        if fasterq-dump "$accession" --outdir "$SRA_OUTPUT_DIR" --concatenate-reads --threads 4 --progress 2>&1; then
            # Check if FASTQ file exists and is not empty
            if [ -f "$SRA_OUTPUT_DIR/${accession}.fastq" ] && [ -s "$SRA_OUTPUT_DIR/${accession}.fastq" ]; then
                echo "    Converting to FASTA format..."
                # Convert FASTQ to FASTA using awk
                awk 'NR%4==1 {print ">" substr($0, 2)} NR%4==2 {print}' "$SRA_OUTPUT_DIR/${accession}.fastq" > "$SRA_OUTPUT_DIR/${accession}.fasta"
                
                if [ -f "$SRA_OUTPUT_DIR/${accession}.fasta" ] && [ -s "$SRA_OUTPUT_DIR/${accession}.fasta" ]; then
                    # Remove FASTQ file to save space
                    rm -f "$SRA_OUTPUT_DIR/${accession}.fastq"
                    echo "    ✓ Successfully downloaded and converted $accession"
                else
                    echo "    ✗ Error converting to FASTA: $accession"
                    rm -f "$SRA_OUTPUT_DIR/${accession}.fastq" "$SRA_OUTPUT_DIR/${accession}.fasta"
                fi
            else
                echo "    ✗ Download completed but file is missing or empty: $accession"
                rm -f "$SRA_OUTPUT_DIR/${accession}.fastq"
            fi
        else
            echo "    ✗ Error downloading $accession (exit code: $?)"
            rm -f "$SRA_OUTPUT_DIR/${accession}.fastq"
        fi
        
    done < "$TEMP_ACCESSIONS"
    
    echo ""
    
    # Check how many files we have
    SUCCESSFUL_COUNT=$(count_successful_downloads)
    echo "Step 3: Verifying downloads..."
    echo "  Successfully downloaded: $SUCCESSFUL_COUNT / $NUM_FILES files"
    echo ""
    
    # Build list of successful accessions
    rm -f "$SUCCESSFUL_ACCESSIONS"
    for file in "$SRA_OUTPUT_DIR"/*.fasta; do
        if [ -f "$file" ]; then
            get_accession_from_file "$file" >> "$SUCCESSFUL_ACCESSIONS"
        fi
    done
    
    # Check if we have enough
    if [ "$SUCCESSFUL_COUNT" -ge "$NUM_FILES" ]; then
        echo "  ✓ Target reached!"
        break
    fi
    
    # Calculate how many more we need
    REMAINING=$((NUM_FILES - SUCCESSFUL_COUNT))
    echo "Step 4: Need $REMAINING more files. Checking for new accessions..."
    
    # Count how many unique accessions we've tried so far
    ATTEMPTED_COUNT=$(wc -l < "$TEMP_ACCESSIONS")
    
    # Check if we've exhausted all available accessions
    if [ "$ATTEMPTED_COUNT" -ge "$TOTAL_AVAILABLE" ]; then
        echo ""
        echo "========================================="
        echo "⚠ NO MORE ACCESSIONS AVAILABLE"
        echo "========================================="
        echo "All available accessions have been attempted."
        echo "Successfully downloaded: $SUCCESSFUL_COUNT files (target was $NUM_FILES)"
        echo "Total accessions attempted: $ATTEMPTED_COUNT / $TOTAL_AVAILABLE"
        echo ""
        echo "Cannot reach target of $NUM_FILES files."
        echo "Proceeding with the $SUCCESSFUL_COUNT files successfully downloaded."
        echo "========================================="
        break
    fi
    
    # Add some extra to account for potential failures (add 50% more than needed)
    EXTRA=$((REMAINING + REMAINING / 2))
    
    # Filter out already attempted accessions and add new ones
    cp "$TEMP_ACCESSIONS" "${TEMP_ACCESSIONS}.old"
    BEFORE_COUNT=$(wc -l < "$TEMP_ACCESSIONS")
    get_random_accessions "$EXTRA"
    AFTER_COUNT=$(wc -l < "$TEMP_ACCESSIONS")
    NEW_ADDED=$((AFTER_COUNT - BEFORE_COUNT))
    
    if [ "$NEW_ADDED" -eq 0 ]; then
        echo ""
        echo "========================================="
        echo "⚠ NO NEW ACCESSIONS FOUND"
        echo "========================================="
        echo "Could not find any new accessions to try."
        echo "Successfully downloaded: $SUCCESSFUL_COUNT files (target was $NUM_FILES)"
        echo ""
        echo "Cannot reach target of $NUM_FILES files."
        echo "Proceeding with the $SUCCESSFUL_COUNT files successfully downloaded."
        echo "========================================="
        break
    fi
    
    echo "  ✓ Added $NEW_ADDED new accessions to try (Total attempted: $AFTER_COUNT / $TOTAL_AVAILABLE)"
    echo ""
    
    ITERATION=$((ITERATION + 1))
done

echo ""
echo "=========================================="
echo "SRA DOWNLOAD COMPLETED"
echo "=========================================="
echo "Successfully downloaded $SUCCESSFUL_COUNT files from SRA"
echo ""

# Now download the same accessions from Logan
echo "=========================================="
echo "DOWNLOADING FROM LOGAN"
echo "=========================================="
echo "Downloading unitigs for successfully downloaded SRA files..."
echo ""

# Use the successful accessions file to download from Logan
if [ -f "$SUCCESSFUL_ACCESSIONS" ] && [ -s "$SUCCESSFUL_ACCESSIONS" ]; then
    # Download unitigs from Logan
    echo "Step 1: Downloading .zst files from Logan..."
    LOGAN_COUNT=0
    LOGAN_TOTAL=$(wc -l < "$SUCCESSFUL_ACCESSIONS")
    
    while IFS= read -r accession; do
        LOGAN_COUNT=$((LOGAN_COUNT + 1))
        echo "  [$LOGAN_COUNT/$LOGAN_TOTAL] Downloading $accession..."
        
        if aws s3 cp "s3://logan-pub/u/${accession}/${accession}.unitigs.fa.zst" "$LOGAN_OUTPUT_DIR/" --no-sign-request 2>&1; then
            echo "    ✓ Downloaded"
        else
            echo "    ✗ Error downloading from Logan"
        fi
    done < "$SUCCESSFUL_ACCESSIONS"
    
    echo ""
    echo "Step 2: Extracting .zst files..."
    EXTRACT_COUNT=0
    
    for file in "$LOGAN_OUTPUT_DIR"/*.unitigs.fa.zst; do
        if [ -f "$file" ]; then
            EXTRACT_COUNT=$((EXTRACT_COUNT + 1))
            echo "  [$EXTRACT_COUNT] Extracting $(basename "$file")..."
            
            if zstd -d "$file" -o "${file%.zst}" -q; then
                rm "$file"
                echo "    ✓ Done"
            else
                echo "    ✗ Error extracting $(basename "$file")"
            fi
        fi
    done
    
    echo ""
    echo "=========================================="
    echo "LOGAN DOWNLOAD COMPLETED"
    echo "=========================================="
    echo "Successfully downloaded and extracted unitigs"
fi

echo ""
echo "=========================================="
echo "FINAL SUMMARY"
echo "=========================================="
echo "End: $(date)"
echo ""
echo "SRA reads downloaded: $(ls -1 "$SRA_OUTPUT_DIR"/*.fasta 2>/dev/null | wc -l)"
echo "Logan unitigs downloaded: $(ls -1 "$LOGAN_OUTPUT_DIR"/*.unitigs.fa 2>/dev/null | wc -l)"
echo ""
echo "SRA output directory: $SRA_OUTPUT_DIR"
ls -lh "$SRA_OUTPUT_DIR"/*.fasta 2>/dev/null | head -5
echo ""
echo "Logan output directory: $LOGAN_OUTPUT_DIR"
ls -lh "$LOGAN_OUTPUT_DIR"/*.unitigs.fa 2>/dev/null | head -5
echo ""
echo "Successful accessions saved in: $SUCCESSFUL_ACCESSIONS"
echo "=========================================="

# Clean up temp files (keep successful_accessions.txt for reference)
rm -f "$TEMP_ACCESSIONS" "${TEMP_ACCESSIONS}.old" "$TEMP_LOGAN_ACCESSIONS"

echo ""
echo "✓ All operations completed successfully!"
