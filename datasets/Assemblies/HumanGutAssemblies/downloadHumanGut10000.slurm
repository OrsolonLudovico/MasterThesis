#!/bin/bash

#SBATCH --job-name download-human-gut-10000
#SBATCH --output logs/download-human-gut-10000.log
#SBATCH --error logs/download-human-gut-10000-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --cpus-per-task 8
#SBATCH --partition allgroups
#SBATCH --mem 16G

########################################VARIABLES#########################################
DIR="./human_gut_genomes_2024_and_more"
DOWNLOAD_FILE="human-gut-2024_and_more-samples.tsv"
MAX_SAMPLES=10000
YEAR=2025
PATH="/nfsd/bcb/bcbg/rossigno/tools/":$PATH
###########################################################################################

set -e  # Exit on error

# Function to download and convert a single metagenome assembly
download_and_convert(){
    accession=$1
    assembly=$2
    
    final_file="${accession}.fasta"
    
    # Check if final file already exists
    if [ -f "$final_file" ]; then
        echo "File $final_file already exists, skipping."
        return 0
    fi
    
    # Extract parts of accession for building NCBI FTP URL
    # Same structure as Salmonella downloads
    dir1=${accession:0:3}       # First three characters
    dir2=${accession:4:3}       # Next three characters after 'GCA_'
    dir3=${accession:7:3}       # Next three characters
    dir4=${accession:10:3}      # Next three characters
    
    # Build the URL for metagenomes (note: path is different - uses /metagenomes/ instead of /bacteria/)
    link=$(printf "https://ftp.ncbi.nlm.nih.gov/genomes/all/%s/%s/%s/%s/%s_%s/%s_%s_genomic.fna.gz" \
        "$dir1" "$dir2" "$dir3" "$dir4" "$accession" "$assembly" "$accession" "$assembly")
    
    echo "Downloading $link..."
    
    download="${accession}.fasta.gz"
    wget -q "$link" -O "${download}" || {
        echo "!!! Download failed. Please check the accession and assembly values. !!!"
        return 1
    }
    
    echo "Unzipping..."
    gzip -d -f "${download}"
    rm -f "${download}"
    
    echo "Done!"
}

echo "### JOB STARTED ###"

mkdir -p "$DIR" && cd "$DIR"
mkdir -p logs

# Check if the sample list file already exists
if [ ! -f "$DOWNLOAD_FILE" ]; then
    echo "*** DOWNLOADING LIST OF HUMAN GUT METAGENOME SAMPLES FROM $YEAR ***"
    
    echo "Fetching assembly summary from NCBI FTP..."
    
    # Download the complete GenBank metagenome assembly summary file
    # This is the same source used for Salmonella downloads
    wget -q -O assembly_summary_genbank.txt \
        "https://ftp.ncbi.nlm.nih.gov/genomes/genbank/metagenomes/assembly_summary.txt"
    
    # Filter for human gut metagenome and collect samples by year
    # Start with the specified year and go backwards until we have enough samples
    echo "Collecting assemblies starting from year $YEAR..."
    
    # Create temporary file for accumulating results
    > "$DOWNLOAD_FILE.tmp"
    
    current_year=$YEAR
    total_collected=0
    
    # Keep adding years until we reach MAX_SAMPLES or run out of data
    while [ $total_collected -lt $MAX_SAMPLES ] && [ $current_year -ge 2000 ]; do
        # Extract assemblies from current year
        year_count=$(grep -i "human gut metagenome" assembly_summary_genbank.txt | \
            awk -F'\t' -v year="$current_year" '$15 ~ year {print $1 "\t" $16}' | \
            wc -l)
        
        if [ $year_count -gt 0 ]; then
            echo "  Year $current_year: found $year_count assemblies"
            grep -i "human gut metagenome" assembly_summary_genbank.txt | \
                awk -F'\t' -v year="$current_year" '$15 ~ year {print $1 "\t" $16}' >> "$DOWNLOAD_FILE.tmp"
            total_collected=$((total_collected + year_count))
        fi
        
        # Move to previous year
        current_year=$((current_year - 1))
        
        # Stop if we have enough samples
        if [ $total_collected -ge $MAX_SAMPLES ]; then
            break
        fi
    done
    
    # Sort and limit to MAX_SAMPLES
    sort "$DOWNLOAD_FILE.tmp" | head -n $MAX_SAMPLES > "$DOWNLOAD_FILE"
    rm -f "$DOWNLOAD_FILE.tmp"
    
    # Clean up
    rm -f assembly_summary_genbank.txt
    
    total_samples=$(wc -l < "$DOWNLOAD_FILE")
    echo ""
    echo "Collected $total_samples human gut metagenome assemblies (from $YEAR backwards)"
    
    if [ $total_samples -eq 0 ]; then
        echo "ERROR: No assemblies found. Check network connection."
        exit 1
    fi
else
    echo "*** USING EXISTING LIST: $DOWNLOAD_FILE ***"
    total_samples=$(wc -l < "$DOWNLOAD_FILE")
    echo "Total assemblies in list: $total_samples"
fi

# Select up to MAX_SAMPLES assemblies (deterministically - first N lines)
samples_to_download=$(head -n "$MAX_SAMPLES" "$DOWNLOAD_FILE")
count=$(echo "$samples_to_download" | wc -l)
echo "*** WILL DOWNLOAD $count ASSEMBLIES ***"
echo

# Download each assembly with progress counter
current=0
while IFS=$'\t' read -r accession assembly; do
    current=$((current + 1))
    echo ""
    echo "==================================================================="
    echo "*** DOWNLOADING $accession ($current/$count) ***"
    echo "==================================================================="
    download_and_convert "$accession" "$assembly"
done <<< "$samples_to_download"

echo ""
echo "### JOB TERMINATED ###"
echo "Successfully downloaded $current assemblies"

