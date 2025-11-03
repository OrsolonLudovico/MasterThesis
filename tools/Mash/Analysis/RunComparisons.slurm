#!/bin/bash

#SBATCH --job-name runcomp
#SBATCH --output runcomp.log
#SBATCH --error euncomp-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 4
#SBATCH --partition allgroups
#SBATCH --mem 20G

srun singularity exec -B /nfsd:/nfsd "/nfsd/bcb/bcbg/Orsolon/Mash/mash_analysis.sif" python3 ./compare_tables.py ./HumanGutUnc_table.txt ./HumanGutCompressed_table.txt