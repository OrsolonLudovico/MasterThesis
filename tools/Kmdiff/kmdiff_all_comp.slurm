#!/bin/bash
#SBATCH --job-name Orsolon-kmdiff_all_HGutReadsCOMP
#SBATCH --output kmdiff_all_HGutReadsCOMP.log
#SBATCH --error kmdiff_all_HGutReadsCOMP-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 16
#SBATCH --partition allgroups
#SBATCH --mem 1000G


#This script will execute kmdiff on the two groups specified in the input file
inputFile="comp_list.txt"
outputDir="Comp_temp"
finalOutputDir="Comp_Final"
# Count controls and cases from input file, check the first word, if there is any amount of numners and then there is :
Ncontrols=$(grep -c "^control[0-9]*:" "$inputFile")
Ncases=$(grep -c "^case[0-9]*:" "$inputFile")
threads=16

########Parameters you should rarely change#############
hmin=1 #Hard minimum for kmer counts
k=31
sig_value=0.01
###################################################
rm -rf "$outputDir"
rm -rf "$finalOutputDir"

#count command
srun singularity exec -B /nfsd:/nfsd "/nfsd/bcb/bcbg/Orsolon/image.sif" /kmdiff/kmdiff_build/bin/kmdiff count --file "$inputFile" --run-dir "$outputDir" --kmer-size $k --hard-min $hmin --threads $threads
#diff command
# -1 is number of controls
# -2 is number of cases
srun singularity exec -B /nfsd:/nfsd "/nfsd/bcb/bcbg/Orsolon/image.sif" /kmdiff/kmdiff_build/bin/kmdiff diff --km-run "$outputDir" -1 $Ncontrols -2 $Ncases --output-dir "$finalOutputDir" -s $sig_value --threads $threads
