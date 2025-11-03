#!/bin/bash

##################It prepares the list of files needed for Fulgor's exexution

# Hard-coded seed for random selection
SEED=123

# Function to display usage
usage() {
    echo "Usage: $0 <input_directory> <number_of_files> <output_file>"
    echo "  input_directory: Directory containing the files to process"
    echo "  number_of_files: Number of files to select (0 means all files)"
    echo "  output_file: Name of the output file to save the list"
    exit 1
}

# Check if exactly 3 arguments are provided
if [ $# -ne 3 ]; then
    echo "Error: Exactly 3 arguments are required."
    usage
fi

INPUT_DIR="$1"
NUM_FILES="$2"
OUTPUT_FILE="$3"

# Validate input directory
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory '$INPUT_DIR' does not exist."
    exit 1
fi

# Validate number of files argument
if ! [[ "$NUM_FILES" =~ ^[0-9]+$ ]]; then
    echo "Error: Number of files must be a non-negative integer."
    exit 1
fi

# Check if directory contains any files
TOTAL_FILES=$(find "$INPUT_DIR" -type f | wc -l)
if [ $TOTAL_FILES -eq 0 ]; then
    echo "Error: No files found in directory '$INPUT_DIR'."
    exit 1
fi

echo "Found $TOTAL_FILES files in directory '$INPUT_DIR'"

# Handle different cases for number of files
if [ $NUM_FILES -eq 0 ]; then
    echo "Selecting all $TOTAL_FILES files"
    find "$INPUT_DIR" -type f | sort > "$OUTPUT_FILE"
elif [ $NUM_FILES -gt $TOTAL_FILES ]; then
    echo "Error: Requested $NUM_FILES files but only $TOTAL_FILES files are available in the directory."
    exit 1
else
    echo "Selecting first $NUM_FILES files out of $TOTAL_FILES (in directory order)"
    # Select first N files maintaining directory order
    find "$INPUT_DIR" -type f | sort | head -n "$NUM_FILES" > "$OUTPUT_FILE"
fi

# Verify output file was created successfully
if [ -f "$OUTPUT_FILE" ]; then
    SELECTED_COUNT=$(wc -l < "$OUTPUT_FILE")
    echo "Successfully created '$OUTPUT_FILE' with $SELECTED_COUNT file paths"
else
    echo "Error: Failed to create output file '$OUTPUT_FILE'"
    exit 1
fi