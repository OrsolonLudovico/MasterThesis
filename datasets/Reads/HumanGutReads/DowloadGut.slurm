#!/bin/bash

#SBATCH --job-name download-humanGut-Reads
#SBATCH --output logs/download-humanGut-Reads.log
#SBATCH --error logs/download-humanGut-Reads-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --cpus-per-task 4
#SBATCH --partition allgroups
#SBATCH --mem 8G

# Script to download, extract and convert FASTQ to FASTA
# Reads URLs from input file

# ============================================
# CONFIGURAZIONE
# ============================================
INPUT_FILE="./gut-ftp.txt"          # File contenente gli URL da scaricare
FASTA_OUTPUT_DIR="./fasta_files"   # Cartella di output per i file FASTA

echo "Working directory: $(pwd)"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE file not found!"
    exit 1
fi

# Create directories for organization
mkdir -p "fastq_files"
mkdir -p "${FASTA_OUTPUT_DIR}"

echo "Starting download and conversion process..."
echo "Input file: $INPUT_FILE"
echo "=========================================="

# Read each line from input file
while IFS= read -r url || [ -n "$url" ]; do
    # Skip empty lines and comments
    [[ -z "$url" || "$url" =~ ^# ]] && continue
    
    # Extract filename from URL
    filename=$(basename "$url")
    echo ""
    echo "Processing: $filename"
    echo "---"
    
    # Download the file (with minimal progress output for SLURM compatibility)
    # wget -c automatically resumes incomplete downloads
    echo "Downloading from: $url"
    wget -c --progress=bar:force:noscroll "ftp://$url" -O "fastq_files/$filename"
    
    if [ $? -ne 0 ]; then
        echo "Error downloading $filename"
        continue
    fi
    
    # Extract if it's a .gz file
    if [[ "$filename" == *.gz ]]; then
        echo "Extracting $filename..."
        gunzip -c "fastq_files/$filename" > "fastq_files/${filename%.gz}"
        
        if [ $? -ne 0 ]; then
            echo "Error extracting $filename"
            continue
        fi
        
        extracted_file="${filename%.gz}"
    else
        extracted_file="$filename"
    fi
    
    # Convert FASTQ to FASTA
    echo "Converting ${extracted_file} to FASTA format..."
    fastq_path="fastq_files/$extracted_file"
    fasta_file="${FASTA_OUTPUT_DIR}/${extracted_file%.fastq}.fasta"
    
    # FASTQ to FASTA conversion using awk
    awk 'NR%4==1 {print ">" substr($0, 2)} NR%4==2 {print}' "$fastq_path" > "$fasta_file"
    
    if [ $? -eq 0 ]; then
        echo "Successfully converted to: $fasta_file"
    else
        echo "Error converting $extracted_file to FASTA"
    fi
    
done < "$INPUT_FILE"

echo ""
echo "=========================================="
echo "Process completed!"
echo "FASTQ files are in: fastq_files/"
echo "FASTA files are in: ${FASTA_OUTPUT_DIR}/"