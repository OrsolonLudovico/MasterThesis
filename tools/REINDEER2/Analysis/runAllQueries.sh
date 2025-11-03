#!/bin/bash

##################################
# Usage: ./runAllQueries.sh <directory> <indexDirComp> <indexDirUnc>
##################################

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <directory> <indexDirComp> <indexDirUnc>"
    echo "This script runs askQueryBoth.sh for all files in the directory"
    echo "Results will be saved in the same directory"
    echo "Example: $0 ./queries /path/to/indexComp /path/to/indexUnc"
    exit 1
fi

queryDir=$1
indexDirComp=$2
indexDirUnc=$3

# Check if query directory exists
if [ ! -d "$queryDir" ]; then
    echo "Error: Directory '$queryDir' does not exist"
    exit 1
fi

# Check if compressed index directory exists
if [ ! -d "$indexDirComp" ]; then
    echo "Error: Compressed index directory '$indexDirComp' does not exist"
    exit 1
fi

# Check if uncompressed index directory exists
if [ ! -d "$indexDirUnc" ]; then
    echo "Error: Uncompressed index directory '$indexDirUnc' does not exist"
    exit 1
fi

# Get the directory where this script is located
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
askQueryScript="$scriptDir/askQueryBoth.sh"

# Check if askQueryBoth.sh exists
if [ ! -f "$askQueryScript" ]; then
    echo "Error: askQueryBoth.sh not found at $askQueryScript"
    exit 1
fi

# Check that all files in the directory are FASTA files (no subdirectories check)
echo "Checking files in $queryDir..."
for file in "$queryDir"/*; do
    # Skip if no files exist
    if [ ! -e "$file" ]; then
        echo "Error: No files found in $queryDir"
        exit 1
    fi
    
    # Skip subdirectories
    if [ -d "$file" ]; then
        continue
    fi
    
    # Check if file is FASTA (by extension)
    if [[ ! "$file" =~ \.(fasta|fa|fna)$ ]]; then
        echo "Error: Non-FASTA file found: $(basename "$file")"
        echo "All files in the directory must be FASTA files (.fasta, .fa, .fna)"
        exit 1
    fi
done

echo "========================================"
echo "Running queries for all FASTA files"
echo "Directory: $queryDir"
echo "Compressed index: $indexDirComp"
echo "Uncompressed index: $indexDirUnc"
echo "Results will be saved in: $queryDir"
echo "========================================"
echo ""

# Count total FASTA files (excluding subdirectories)
totalFiles=$(find "$queryDir" -maxdepth 1 -type f \( -name "*.fasta" -o -name "*.fa" -o -name "*.fna" \) | wc -l)

if [ "$totalFiles" -eq 0 ]; then
    echo "No FASTA files found in $queryDir"
    exit 0
fi

echo "Found $totalFiles FASTA file(s) to process"
echo ""

# Counter for processed files
counter=0

# Process each FASTA file in the query directory
for fastaFile in "$queryDir"/*.fasta "$queryDir"/*.fa "$queryDir"/*.fna; do
    # Check if file exists (handles case where no files match the pattern)
    if [ ! -f "$fastaFile" ]; then
        continue
    fi
    
    counter=$((counter + 1))
    echo "========================================"
    echo "[$counter/$totalFiles] Processing: $(basename "$fastaFile")"
    echo "========================================"
    
    # Run askQueryBoth.sh with the specified indices
    "$askQueryScript" "$fastaFile" "$queryDir" "$indexDirComp" "$indexDirUnc"
    
    exitCode=$?
    
    if [ $exitCode -eq 0 ]; then
        echo "✓ Successfully processed: $(basename "$fastaFile")"
        
        # Find the result directory that was just created (most recent one)
        queryName="${fastaFile%.*}"
        queryName=$(basename "$queryName")
        resultDir=$(find "$queryDir" -maxdepth 1 -type d -name "${queryName}_*" | sort -r | head -1)
        
        if [ -n "$resultDir" ] && [ -d "$resultDir" ]; then
            echo "Running comparison analysis on: $resultDir"
            
            # Find the uncompressed and compressed CSV files
            uncFile=$(find "$resultDir" -maxdepth 1 -name "*_uncompressed.csv" -type f | head -1)
            compFile=$(find "$resultDir" -maxdepth 1 -name "*_compressed.csv" -type f | head -1)
            
            if [ -n "$uncFile" ] && [ -n "$compFile" ]; then
                python3 "$scriptDir/compare_results.py" "$uncFile" "$compFile"
                echo "✓ Comparison analysis completed"
            else
                echo "⚠ Warning: Could not find CSV files for comparison"
            fi
        else
            echo "⚠ Warning: Could not find result directory"
        fi
    else
        echo "✗ Error processing: $(basename "$fastaFile") (exit code: $exitCode)"
    fi
    
    echo ""
done

echo "========================================"
echo "All queries completed!"
echo "Processed $counter file(s)"
echo "Results are in: $queryDir"
echo "========================================"
