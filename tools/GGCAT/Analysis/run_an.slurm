#!/bin/bash

#SBATCH --job-name Orsolon-GGCAT_GutAnal
#SBATCH --output GGCAT_GutAnal.log
#SBATCH --error GGCAT_GutAnal-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 16
#SBATCH --partition allgroups
#SBATCH --mem 100G

#I use the image used for mash since it contains python libraries
srun singularity exec --bind /nfsd:/nfsd "/nfsd/bcb/bcbg/Orsolon/Mash/mash_analysis.sif" python3 run_full_analysis.py ../HumanGutUnc_GGCAT_output/ ../HumanGutCompressed_GGCAT_output/