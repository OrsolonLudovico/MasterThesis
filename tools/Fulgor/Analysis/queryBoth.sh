#!/bin/bash

# Check if query file argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <query_file>"
    echo "Example: $0 query.fasta"
    exit 1
fi

query="$1"

# Check if query file exists
if [ ! -f "$query" ]; then
    echo "Error: Query file '$query' not found."
    exit 1
fi

# Extract query name without extension for output files
queryname=$(basename "$query" .fasta)
queryname=$(basename "$queryname" .fa)

# Get the directory of the query file
query_dir=$(dirname "$query")

# Index files########################################Change this to change the index
index_unc="/nfsd/bcb/bcbg/Orsolon/Fulgor/READS/HumanGutReads/IndexGutUnc.fur"
index_comp="/nfsd/bcb/bcbg/Orsolon/Fulgor/READS/HumanGutReads/IndexGutComp.fur"

# Output files (created in the same directory as the query)
output_unc="${query_dir}/${queryname}_unc_res.txt"
output_comp="${query_dir}/${queryname}_comp_res.txt"

############
nThreads=8

echo "Querying uncompressed index..."
singularity exec -B /nfsd:/nfsd "/nfsd/bcb/bcbg/Orsolon/image.sif" /fulgor/build/fulgor pseudoalign -i "$index_unc" \
 -q "$query" -t "$nThreads" --verbose -o "$output_unc"

echo "Querying compressed index..."
singularity exec -B /nfsd:/nfsd "/nfsd/bcb/bcbg/Orsolon/image.sif" /fulgor/build/fulgor pseudoalign -i "$index_comp" \
 -q "$query" -t "$nThreads" --verbose -o "$output_comp"

echo "Query completed!"
echo "Results saved to:"
echo "  - Uncompressed index: $output_unc"
echo "  - Compressed index: $output_comp"