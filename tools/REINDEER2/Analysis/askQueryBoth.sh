#!/bin/bash

##################################
# Usage: ./askQueryBoth.sh <query_file> <output_dir> [indexDirComp] [indexDirUnc]
##################################

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <query_file> <output_dir> [indexDirComp] [indexDirUnc]"
    echo "Example: $0 query.fasta ./results /path/to/indexComp /path/to/indexUnc"
    exit 1
fi

query=$1
outputDir=$2
imagePath="/nfsd/bcb/bcbg/Orsolon/image.sif"

# Use provided index directories or defaults
if [ "$#" -ge 4 ]; then
    indexDirComp=$3
    indexDirUnc=$4
else
    # Default index directories #Change this to the paths of the indexes
    indexDirComp="NonPuoiUsrareIlPercorsoDiDefault"
    indexDirUnc="NonPuoiUsrareIlPercorsoDiDefault"
fi

cores=8

# Create output directory if it doesn't exist
mkdir -p "$outputDir"

##################################

echo "Query file: $query"
echo "Compressed index: $indexDirComp"
echo "Uncompressed index: $indexDirUnc"
echo "Output directory: $outputDir"
echo ""

# Get the base name of the query file (without path)
queryBaseName=$(basename "$query")

#THE OUTPUT IS FORCIBLY IN THE SAME FOLDER AS THE INDEX
#Run on uncompressed index
echo "Running query on uncompressed index..."
singularity exec -B /nfsd:/nfsd $imagePath /REINDEER2/target/release/Reindeer2 --mode query -f $query -i $indexDirUnc -t $cores -c false

#Run on compressed index
echo "Running query on compressed index..."
singularity exec -B /nfsd:/nfsd $imagePath /REINDEER2/target/release/Reindeer2 --mode query -f $query -i $indexDirComp -t $cores -c false

echo ""
echo "Queries completed. Moving results to $outputDir..."

# Create a timestamped subdirectory for the results
timestamp=$(date +%Y%m%d_%H%M%S)
queryName="${queryBaseName%.*}"  # Remove file extension
resultSubDir="$outputDir/${queryName}_${timestamp}"
mkdir -p "$resultSubDir"

echo "Creating results directory: $resultSubDir"

# Copy result files from uncompressed index (specifically query_results.csv)
uncResults="$indexDirUnc/query_results.csv"
if [ -f "$uncResults" ]; then
    cp "$uncResults" "$resultSubDir/${queryName}_uncompressed.csv"
    echo "Moved uncompressed results to: $resultSubDir/${queryName}_uncompressed.csv"
else
    echo "Warning: No recent results found in $indexDirUnc"
fi

# Copy result files from compressed index (specifically query_results.csv)
compResults="$indexDirComp/query_results.csv"
if [ -f "$compResults" ]; then
    cp "$compResults" "$resultSubDir/${queryName}_compressed.csv"
    echo "Moved compressed results to: $resultSubDir/${queryName}_compressed.csv"
else
    echo "Warning: No recent results found in $indexDirComp"
fi

echo ""
echo "Done! Results are in $resultSubDir"