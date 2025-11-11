# File Format Detection and Parsing - Detailed Explanation

## Overview
The modified `DBG.cpp` now supports two different unitigs file formats:
1. **Standard BCALM2 format** - Original format with detailed k-mer abundances
2. **Alternative format (Cutterfish2)** - Simplified format with average k-mer abundance

## Format Detection Mechanism

### Auto-detection Logic (DBG.cpp, lines 75-84)

```cpp
// AUTO-DETECT format type by searching for distinctive tags
bool is_standard_format = (line.find("LN:i:") != string::npos && 
                          line.find("ab:Z:") != string::npos);
bool is_alternative_format = (line.find("ka:f:") != string::npos);
```

**How it works:**
- The parser examines each header line for **distinctive tags**
- If both `LN:i:` (length) AND `ab:Z:` (abundance array) are found → **Standard BCALM2**
- If `ka:f:` (k-mer average float) is found → **Alternative format**
- Only ONE format can be detected per file (validated at line 83)

---

## Format 1: Standard BCALM2

### Example Header:
```
>25 LN:i:32 ab:Z:14 12 17 15   L:-:23:+ L:-:104831:+  L:+:22:-
ACGTACGTACGTACGTACGTACGTACGTACGT
```

### Structure:
- **ID**: Simple integer (`25`)
- **Length field**: `LN:i:32` - unitig length in nucleotides
- **Abundance field**: `ab:Z:14 12 17 15` - space-separated integers
  - Each integer = abundance of one k-mer in the unitig
  - Number of values = (sequence_length - k + 1)
- **Arcs**: `L:SIGN:ID:SIGN` format (same in both formats)

### Parsing Process:
1. Extract ID and length using `sscanf` with format string
2. Parse each abundance value individually
3. Calculate `average_abundance` = sum / count
4. Calculate `median_abundance` using median() function
5. Each k-mer gets its own abundance value in `node.abundances[]`

---

## Format 2: Alternative (Cutterfish2)

### Example Header:
```
>SRR11905265_0 ka:f:1.0    L:-:27885434:-
AAAAAAAAAAAAAAAAAAAAAACAGCCTCAG
```

### Structure:
- **ID**: `PREFIX_NUMBER` format (e.g., `SRR11905265_0`)
  - Prefix can be any string (dataset name)
  - Number after underscore = serial ID
- **No length field** - computed from sequence
- **Abundance field**: `ka:f:1.0` - single float value
  - `ka:f:` = "k-mer average, float"
  - One value representing average across ALL k-mers
  - Uses floating-point for precision (e.g., 1.0, 4.8, 13.5)
- **Arcs**: Same `L:SIGN:ID:SIGN` format

### Parsing Process:
1. Find underscore in ID, extract number after it
2. Parse `ka:f:X.X` to get average abundance as double
3. Store in `node.average_abundance` directly
4. Use same value for `node.median_abundance`
5. **IMPORTANT**: Individual k-mer abundances created AFTER reading sequence:
   - Calculate n_kmers = sequence_length - k + 1
   - Fill `node.abundances[]` with replicated average value
   - This maintains compatibility with rest of codebase


## Why This Works for `-s+aa` and `-x-c`

### Flag `-s+aa` (Seed by Higher Average Abundance)
- **Standard format**: Average calculated from individual k-mer abundances
- **Alternative format**: Average directly provided in file
- **Both**: Result stored in `node.average_abundance` (type: `double`)
- **Sorting works identically** - both use the same field

### Flag `-x-c` (Extend by Less Connected)
- Counts number of outgoing arcs from a node
- Uses `node.arcs.size()` - same in both formats
- Arc parsing (`L:` tags) is **identical** in both formats
- **Works without modification**

### Why Other Flags May Not Work:
- Flags using individual k-mer abundances (e.g., `-x=a` comparing edge abundances)
- Alternative format replicates same value for all k-mers
- Loses per-position granularity
- May produce suboptimal but valid results

### Testing
Both formats can be tested with the files provided in the [test](./Test) folder.

The parser auto-detects and handles each correctly.
