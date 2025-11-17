# Logan Data Download Pipeline

Pipeline for downloading sequencing data from SRA and corresponding unitigs from the Logan database.

## Overview

This pipeline allows you to download genomic data from two sources:
- **SRA (Sequence Read Archive)**: raw reads in FASTA format
- **Logan Database**: pre-processed unitigs from the Logan project

Downloaded files are perfectly paired: for each accession successfully downloaded from SRA, the corresponding unitigs file is also downloaded from Logan.

## Input Files

### Accession Lists

Accession lists can be downloaded from Logan, look ath the guide: https://github.com/IndexThePlanet/Logan/blob/main/SRA_list.md

### CSV Format
```csv
"SRR16301321","RNA-Seq","Homo sapiens","9606","species","Homo sapiens"
"SRR16777296","miRNA-Seq","Homo sapiens","9606","species","Homo sapiens"
```
Scripts automatically extract accession ID.

## Scripts

### 1. `1_download_unitigs_from_logan.sh`

**Description**: Downloads unitigs from Logan without automatic extraction.

**Usage**:
```bash
./1_download_unitigs_from_logan.sh <accessions_file.txt> [output_dir]
```

**Input**:
- File with list of accessions
- Output directory (optional, default: current directory)

**Output**:
- Compressed `.unitigs.fa.zst` files in the specified directory

**Example**:
```bash
./1_download_unitigs_from_logan.sh list_accessions_human.txt ./unitigs
```

---

### 2. `2_download_and_extract_unitigs_from_logan.sh`

**Description**: Downloads unitigs from Logan and automatically extracts compressed files.

**Usage**:
```bash
./2_download_and_extract_unitigs_from_logan.sh <accessions_file.txt> [output_dir]
```

**Input**:
- File with list of accessions
- Output directory (optional, default: current directory)

**Output**:
- Extracted `.unitigs.fa` files in the specified directory
- Compressed `.zst` files are automatically removed after extraction

**Example**:
```bash
./2_download_and_extract_unitigs_from_logan.sh list_accessions_human.txt ./logan_unitigs
```

**Note**: Requires `zstd` installed for extraction.

---

### 3. `3_download_reads_from_sra.sh`

**Description**: Downloads raw reads from SRA in FASTQ format.

**Usage**:
```bash
./3_download_reads_from_sra.sh <accessions_file.txt> [output_dir]
```

**Input**:
- File with list of accessions
- Output directory (optional, default: current directory)

**Output**:
- `.fastq` files in the specified directory

**Example**:
```bash
./3_download_reads_from_sra.sh list_accessions_human.txt ./sra_reads
```

**Note**: Requires SRA Toolkit installed (`fasterq-dump`).

---

### 4. `4_download_paired_sra_logan.sh` (MAIN SCRIPT)

**Description**: Intelligent script that downloads a specified number of files from SRA (in FASTA format) and corresponding unitigs from Logan. Automatically handles failures and retries with new accessions until the target number is reached. **Only selects accessions that are available in Logan** by cross-referencing with the Logan CSV.

**Usage**:
```bash
./4_download_paired_sra_logan.sh <num_files> <accessions_list.txt> [sra_output_dir] [logan_output_dir]
```

**Input**:
- `num_files`: Number of files to download
- `accessions_list.txt`: File with list of accessions (can contain any SRA accessions)
- `sra_output_dir`: SRA output directory (optional, default: `./sra_reads`)
- `logan_output_dir`: Logan output directory (optional, default: `./logan_unitigs`)

**Requirements**:
- `logan_accessions_v1.1_SRA2023.csv` must be present in the same directory (extract with `zstdcat logan_accessions_v1.1_SRA2023.csv.zst > logan_accessions_v1.1_SRA2023.csv`)

**Output**:
- `.fasta` files from SRA in `sra_output_dir`
- `.unitigs.fa` files from Logan in `logan_output_dir`
- `successful_accessions.txt`: List of successfully downloaded accessions

**Example**:
```bash
# Download 10 files with default directories
./4_download_paired_sra_logan.sh 10 list_accessions_human.txt

# Download 20 files specifying directories
./4_download_paired_sra_logan.sh 20 list_accessions_human.txt ./my_sra ./my_logan

# Download 5 files from human gut metagenome dataset
./4_download_paired_sra_logan.sh 5 list_accessions_human_gut_metagenome.txt
```

**Workflow**:
1. **Loads Logan CSV**: Extracts all accessions available in Logan for fast lookup
2. Selects N random accessions from the input list **that are also in Logan CSV**
3. Attempts to download them from SRA in FASTQ format (with progress bar using `fasterq-dump`)
4. **Converts FASTQ → FASTA**: For each successfully downloaded FASTQ file:
   - Uses `awk` to extract sequence headers and sequences
   - Converts FASTQ 4-line format to FASTA 2-line format
   - Removes quality scores (not needed for most analyses)
   - Deletes the original FASTQ file to save disk space
5. Verifies which files were successfully downloaded and converted
6. If files are missing, adds new random accessions (also filtered by Logan CSV) and retries (ITERATION 2, 3, ...)
7. Once N files are reached, downloads from Logan ONLY successful ones
8. Automatically extracts `.zst` files from Logan

**Important**: This script filters accessions to ensure they exist in Logan before attempting download. This prevents 404 errors when downloading from Logan. The input accessions file can be from any source (e.g., `sra_taxid.csv.zst`), but only accessions present in `logan_accessions_v1.1_SRA2023.csv` will be selected.

**FASTQ to FASTA Conversion Details**:

The script automatically converts downloaded FASTQ files to FASTA format using the following `awk` command:
```bash
awk 'NR%4==1 {print ">" substr($0, 2)} NR%4==2 {print}' file.fastq > file.fasta
```
After conversion, the original FASTQ file is automatically deleted.

**Requirements**:
- SRA Toolkit (`fasterq-dump`)
- AWS CLI (for Logan S3 download)
- `zstd` (for unitigs extraction)
- `awk` (for FASTQ → FASTA conversion)

---

### 5. `utility_extract_zst_and_cleanup.sh`

**Description**: Utility to extract `.zst` files and cleanup compressed files.

**Usage**:
```bash
./utility_extract_zst_and_cleanup.sh [directory]
```

**Input**:
- Directory containing `.zst` files (optional, default: current directory)

**Output**:
- Extracted files in the same directory
- Original `.zst` files are removed


## Notes

1. **Logan CSV Required**: Script 4 requires `logan_accessions_v1.1_SRA2023.csv` to be extracted in the same directory. Extract it once with:
   ```bash
   zstdcat logan_accessions_v1.1_SRA2023.csv.zst > logan_accessions_v1.1_SRA2023.csv
   ```

2. **SRA vs Logan Accessions**: Not all SRA accessions are available in Logan. Files like `list_accessions_human.txt` (from `sra_taxid.csv.zst`) contain ALL human SRA accessions, but only a subset has been processed by Logan. Script 4 automatically filters to use only available accessions.

3. **Download speed from SRA can be slow**: Times depend on file size and connection speed

4. **Disk space**: Ensure sufficient space (files can be very large)

5. **Automatic retry**: Script 4 automatically handles failures, making it the most robust solution

6. **FASTA vs FASTQ**: Scripts download in FASTA format (without quality scores) to save space

7. **Paired-end**: Paired-end files are automatically concatenated into a single file
