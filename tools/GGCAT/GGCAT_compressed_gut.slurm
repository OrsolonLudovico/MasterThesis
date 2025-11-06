#!/bin/bash

#SBATCH --job-name Orsolon-GGCAT_GutReadsComp
#SBATCH --output GGCAT_GutReadsComp.log
#SBATCH --error GGCAT_GutReadsComp-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 16
#SBATCH --partition allgroups
#SBATCH --mem 1000G
####################################################################
inputFolder="/nfsd/bcb/bcbg/Orsolon/datasetsOrsolon/Reads/HumanGut/HumanGutCompressed/"
k=31
imagePath="/nfsd/bcb/bcbg/Orsolon/image.sif"
cores=8
outGGCAT="./resGGCAT.txt"
#################################################################
# Find only FASTA files (extensions: .fasta, .fa, .fna, .faa)
find "$inputFolder" -type f \( -name "*.fasta" -o -name "*.fa" -o -name "*.fna" -o -name "*.faa" \) ! -name "*Zone.Identifier" -exec realpath {} \; > inGGCAT.txt

touch "$outGGCAT"
srun singularity exec --bind /nfsd:/nfsd $imagePath /ggcat build -k $k -j $cores -l inGGCAT.txt -o "$outGGCAT" -c -e

# Create output folder with name based on input folder
folderName=$(basename "$inputFolder")
outputDir="./${folderName}_GGCAT_output"
mkdir -p "$outputDir"

# Move all GGCAT output files to the folder
mv inGGCAT.txt "$outputDir/"
mv "$outGGCAT" "$outputDir/"
mv resGGCAT.colors.dat "$outputDir/"
mv resGGCAT.stats.log "$outputDir/"
echo "Files moved to: $outputDir" 