#!/bin/bash

# Script that runs queryBoth.sh, then analisi_differenze.py, and cleans up temporary files

# Check if query file argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <query_file>"
    echo "Example: $0 Queries/Query1/Query1_SAL_AA7174AA.fasta"
    exit 1
fi

query="$1"

# Check if query file exists
if [ ! -f "$query" ]; then
    echo "Error: Query file '$query' not found."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extract query name without extension for output files
queryname=$(basename "$query" .fasta)
queryname=$(basename "$queryname" .fa)

# Get the directory of the query file
query_dir=$(dirname "$query")

# Define output files
output_unc="${query_dir}/${queryname}_unc_res.txt"
output_comp="${query_dir}/${queryname}_comp_res.txt"

echo "========================================"
echo "STEP 1: Running queryBoth.sh..."
echo "========================================"

# Run queryBoth.sh
bash "${SCRIPT_DIR}/queryBoth.sh" "$query"

# Check if queryBoth.sh completed successfully
if [ $? -ne 0 ]; then
    echo "Error: queryBoth.sh failed."
    exit 1
fi

echo ""
echo "========================================"
echo "STEP 2: Running analisi_differenze.py..."
echo "========================================"

# Run the analysis script
python3 "${SCRIPT_DIR}/analisi_differenze.py" "$output_unc" "$output_comp"

# Check if analisi_differenze.py completed successfully
if [ $? -ne 0 ]; then
    echo "Error: analisi_differenze.py failed."
    echo "Temporary files have NOT been deleted."
    exit 1
fi

echo ""
echo "========================================"
echo "STEP 3: Cleaning up temporary files..."
echo "========================================"

# Remove temporary result files
if [ -f "$output_unc" ]; then
    rm "$output_unc"
    echo "Removed: $output_unc"
fi

if [ -f "$output_comp" ]; then
    rm "$output_comp"
    echo "Removed: $output_comp"
fi

echo ""
echo "========================================"
echo "Analysis complete!"
echo "========================================"
echo "Results saved in: ${query_dir}/${queryname}_unc_res_comparisons.txt"
