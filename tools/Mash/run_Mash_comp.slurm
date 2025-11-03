#!/bin/bash

#SBATCH --job-name Mash_GutReads_comp
#SBATCH --output Mash_GutReads_comp.log
#SBATCH --error Mash_GutReads_comp-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 16
#SBATCH --partition allgroups
#SBATCH --mem 200G

# Script to compare genomes with Mash
# Output: distance matrix between all fasta files

# Singularity container
CONTAINER_IMAGE="/nfsd/bcb/bcbg/Orsolon/image.sif"
MASH_PATH="/Mash/mash-Linux64-v2.3/mash"

# Directory with fasta files, ####################DO NOT PUT / IN THE END
INPUT_DIR="/nfsd/bcb/bcbg/Orsolon/datasetsOrsolon/Reads/HumanGut/HumanGutCompressed"

# Extract directory name for output files
DIR_NAME=$(basename "$INPUT_DIR")
SKETCH_FILE="${DIR_NAME}.msh"
OUTPUT_FILE="${DIR_NAME}_table.txt"

# Mash parameters
THREADS=4          # Number of threads (adjust based on your system)
KMER_SIZE=31       # K-mer size (THE DEFAULT WAS 21)
SKETCH_SIZE=1000   # Sketch size (default)

echo "=== Mash distance analysis between genomes ==="
echo "Input directory: $INPUT_DIR"
echo "Threads: $THREADS"
echo ""

# Create list of fasta files (both .fasta and .ustar.fa)
files=("$INPUT_DIR"/*.fasta "$INPUT_DIR"/*.ustar.fa)

# Remove non-existent patterns (in case one pattern doesn't match)
existing_files=()
for f in "${files[@]}"; do
    if [ -f "$f" ]; then
        existing_files+=("$f")
    fi
done
files=("${existing_files[@]}")

# Check that files exist
if [ ${#files[@]} -eq 0 ]; then
    echo "Error: no .fasta or .ustar.fa files found in $INPUT_DIR"
    exit 1
fi

echo "Files found: ${#files[@]}"
for f in "${files[@]}"; do
    echo "  - $(basename $f)"
done
echo ""

# Step 1: Create sketch for all genomes together (MUCH faster!)
echo "Creating combined sketch..."
srun singularity exec -B /nfsd:/nfsd "$CONTAINER_IMAGE" $MASH_PATH sketch -p $THREADS -k $KMER_SIZE -s $SKETCH_SIZE -o "$DIR_NAME" "${files[@]}"

echo ""
echo "Sketch created: $SKETCH_FILE"
echo ""

# Step 2: Compare all-vs-all with the sketch (single command!)
echo "Computing all-vs-all distances..."
srun singularity exec -B /nfsd:/nfsd "$CONTAINER_IMAGE" $MASH_PATH dist -p $THREADS -t "$SKETCH_FILE" "$SKETCH_FILE" > "$OUTPUT_FILE"

echo "All comparisons completed in one step!"

echo ""
echo "=== Analysis completed ==="
echo "Results saved in: $OUTPUT_FILE"
echo ""
echo "First lines of the result:"
head -n 10 "$OUTPUT_FILE"
