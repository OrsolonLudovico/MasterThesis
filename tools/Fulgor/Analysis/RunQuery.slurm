#!/bin/bash

#SBATCH --job-name Fulgor_RunQuery_GutReads
#SBATCH --output Fulgor_RunQuery_GutReads.log
#SBATCH --error Fulgor_RunQuery_GutReads-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 16
#SBATCH --partition allgroups
#SBATCH --mem 1000G

srun bash "./run_batch_analysis.sh" "./Queries"