#!/bin/bash
####################################################################
# Script to query GGCAT graphs and compare results
####################################################################

# Check if two arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <graph1_folder> <graph2_folder>"
    echo "Example: $0 ./testDataset_GGCAT ./Test2_GGCAT"
    exit 1
fi

graph1_folder="$1"
graph2_folder="$2"
queryFolder="./Queries"
imagePath="/nfsd/bcb/bcbg/Orsolon/image.sif"
k=31

# Check if directories exist
if [ ! -d "$graph1_folder" ]; then
    echo "Error: Directory $graph1_folder does not exist"
    exit 1
fi

if [ ! -d "$graph2_folder" ]; then
    echo "Error: Directory $graph2_folder does not exist"
    exit 1
fi

if [ ! -d "$queryFolder" ]; then
    echo "Error: Query folder $queryFolder does not exist"
    exit 1
fi

# Get graph files
graph1="$graph1_folder/resGGCAT.txt"
graph2="$graph2_folder/resGGCAT.txt"

if [ ! -f "$graph1" ]; then
    echo "Error: Graph file $graph1 does not exist"
    exit 1
fi

if [ ! -f "$graph2" ]; then
    echo "Error: Graph file $graph2 does not exist"
    exit 1
fi

# Create output directories
output1_dir="${graph1_folder}/query_results"
output2_dir="${graph2_folder}/query_results"
mkdir -p "$output1_dir"
mkdir -p "$output2_dir"

# Get base names for labeling
graph1_name=$(basename "$graph1_folder")
graph2_name=$(basename "$graph2_folder")

echo "========================================"
echo "GGCAT Query Execution"
echo "========================================"
echo "Graph 1: $graph1_name"
echo "Graph 2: $graph2_name"
echo "Query folder: $queryFolder"
echo ""

# Find all query files
query_files=$(find "$queryFolder" -type f \( -name "*.fasta" -o -name "*.fa" -o -name "*.fna" \) | sort)

if [ -z "$query_files" ]; then
    echo "Error: No query files found in $queryFolder"
    exit 1
fi

# Process each query file
for query_file in $query_files; do
    query_name=$(basename "$query_file")
    echo "----------------------------------------"
    echo "Processing query: $query_name"
    echo "----------------------------------------"
    
    # Output files
    output1="$output1_dir/${query_name%.fasta}_result.txt"
    output2="$output2_dir/${query_name%.fasta}_result.txt"
    
    # Query graph 1
    echo "Querying $graph1_name..."
    srun singularity exec --bind /nfsd:/nfsd "$imagePath" /ggcat query "$graph1" "$query_file" -k $k -c > "$output1" 2>&1
    echo "  Result saved to: $output1"
    
    # Query graph 2
    echo "Querying $graph2_name..."
    srun singularity exec --bind /nfsd:/nfsd "$imagePath" /ggcat query "$graph2" "$query_file" -k $k -c > "$output2" 2>&1
    echo "  Result saved to: $output2"
    
    echo ""
done

echo "========================================"
echo "All queries completed!"
echo "========================================"
echo "Results saved in:"
echo "  - $output1_dir/"
echo "  - $output2_dir/"
