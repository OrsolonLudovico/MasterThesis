#!/bin/bash

#SBATCH --job-name Orsolon-Fulgor_GutReadsComp
#SBATCH --output Fulgor_GutReadsComp.log
#SBATCH --error Fulgor_GutReadsComp-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 16
#SBATCH --partition allgroups
#SBATCH --mem 1000G

input="GutReadsComp_list.txt"
outDir="IndexGutComp" #Do not write .fur
k=31
maxRAM=990
nThreads=16

#########
minimizerSize=19
tmpDir="./temporary_dir_delete_me_Comp"

#Delete previous index
rm -rf "${outDir}.fur"

srun singularity exec -B /nfsd:/nfsd "/nfsd/bcb/bcbg/Orsolon/image.sif" /fulgor/build/fulgor build -l "$input" \
-o "$outDir" -k "$k" -m "$minimizerSize" -d "$tmp_dir" -g "$maxRAM" -t "$nThreads" --verbose
