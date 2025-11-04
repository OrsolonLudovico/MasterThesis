#!/bin/bash
#This script creates a list compatible with kmdiff, it has the folowing structure:
# (paths are absolute)
# control1: /path/to/control1
# control2: /path/to/control2
# ....
# case1: /path/to/case1
# case2: /path/to/case2
# ....
#### The script takes two subsets of the specified number of elements (not intersecating) from the input folder
#### They will be case and control groups onto wich to apply kmdiff later

### Usage: make_groups.sh <input_folder> <group_size> <output_file>
###########################################################################

set -euo pipefail

if [ $# -lt 3 ]; then
    echo "Usage: $0 <input_folder> <group_size> <output_file>"
    exit 1
fi

INPUT_FOLDER="$1"
GROUP_SIZE="$2"
OUTPUT_FILE="$3"
SEED=123            ######## Fix the seed for reproducibility

# Collect fasta files (both .fasta and .fa)
FILES=($(find "$INPUT_FOLDER" -maxdepth 1 -type f \( -name "*.fasta" -o -name "*.fa" \)))

TOTAL=${#FILES[@]}
NEEDED=$((GROUP_SIZE * 2))

if [ "$TOTAL" -lt "$NEEDED" ]; then
    echo "Error: not enough fasta files in $INPUT_FOLDER. Need at least $NEEDED, found $TOTAL."
    exit 1
fi

# Generate a reproducible random source from seed
RAND_SRC=$(mktemp)
# Temporarily disable pipefail for this command to avoid SIGPIPE error
set +o pipefail
yes "$SEED" | head -c 1048576 > "$RAND_SRC"
set -o pipefail

# Shuffle files reproducibly
SHUFFLED=($(printf "%s\n" "${FILES[@]}" | shuf --random-source="$RAND_SRC"))
rm -f "$RAND_SRC"

# Split into controls and cases
CONTROLS=("${SHUFFLED[@]:0:GROUP_SIZE}")
CASES=("${SHUFFLED[@]:GROUP_SIZE:GROUP_SIZE}")

# Write output
: > "$OUTPUT_FILE"
i=1
for f in "${CONTROLS[@]}"; do
    echo "control${i}: $(realpath "$f")" >> "$OUTPUT_FILE"
    ((i++))
done

i=1
for f in "${CASES[@]}"; do
    echo "case${i}: $(realpath "$f")" >> "$OUTPUT_FILE"
    ((i++))
done

echo "Groups written to $OUTPUT_FILE"
