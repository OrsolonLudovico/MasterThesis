# How did I compare the results?
Running the `.slurm` [file](./RunQuery.slurm) launches [run_batch_analysis.sh](./run_batch_analysis.sh); this will also start [run_analysis.sh](./run_analysis.sh) and [queryBoth.sh](./queryBoth.sh).  
This process takes a folder containing queries and uses each one to query both indexes, saving the responses. Those will later be compared by [analisi_differenze.py](./analisi_differenze.py) using various metrics.
