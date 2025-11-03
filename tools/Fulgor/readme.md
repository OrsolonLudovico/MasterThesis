# How did I use Fulgor?
I built two indexes, one for the compressed version of each dataset and one for the uncompressed one. Each run produces a folder that represents the index as output. I then compared the two indexes by querying them and analyzed the differences in the [Analysis](./Analysis) section.

# Example on how to run Fulgor
The `.slurm` file I used to build the index is reported [here](./IndexComp.slurm). In this example, I create an index using the compressed version of the *Human Gut Reads* dataset.  

There is also [prepInput.sh](./prepInput.sh), which simply takes as input a folder and outputs a file containing the paths to the files in that folder (this is needed as input for *Fulgor*).
