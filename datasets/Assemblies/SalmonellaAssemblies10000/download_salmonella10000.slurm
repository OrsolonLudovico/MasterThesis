#!/bin/bash

#SBATCH --job-name download-salmonella10000
#SBATCH --output logs/download-salmonella10000.txt
#SBATCH --error logs/download-salmonella10000.txt
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --cpus-per-task 1
#SBATCH --partition allgroups
#SBATCH --mem 4G

########################################VARIABLES#########################################
DIR="./salmonella_genomes_2024"
DOWNLOAD_FILE="salmonella-2024-assemblies.csv"
MAX_GENOMES=10000
YEAR=2024
###########################################################################################

# download function
download_accession(){
accession=$1
assembly=$2

# Check if file already exists
final_file="${accession}.fasta"
if [ -f "$final_file" ]; then
    echo
    echo "File $final_file already exists, skipping download."
    echo
    return 0
fi

# Extract parts of accession
dir1=${accession:0:3}       # First three characters
dir2=${accession:4:3}       # Next three characters after 'GCA_'
dir3=${accession:7:3}       # Next three characters
dir4=${accession:10:3}      # Next three characters

# Build the URL
link=$(printf "https://ftp.ncbi.nlm.nih.gov/genomes/all/%s/%s/%s/%s/%s_%s/%s_%s_genomic.fna.gz" \
    "$dir1" "$dir2" "$dir3" "$dir4" "$accession" "$assembly" "$accession" "$assembly")

# Download
echo
echo "Downloading $link..."

download="${accession}.fasta.gz"
wget -q "$link" -O "${download}" || {
    echo "!!! Download failed. Please check the accession and assembly values. !!!"
    exit 1
}

echo "Unzipping..."

gzip -d -f "${download}"
rm -f "${download}"

echo "Done!"
echo
}

echo "### JOB STARTED ###"

mkdir -p $DIR && cd $DIR 
mkdir -p logs

# Check if the CSV file already exists
if [ ! -f "$DOWNLOAD_FILE" ]; then
    echo "*** DOWNLOADING LIST OF SALMONELLA GENOMES FROM $YEAR ***"
    
    echo "Fetching assembly summary from NCBI FTP..."
    
    # Download the complete GenBank assembly summary file
    wget -q -O assembly_summary_genbank.txt \
        "https://ftp.ncbi.nlm.nih.gov/genomes/genbank/bacteria/assembly_summary.txt"
    
    # Filter for Salmonella (organism_name contains "Salmonella")
    # Filter by seq_rel_date (column 15) for the specified year
    # Extract assembly_accession (column 1) and asm_name (column 16)
    grep "Salmonella" assembly_summary_genbank.txt | \
        awk -F'\t' -v year="$YEAR" '$15 ~ year {print $1 "\t" $16}' | \
        sort > "$DOWNLOAD_FILE"
    
    # Clean up
    rm -f assembly_summary_genbank.txt
    
    total_genomes=$(wc -l < "$DOWNLOAD_FILE")
    echo "Found $total_genomes Salmonella genomes from $YEAR"
    
    if [ $total_genomes -eq 0 ]; then
        echo "WARNING: No genomes found for $YEAR. Trying without year filter..."
        
        # Fallback: get all Salmonella genomes if year filter returns nothing
        wget -q -O assembly_summary_genbank.txt \
            "https://ftp.ncbi.nlm.nih.gov/genomes/genbank/bacteria/assembly_summary.txt"
        
        grep "Salmonella" assembly_summary_genbank.txt | \
            tail -n +3 | \
            awk -F'\t' '{print $1 "\t" $16}' | \
            sort | \
            head -n $MAX_GENOMES > "$DOWNLOAD_FILE"
        
        rm -f assembly_summary_genbank.txt
        total_genomes=$(wc -l < "$DOWNLOAD_FILE")
        echo "Found $total_genomes Salmonella genomes (all years)"
    fi
else
    echo "*** USING EXISTING LIST: $DOWNLOAD_FILE ***"
    total_genomes=$(wc -l < "$DOWNLOAD_FILE")
    echo "Total genomes in list: $total_genomes"
fi

# Select up to MAX_GENOMES genomes (deterministically - first N lines)
genomes_to_download=$(head -n $MAX_GENOMES "$DOWNLOAD_FILE")
count=$(echo "$genomes_to_download" | wc -l)
echo "*** WILL DOWNLOAD $count GENOMES ***"
echo

# Download each genome with progress counter
current=0
while IFS=$'\t' read -r accession assembly; do
	current=$((current + 1))
  	echo "*** DOWNLOADING $accession ($current/$count) ***"
	download_accession "$accession" "$assembly"
done <<< "$genomes_to_download"

echo "### JOB TERMINATED ###"

