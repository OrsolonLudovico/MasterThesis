# Build the singularity image

Download and install singularity using this [guide](https://docs.sylabs.io/guides/3.4/user-guide/)

Now, in the folder in which you have your def file:

```bash
sudo singularity build outputFile.sif Container.def
```

This will result in the build of a singularity container called **outputFile.sif**, as defined in **Container.def**.

## Testing:

```bash
singularity shell outputFile.sif
```

To enter the shell of the container.  
From here you can launch commands as in a normal Linux installation.  
You can test USTAR, for example, from inside the shell:

```bash
/USTAR/build/ustar -h
```

or from outside the shell, using the exec command:

```bash
singularity exec outputFile.sif /USTAR/build/ustar -h
```

**Notes:**
- It’s a good idea to bind your working directory when you execute the file, for example:  
  ```bash
  singularity exec -B /:/ outputFile.sif /USTAR/build/ustar -h
  ```
  binds the `/` folder on your machine to the `/` folder on the image.
- I did not put the programs in *PATH* to be more deliberate when I call a program, so you have to specify the whole global path (or add them to *PATH* in the def file).

# Modify USTAR

I also used a different version of the `.def` file — look into [this folder](./ModifyUSTAR)
