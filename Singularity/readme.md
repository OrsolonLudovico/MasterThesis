# Why singularity?

I maily used the [DEI cluster](https://www.dei.unipd.it/en/node/2284) in Padova to make all my computations. In that cluster users are not allowed to install programs; this means that a singularity image containing all the programs and files each user needs is the only way to use custom programs on the cluster.

# Build the singularity image

Download and install singularity using this [guide](https://docs.sylabs.io/guides/3.4/user-guide/). Now, in the folder in which you have your def file:

```bash
sudo singularity build outputFile.sif Container.def
```

This will result in the build of a singularity container called **outputFile.sif**, as defined in **Container.def**.

## Testing:

To enter the shell of the container.
```bash
singularity shell outputFile.sif
```  
From here you can launch commands as in a normal Linux installation. From inside this shell you can test USTAR for example:

```bash
/USTAR/build/ustar -h
```

you can also do that from outside the shell, using the exec command:

```bash
singularity exec outputFile.sif /USTAR/build/ustar -h
```

**Notes:**
- It’s a good idea to bind your working directory when you execute the file, for example:  
  ```bash
  singularity exec -B /:/ outputFile.sif /USTAR/build/ustar -h
  ```
  binds the `/` folder on your machine to the `/` folder on the image.
- I did not put the programs in *PATH* to be more deliberate when I use commands, so you have to specify the whole global path (or add it to *PATH* in the def file).

# Modify USTAR

I also used a different version of the `.def` file — look into [this folder](./ModifyUSTAR)
