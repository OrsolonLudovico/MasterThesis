#!/bin/bash

# Script to run run_analysis.sh on every file in a specified folder

# Check if folder argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <folder_path>"
    echo "Example: $0 FulgorQueryTest/Queries/Query1"
    echo "         $0 FulgorQueryTest/HumanGutQuery"
    exit 1
fi

folder="$1"

# Check if folder exists
if [ ! -d "$folder" ]; then
    echo "Error: Folder '$folder' not found."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Counter for processed files
count=0
success=0
failed=0

echo "========================================"
echo "Batch Analysis Started"
echo "========================================"
echo "Searching for .fasta and .fa files in: $folder"
echo ""

# Process all .fasta and .fa files in the folder
for file in "$folder"/*.fasta "$folder"/*.fa; do
    # Check if file exists (in case no files match the pattern)
    if [ ! -f "$file" ]; then
        continue
    fi
    
    count=$((count + 1))
    
    echo ""
    echo "========================================"
    echo "Processing file $count: $(basename "$file")"
    echo "========================================"
    
    # Run run_analysis.sh on the file
    bash "${SCRIPT_DIR}/run_analysis.sh" "$file"
    
    # Check if the analysis was successful
    if [ $? -eq 0 ]; then
        success=$((success + 1))
        echo " Successfully processed: $(basename "$file")"
    else
        failed=$((failed + 1))
        echo " Failed to process: $(basename "$file")"
    fi
done

# Print summary
echo ""
echo "========================================"
echo "Batch Analysis Complete"
echo "========================================"
echo "Total files found: $count"
echo "Successfully processed: $success"
echo "Failed: $failed"
echo "========================================"

# Exit with error code if any files failed
if [ $failed -gt 0 ]; then
    exit 1
fi
