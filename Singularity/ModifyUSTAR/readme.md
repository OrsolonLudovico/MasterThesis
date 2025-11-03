# Modifyng USTAR

USTAR takes as input a single file and, especially when you're using Slurm, executing it for thousands of files can be slow.  
With this `.def` file, I swap the `ustar.cpp` file in the cloned repository with an ad hoc one, present in this directory — [ustar.cpp](./ustar.cpp).  
This modification allows USTAR to be called just one time and run on a batch of files.

The approach is not satisfying though, because the biggest contributor to the slowdown is **BCALM2**.  
Without modifying it to accept a batch of files as well, using the modified version of USTAR or the normal one doesn’t provide any real difference.  
For this reason, I used the original version for each of my Slurm jobs.
