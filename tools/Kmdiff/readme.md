# How did I use kmdiff?
I ran kmdiff on the compressed and uncompressed versions of the datasets, obtaining a file with the most expressed k-mers.  
The script [kmdiff_all_comp.slurm](./kmdiff_all_comp.slurm) is an example that runs kmdiff on the compressed version of the *Human Gut Reads* dataset.  
[createInput.sh](./createInput.sh) is needed to create a file containing the list of the paths of the genomes we want to analyze (kmdiff requires this input format).

# Results
Unfortunately, from my experiments, we found that compressing the datasets makes *kmdiff* unable to discover any differentially expressed k-mers.
