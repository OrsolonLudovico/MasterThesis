#!/bin/bash

#SBATCH --job-name REINDEER2-GutReads-Query
#SBATCH --output REINDEER2-GutReads-Query.log
#SBATCH --error REINDEER2-GutReads-Query-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 1-00:00:00
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 16
#SBATCH --partition allgroups
#SBATCH --mem 300G

srun bash runAllQueries.sh "./Queries" "/nfsd/bcb/bcbg/Orsolon/REINDEER2/READS/HumanGutReads/indexComp/" "/nfsd/bcb/bcbg/Orsolon/REINDEER2/READS/HumanGutReads/indexUnc/"