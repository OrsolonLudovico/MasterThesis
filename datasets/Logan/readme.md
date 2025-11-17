# Logan

## Download
Here we have the pipeline to download `.unitig` files from Logan (The example is on how to download Human Genome files):   
First you select what specie to dowaload from and how many samples to download using the [select ascessions](./select_accessions.sh) script, this will provide a  `.txt` file which will be the input for the next scripts.  
You then use the [dowload script](./2_download_and_extract_unitigs_from_logan.sh) by launching the `.txt` [file](./launch_download.slurm), you'll get a unitigs folder.  
Now you can compress that folder with USTAR without using BCALM2; example in the [compress](./compress_Hgen_Unitigs.slurm) script.

Note: You have to use a modified version of USTAR to read the format provided by Logan. For more info regarding the USTAR's mods look into the [dedicated folder](/ModifyUSTAR/).

## Check correctness
You can look into the [Download both](./Download_both_from_sra_and_Logan/) folder to see how to dowload the same file from Logan and sra simultaniously.
