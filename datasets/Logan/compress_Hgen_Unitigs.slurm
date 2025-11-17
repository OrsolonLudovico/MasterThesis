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
imagePath="/nfsd/bcb/bcbg/Orsolon/imageUSTARmod.sif"
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

# Master error log
master_err_log="$outputFolder/CompressGen-errors.log"

# Process each unitigs.fa file in the input directory
for input in "$inputFolder"/*.unitigs.fa; do

    # Skip if the glob didn't match any files
    [ -f "$input" ] || continue

    file=$(basename "$input")                            
    base="${file%.unitigs.fa}"                          

    echo "------------------------------------------------------------"
    echo "Processing file: $file"
    echo "Base name: $base"

    ### NEW CHECK: SKIP IF ALREADY COMPRESSED ###
    if [ -f "$outputFolder/${base}.ustar.fa" ]; then
        echo "Output already exists for $base — skipping."
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SKIPPED (already processed) $file" >> "$master_err_log"
        continue
    fi
    ############################################

    echo "Checking if unitigs file is compatible with USTAR (no sequence line >= 6,000,000 chars)..."

    # Temporarily disable strict error handling for this check
    set +e
    awk '/^>/ { next } length($0) >= 6000000 { exit 1 }' "$input"
    check_result=$?
    set -e

    if [ $check_result -eq 0 ]; then
        echo "File is compatible, running USTAR on $file..."
        echo "Command: singularity exec -B /nfsd:/nfsd $imagePath /USTAR/build/ustar -i $file -k $k -s+aa -x-c -o ${base}.ustar.fa"

        # Prepare per-file logs
        stdout_log="$outputFolder/${base}.ustar.log"
        stderr_log="$outputFolder/${base}.ustar.err"

        # Run USTAR (limit threads via OMP_NUM_THREADS), capture stdout/stderr
        if OMP_NUM_THREADS="$OMP_NUM_THREADS" singularity exec -B /nfsd:/nfsd "$imagePath" \
            /USTAR/build/ustar -i "$input" -k "$k" -s+aa -x-c -o "${base}.ustar.fa" \
            >"$stdout_log" 2>"$stderr_log"; then

            if [ -f "${base}.ustar.fa" ]; then
                mv "${base}.ustar.fa" "$outputFolder/"
                echo "Successfully produced: $outputFolder/${base}.ustar.fa"
            else
                echo "WARNING: USTAR finished but output file missing for $file" | tee -a "$master_err_log"
            fi

            # Cleanup USTAR-generated auxiliary files
            rm -f "${base}.ustar.counts" || true
            rm -f ./*.h5 || true

        else
            echo "##################################################################"
            echo "ERROR: USTAR failed on $file -- see logs:"
            echo "  stdout: $stdout_log"
            echo "  stderr: $stderr_log"
            echo "##################################################################"

            echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILURE for $file. See $stderr_log" >> "$master_err_log"
            continue
        fi

    else
        echo "##################################################################"
        echo "Skipping USTAR for $file - sequence line >= 6,000,000 characters"
        echo "##################################################################"

        echo "$(date '+%Y-%m-%d %H:%M:%S') - SKIPPED (too long) $file" >> "$master_err_log"
        continue
    fi

    echo "Progress: $(ls -1 "$outputFolder"/*.ustar.fa 2>/dev/null | wc -l) files completed so far"
done

echo "### JOB COMPLETED ###"
echo "End time: $(date)"
echo "Results saved in: $outputFolder"
echo "Total files processed: $(ls -1 "$outputFolder"/*.ustar.fa 2>/dev/null | wc -l)"
echo "Job runtime: $SECONDS seconds"

echo "Output directory size: $(du -sh "$outputFolder" 2>/dev/null || echo 'N/A')"