#!/bin/bash

#SBATCH --job-name downloadLogan-HumanGen
#SBATCH --output downloadLogan-HumanGen.log
#SBATCH --error downloadLogan-HumanGen-err.log
#SBATCH --mail-user ludovico.orsolon@studenti.unipd.it
#SBATCH --mail-type ALL
#SBATCH --time 3-00:00:00
#SBATCH --cpus-per-task 8
#SBATCH --partition allgroups
#SBATCH --mem 200G

singularity exec -B /nfsd:/nfsd /nfsd/bcb/bcbg/Orsolon/datasetsOrsolon/LoganUnitigs/utility.sif bash 2_download_and_extract_unitigs_from_logan.sh 1000_humanGen.txt ./unitigs