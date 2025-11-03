#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
USAGE: Give two files as input. These two files are the result of a fulgor query, this script will analyze 
their differences and produce a report.
"""

import sys
import os

def read_numbers_from_file(file_name):
    """Read numbers from a file and return a set"""
    try:
        with open(file_name, 'r') as f:
            content = f.read().strip()
    except FileNotFoundError:
        print(f"Error: File '{file_name}' not found.")
        sys.exit(1)
    
    # Split by tab and take all elements except the first (which is the identifier)
    elements = content.split('\t')
    numbers = set()
    
    for i, element in enumerate(elements):
        if i == 0:  # Skip the first element (query identifier)
            continue
        try:
            number = int(element)
            numbers.add(number)
        except ValueError:
            # If it's not a number, skip it
            continue
    
    return numbers

def main():
    if len(sys.argv) != 3:
        print("Usage: python analisi_differenze.py <original_query_result> <compressed_query_result>")
        print("  original_query_result: Result from query on original index (correct)")
        print("  compressed_query_result: Result from query on compressed index")
        sys.exit(1)
    
    original_file = sys.argv[1]
    compressed_file = sys.argv[2]
    
    # Extract query name from the first file for output filename
    query_name = os.path.splitext(os.path.basename(original_file))[0]
    
    # Get the directory of the original (uncompressed) index file
    original_dir = os.path.dirname(original_file)
    output_file = os.path.join(original_dir, f"{query_name}_comparisons.txt")
    
    # Read numbers from both files
    print("Reading files...")
    original_results = read_numbers_from_file(original_file)
    compressed_results = read_numbers_from_file(compressed_file)
    
    print(f"Numbers found in original index result: {len(original_results)}")
    print(f"Numbers found in compressed index result: {len(compressed_results)}")
    
    # Basic comparison
    total_original = len(original_results)
    total_compressed = len(compressed_results)
    
    # Calculate set differences and intersections
    only_in_original = original_results - compressed_results  # In original but not in compressed
    only_in_compressed = compressed_results - original_results  # In compressed but not in original
    in_both = original_results & compressed_results  # Present in both
    
    # Calculate basic percentages
    perc_only_original = (len(only_in_original) / total_original * 100) if total_original > 0 else 0
    perc_only_compressed = (len(only_in_compressed) / total_compressed * 100) if total_compressed > 0 else 0
    perc_both_vs_original = (len(in_both) / total_original * 100) if total_original > 0 else 0
    perc_both_vs_compressed = (len(in_both) / total_compressed * 100) if total_compressed > 0 else 0
    
    # Calculate error metrics (treating original as ground truth)
    # False Positives: sequences found by compressed index but not in original (incorrect additions)
    false_positives = only_in_compressed
    # False Negatives: sequences in original but missed by compressed index (missed results)
    false_negatives = only_in_original
    
    # Precision: percentage of compressed results that are correct
    # Formula: Correct matches / Total compressed results - "Of all sequences the compressed index found, how many are correct?"
    precision = (len(in_both) / total_compressed * 100) if total_compressed > 0 else 0
    
    # Recall (Sensitivity): percentage of original results that were found by compressed
    # Formula: Correct matches / Total original results - "Of all sequences that should be found, how many did compressed find?"
    recall = (len(in_both) / total_original * 100) if total_original > 0 else 0
    
    # F1-Score: harmonic mean of precision and recall (balances both metrics)
    # Formula: 2 * (Precision * Recall) / (Precision + Recall)
    # Higher F1-Score = better overall performance
    f1_score = (2 * precision * recall / (precision + recall)) if (precision + recall) > 0 else 0
    
    # Prepare results for output
    results = []
    results.append("="*60)
    results.append("QUERY COMPARISON RESULTS")
    results.append("="*60)
    results.append(f"Original index results (ground truth): {total_original}")
    results.append(f"Compressed index results: {total_compressed}")
    results.append("")
    results.append("DETAILED ANALYSIS (treating original as ground truth):")
    results.append(f"  Sequences in both indices: {len(in_both)}")
    results.append(f"    - As % of original: {perc_both_vs_original:.2f}%")
    results.append(f"    - As % of compressed: {perc_both_vs_compressed:.2f}%")
    results.append(f"  Sequences only in original (False Negatives): {len(false_negatives)} ({perc_only_original:.2f}% of original)")
    results.append(f"    -> These are sequences that compressed index missed")
    results.append(f"  Sequences only in compressed (False Positives): {len(false_positives)} ({perc_only_compressed:.2f}% of compressed)")
    results.append(f"    -> These are incorrect sequences found by compressed index")
    results.append("")
    results.append("PERFORMANCE METRICS:")
    results.append(f"  Precision (% of compressed results that are correct): {precision:.2f}%")
    results.append(f"    -> Of {total_compressed} sequences found by compressed, {len(in_both)} are correct")
    results.append(f"  Recall (% of original results found by compressed): {recall:.2f}%")
    results.append(f"    -> Of {total_original} sequences that should be found, {len(in_both)} were found")
    results.append(f"  F1-Score (balanced precision-recall metric): {f1_score:.2f}%")
    results.append(f"    -> Higher F1-Score indicates better overall performance")
    results.append("="*60)
    
    # Print to console
    for line in results:
        print(line)
    
    # Save to file
    with open(output_file, 'w') as f:
        for line in results:
            f.write(line + '\n')
    
    print(f"\nResults saved to: {output_file}")

if __name__ == "__main__":
    main()