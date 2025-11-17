#!/bin/bash
#SBATCH --job-name Orsolon-CompressGenUstar
#SBATCH --output CompressGen.log
#SBATCH --error CompressGen-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 2-00:00:00
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 16
#SBATCH --partition allgroups
#SBATCH --mem 100G

### CONFIGURATION VARIABLES #####################################################
#### I'm using the modified version of USTAR now ####
imagePath="/nfsd/bcb/bcbg/Orsolon/imageUSTARmod.sif"
### WARNING: DO NOT PUT THE "/" AT THE END OF INPUT FOLDER
inputFolder="/nfsd/bcb/bcbg/Orsolon/datasetsOrsolon/LoganUnitigs/HumanGenomeUnitigs/1000/unitigs"
k=31
outputFolder="./compressed"

# Create output directory if it doesn't exist
mkdir -p "$outputFolder"

set -e
echo "Processing all .unitigs.fa files from: $inputFolder"

# Count total unitigs files first
totalFiles=$(ls -1 "$inputFolder"/*.unitigs.fa 2>/dev/null | wc -l)
echo "Total .unitigs.fa files found: $totalFiles"

# Set default OMP threads (use SLURM_CPUS_PER_TASK if available)
: "${OMP_NUM_THREADS:=${SLURM_CPUS_PER_TASK:-8}}"
export OMP_NUM_THREADS

# Process each unitigs.fa file in the input directory
for input in "$inputFolder"/*.unitigs.fa; do

    # Skip if the glob didn't match any files
    [ -f "$input" ] || continue

    file=$(basename "$input")                            # ex: "sample.unitigs.fa"
    base="${file%.unitigs.fa}"                          # ex: "sample"

    echo "------------------------------------------------------------"
    echo "Processing file: $file"
    echo "Base name: $base"

    # USTAR cannot process SEQUENCE lines >= 6,000,000 characters
    # We check only **non-header** lines (skip lines starting with '>')
    echo "Checking if unitigs file is compatible with USTAR (no sequence line >= 6,000,000 chars)..."

    # Temporarily disable strict error handling for this check
    set +e
    # awk: skip header lines, if any sequence line is >= 6000000 exit with code 1
    awk '/^>/ { next } length($0) >= 6000000 { exit 1 }' "$input"
    check_result=$?
    set -e

    if [ $check_result -eq 0 ]; then
        echo "File is compatible, running USTAR on $file..."
        echo "Command: singularity exec -B /nfsd:/nfsd $imagePath /USTAR/build/ustar -i $file -k $k -s+aa -x-c -o ${base}.ustar.fa"

        # Run USTAR (limit threads via OMP_NUM_THREADS)
        OMP_NUM_THREADS="$OMP_NUM_THREADS" singularity exec -B /nfsd:/nfsd "$imagePath" /USTAR/build/ustar -i "$input" -k $k -s+aa -x-c -o "${base}.ustar.fa"

        # Move final compressed result to output directory
        if [ -f "${base}.ustar.fa" ]; then
            mv "${base}.ustar.fa" "$outputFolder/"
            echo "Successfully produced: $outputFolder/${base}.ustar.fa"
        else
            echo "ERROR: USTAR did not produce ${base}.ustar.fa for $file"
        fi

        # Cleanup USTAR-generated auxiliary files (keep original .unitigs.fa intact)
        rm -f "${base}.ustar.counts" || true
        rm -f ./*.h5 || true

    else
        echo "##################################################################"
        echo "Skipping USTAR for $file - unitigs file has sequence lines >= 6,000,000 characters"
        echo "  (USTAR cannot handle sequence lines >= 6,000,000 characters)"
        echo "##################################################################"
        # NON cancelliamo il file di input: lasciamo l'utente decidere come gestirlo
        continue
    fi

    echo "Progress: $(ls -1 "$outputFolder"/*.ustar.fa 2>/dev/null | wc -l) files completed so far"
done

echo "### JOB COMPLETED ###"
echo "End time: $(date)"
echo "Results saved in: $outputFolder"
echo "Total files processed: $(ls -1 "$outputFolder"/*.ustar.fa 2>/dev/null | wc -l)"
echo "Job runtime: $SECONDS seconds"

# Optional: show disk usage of output directory
echo "Output directory size: $(du -sh "$outputFolder" 2>/dev/null || echo "N/A")"