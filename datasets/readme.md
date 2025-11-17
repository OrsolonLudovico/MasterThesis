# About the datasets
I used two types of datasets: datasets containing assemblied genomes and datasets containing reads. 
Using USTAR on the assemblies provided only a small compression due to the fact that the process of assembling a genome removes most of the redundancies. On the other hand compressing a dataset of reads yelded much better results due to the inherit repetitiveness of the reads.   
Look in the sub-folders to get more information about the specific datasets I used.

Using reads means that we have to rely on BCALM2 to produce unitigs, which is slow. We could download directly the unitigs from the [Logan](https://github.com/IndexThePlanet/Logan/tree/main) project. In the [Logan folder](./Logan) there are some scripts that dowloads unitigs and corresponding reads.

The datasets downloaded using Logan are in the [unitigs](./Unitigs/) folder.
