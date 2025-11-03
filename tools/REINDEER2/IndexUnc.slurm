#!/bin/bash

#SBATCH --job-name REINDEER2GutReads_IND_unc
#SBATCH --output REINDEER2GutReads_IND_unc.log
#SBATCH --error REINDEER2GutReads_IND_unc-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 16
#SBATCH --partition allgroups
#SBATCH --mem 200G

####################################################################################################################
inputFolder="/nfsd/bcb/bcbg/Orsolon/datasetsOrsolon/Reads/HumanGut/HumanGutUnc/"
k=31
imagePath="/nfsd/bcb/bcbg/Orsolon/image.sif"
cores=16
outGGCAT="./resGGCATUnc.txt"
outREINDEER2="./indexUnc"
#################################################################
find "$inputFolder" -type f -exec realpath {} \; > inGGCAT.txt

#Let's try to use GGCAT
echo "### STARTING GGCAT ###"
touch "$outGGCAT"
srun singularity exec  -B /nfsd:/nfsd $imagePath /ggcat build -k $k -j $cores -l inGGCAT.txt -o "$outGGCAT" -c -e 

echo "### FIXING HEADERS ###"
# Create a temporary file
temp_file="${outGGCAT}.tmp"
# Convert headers to REINDEER2 format
srun awk '
{
    if ($0 ~ /^>/) {
        match($0, /C:[a-z0-9]+:([0-9]+)/, arr)
        if (arr[1] != "") {
            printf ">%d km:f:%s\n", NR/2, arr[1]
        } else {
            printf ">%d km:f:1\n", NR/2
        }
    } else {
        print $0
    }
}' "$outGGCAT" > "$temp_file"
# Replace original file with fixed headers
mv "$temp_file" "$outGGCAT"
echo "### HEADERS FIXED ###"

#Now go with REINDEER2
rm -rf ./"$outREINDEER2"
mkdir ./"$outREINDEER2"
echo "### STARTING REINDEER2 ###"
find "$outGGCAT" -type f -exec realpath {} \; > inputREIN2.txt
srun singularity exec  -B /nfsd:/nfsd $imagePath /REINDEER2/target/release/Reindeer2 --mode index --input "inputREIN2.txt" --kmer $k -o $outREINDEER2 -t $cores
echo "### REINDEER2 ENDED ###"

rm -f "./*.colors.dat"
rm -f "./*.stats.log"
#rm -f "inputREIN2.txt"
#rm -f "inGGCAT.txt"
#rm -f "$outGGCAT"
