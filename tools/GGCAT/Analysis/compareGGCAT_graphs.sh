#!/bin/bash
####################################################################
# Script to compare GGCAT results from two different datasets
####################################################################

# Check if two arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <dataset1_GGCAT_folder> <dataset2_GGCAT_folder>"
    echo "Example: $0 ./testDataset_GGCAT ./Test2_GGCAT"
    exit 1
fi

dataset1="$1"
dataset2="$2"

# Check if directories exist
if [ ! -d "$dataset1" ]; then
    echo "Error: Directory $dataset1 does not exist"
    exit 1
fi

if [ ! -d "$dataset2" ]; then
    echo "Error: Directory $dataset2 does not exist"
    exit 1
fi

# Output file
outputFile="./comparison_results.txt"

echo "========================================" > "$outputFile"
echo "GGCAT Results Comparison" >> "$outputFile"
echo "========================================" >> "$outputFile"
echo "Dataset 1: $dataset1" >> "$outputFile"
echo "Dataset 2: $dataset2" >> "$outputFile"
echo "Date: $(date)" >> "$outputFile"
echo "" >> "$outputFile"

# Function to extract stats from GGCAT output
extract_stats() {
    local folder=$1
    local label=$2
    
    echo "----------------------------------------" >> "$outputFile"
    echo "$label" >> "$outputFile"
    echo "----------------------------------------" >> "$outputFile"
    
    # File sizes
    echo "File Sizes:" >> "$outputFile"
    if [ -f "$folder/resGGCAT.txt" ]; then
        size=$(du -h "$folder/resGGCAT.txt" | cut -f1)
        echo "  Graph file (resGGCAT.txt): $size" >> "$outputFile"
    fi
    
    if [ -f "$folder/resGGCAT.colors.dat" ]; then
        size=$(du -h "$folder/resGGCAT.colors.dat" | cut -f1)
        echo "  Colors file: $size" >> "$outputFile"
    fi
    
    # Number of sequences (unitigs) in the graph
    if [ -f "$folder/resGGCAT.txt" ]; then
        num_sequences=$(grep -c "^>" "$folder/resGGCAT.txt")
        echo "  Number of unitigs: $num_sequences" >> "$outputFile"
        
        # Total length of sequences
        total_length=$(grep -v "^>" "$folder/resGGCAT.txt" | tr -d '\n' | wc -c)
        echo "  Total sequence length: $total_length bp" >> "$outputFile"
        
        # Average unitig length
        if [ "$num_sequences" -gt 0 ]; then
            avg_length=$((total_length / num_sequences))
            echo "  Average unitig length: $avg_length bp" >> "$outputFile"
        fi
        
        # Longest unitig
        longest=$(grep -v "^>" "$folder/resGGCAT.txt" | awk '{print length}' | sort -rn | head -1)
        echo "  Longest unitig: $longest bp" >> "$outputFile"
    fi
    
    # Extract info from stats log
    if [ -f "$folder/resGGCAT.stats.log" ]; then
        # Look for "Total color subsets" in the terminal output or parse from log
        # Since the log is JSON, we'll need to extract relevant info
        echo "" >> "$outputFile"
        echo "Execution Statistics:" >> "$outputFile"
        
        # Try to find total time (this would be in the terminal output)
        # For now, just note the stats file exists
        echo "  Stats file available: Yes" >> "$outputFile"
    fi
    
    # Number of input files
    if [ -f "$folder/inGGCAT.txt" ]; then
        num_inputs=$(wc -l < "$folder/inGGCAT.txt")
        echo "  Number of input files: $num_inputs" >> "$outputFile"
    fi
    
    echo "" >> "$outputFile"
}

# Extract stats for both datasets
extract_stats "$dataset1" "DATASET 1"
extract_stats "$dataset2" "DATASET 2"

# Comparison summary
echo "========================================" >> "$outputFile"
echo "COMPARISON SUMMARY" >> "$outputFile"
echo "========================================" >> "$outputFile"

# Compare file sizes
if [ -f "$dataset1/resGGCAT.txt" ] && [ -f "$dataset2/resGGCAT.txt" ]; then
    size1=$(stat -c%s "$dataset1/resGGCAT.txt")
    size2=$(stat -c%s "$dataset2/resGGCAT.txt")
    
    echo "Graph file size comparison:" >> "$outputFile"
    echo "  Dataset 1: $size1 bytes" >> "$outputFile"
    echo "  Dataset 2: $size2 bytes" >> "$outputFile"
    
    if [ "$size1" -gt "$size2" ]; then
        diff=$((size1 - size2))
        percent=$(echo "scale=2; ($diff * 100) / $size1" | bc)
        echo "  Dataset 1 is larger by: $diff bytes ($percent%)" >> "$outputFile"
    elif [ "$size2" -gt "$size1" ]; then
        diff=$((size2 - size1))
        percent=$(echo "scale=2; ($diff * 100) / $size2" | bc)
        echo "  Dataset 2 is larger by: $diff bytes ($percent%)" >> "$outputFile"
    else
        echo "  Both datasets produce identical graph sizes" >> "$outputFile"
    fi
    echo "" >> "$outputFile"
fi

# Compare number of unitigs
num1=$(grep -c "^>" "$dataset1/resGGCAT.txt" 2>/dev/null || echo "0")
num2=$(grep -c "^>" "$dataset2/resGGCAT.txt" 2>/dev/null || echo "0")

echo "Number of unitigs comparison:" >> "$outputFile"
echo "  Dataset 1: $num1 unitigs" >> "$outputFile"
echo "  Dataset 2: $num2 unitigs" >> "$outputFile"

if [ "$num1" -ne "$num2" ]; then
    diff=$((num1 - num2))
    echo "  Difference: $diff unitigs" >> "$outputFile"
else
    echo "  Both datasets produce the same number of unitigs" >> "$outputFile"
fi

echo "" >> "$outputFile"
echo "========================================" >> "$outputFile"
echo "Full comparison report saved to: $outputFile" >> "$outputFile"
echo "========================================" >> "$outputFile"

# Display the report
cat "$outputFile"

echo ""
echo "Report saved to: $outputFile"
