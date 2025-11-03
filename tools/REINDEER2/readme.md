# How did I use REINDEER2?
I build two indexes, one for the compressed version of each dataset and one for the uncompressed one, each run gives a folder which is the index as output. I then compared the two indexes by queryng them and analized the difference in the [Analysis](./Analysis) section.

# Exampe on how to run REINDEER2
The `.slurm` file I used to build the index is reported [here](./IndexUnc.slurm), in this example i create an index using the compressed version of the *Human Gut Reads* dataset.
