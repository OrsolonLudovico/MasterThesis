# How did I compare the results?
Running the `.slurm` [file](./run_analysis.slurm) launches [runAllQueries.sh](./runAllQueries.sh), which runs [askQueryBoth.sh](./askQueryBoth.sh) on each file of a given folder; *askQueryBoth.sh* queries both indexes and saves the results.

Running *run_analysis.slurm* also launches [compare_results.py](./compare_results.py), which looks at the results provided by *askQueryBoth.sh* and outputs a comparison with some metrics.
