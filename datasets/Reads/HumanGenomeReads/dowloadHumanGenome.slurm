#!/bin/bash

#SBATCH --job-name download-humanGenome-Reads
#SBATCH --output logs/download-humanGenome-Reads.log
#SBATCH --error logs/download-humanGenome-Reads-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --cpus-per-task 4
#SBATCH --partition allgroups
#SBATCH --mem 1000G

# Script to download all .gz files from NCBI FTP directory,
# extract and convert FASTQ to FASTA

# ============================================
# CONFIGURAZIONE
# ============================================
BASE_URL="ftp://ftp.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/HG004_NA24143_mother/NIST_Illumina_2x250bps/reads/"
FASTA_OUTPUT_DIR="./HumanGenomeUnc"   # Cartella di output per i file FASTA

echo "Working directory: $(pwd)"

# Create directories for organization
mkdir -p "fastq_files"
mkdir -p "${FASTA_OUTPUT_DIR}"

echo "Starting download and conversion process..."
echo "Base URL: $BASE_URL"
echo "=========================================="

# Get list of .gz files from FTP directory
echo "Fetching file list from FTP server..."
file_list=$(curl -s "$BASE_URL" | grep -oE '[^[:space:]]+\.fastq\.gz' | sort -u)

if [ -z "$file_list" ]; then
    echo "Error: No .gz files found or unable to connect to FTP server"
    exit 1
fi

echo "Found files:"
echo "$file_list"
echo "=========================================="

# Process each file
while IFS= read -r filename; do
    # Skip empty lines
    [[ -z "$filename" ]] && continue
    
    echo ""
    echo "Processing: $filename"
    echo "---"
    
    # Full URL for download
    full_url="${BASE_URL}${filename}"
    
    # Download the file
    echo "Downloading from: $full_url"
    wget -c --progress=bar:force:noscroll "$full_url" -O "fastq_files/$filename"
    
    if [ $? -ne 0 ]; then
        echo "Error downloading $filename"
        continue
    fi
    
    # Extract the .gz file
    echo "Extracting $filename..."
    gunzip -c "fastq_files/$filename" > "fastq_files/${filename%.gz}"
    
    if [ $? -ne 0 ]; then
        echo "Error extracting $filename"
        continue
    fi
    
    extracted_file="${filename%.gz}"
    
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
    
done <<< "$file_list"

echo ""
echo "=========================================="
echo "Process completed!"
echo "FASTQ files are in: fastq_files/"
echo "FASTA files are in: ${FASTA_OUTPUT_DIR}/"