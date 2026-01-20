# Exploring how k-mer based compression speeds up many bioinformatics applications

This is the repository where I'll store and explain my work towards the master thesis which can be found [here].

## What's this thesis about?

Briefly: I used a tool called [USTAR](https://github.com/enricorox/USTAR) to compress genome datasets and evaluated how well this compression works in tandem with various tools.

### How?

Using Singularity and a computing cluster. For more information, look into the dedicated section: [Singularity](./Singularity).

## Which tool did I use?

USTAR: GitHub page [here](https://github.com/enricorox/USTAR)  
[Fulgor](./tools/Fulgor): GitHub page [here](https://github.com/jermp/fulgor)  
[GGCAT](./tools/GGCAT): GitHub page [here](https://github.com/algbio/ggcat)  
[Kmdiff](./tools/Kmdiff): GitHub page [here](https://github.com/tlemane/kmdiff)   
[Mash](./tools/Mash): GitHub page [here](https://github.com/marbl/Mash)  
[REINDEER2](./tools/REINDEER2): GitHub page [here](https://github.com/Yohan-HernandezCourbevoie/REINDEER2)  
    
A summary of all the tools' results is reported in spreadsheet foramt inside the [tools](/tools/Tools_results_statistics.xlsx) folder.

## Datasets

You can find info about the datasets in the [datasets](./datasets) section.

## Modify USTAR

I also modified USTAR to make it do things it wasn't capable of doing before, all the details are into [this folder](./ModifyUSTAR) (I suggest reading the [Singularity](./Singularity/) section beforehand)
