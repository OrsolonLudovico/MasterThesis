#!/usr/bin/env python3
"""
Script to compare query results between compressed vs uncompressed indices.
The uncompressed index is considered ground truth.

Usage: python compare_results.py <ground_truth_file> <compressed_file>
"""

import sys
import csv
from pathlib import Path
from typing import Dict, Set, Tuple
import argparse


def load_csv_results(filepath: str) -> Dict[str, int]:
    """
    Load results from a CSV file.
    Returns a dictionary {header: abundance}
    
    The CSV format is: header,file,abundance
    But header may contain commas, so we parse from the end:
    - Last field is abundance (integer)
    - Second to last is file (integer)
    - Everything else is the header
    """
    results = {}
    with open(filepath, 'r') as f:
        # Skip header line
        next(f)
        for line in f:
            line = line.strip()
            if not line:
                continue
            # Split by comma and take the last two fields as file and abundance
            parts = line.split(',')
            if len(parts) < 3:
                continue
            # Last field is abundance, second to last is file
            abundance = int(parts[-1])
            file_id = parts[-2]
            # Everything else is the header
            header = ','.join(parts[:-2])
            results[header] = abundance
    return results


def calculate_metrics(ground_truth: Dict[str, int], compressed: Dict[str, int]) -> Dict:
    """
    Calculate comparison metrics between ground truth and compressed results.
    """
    gt_nodes = set(ground_truth.keys())
    comp_nodes = set(compressed.keys())
    
    # True Positives: NODE presenti in entrambi
    tp_nodes = gt_nodes & comp_nodes
    tp = len(tp_nodes)
    
    # False Positives: NODE presenti solo in compressed (non in ground truth)
    fp_nodes = comp_nodes - gt_nodes
    fp = len(fp_nodes)
    
    # False Negatives: NODE presenti solo in ground truth (mancanti in compressed)
    fn_nodes = gt_nodes - comp_nodes
    fn = len(fn_nodes)
    
    # Calcolo metriche
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1_score = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0
    
    # Analisi delle abundance per i TP
    abundance_diffs = []
    abundance_abs_diffs = []
    abundance_rel_diffs = []
    
    for node in tp_nodes:
        gt_abd = ground_truth[node]
        comp_abd = compressed[node]
        diff = comp_abd - gt_abd
        abs_diff = abs(diff)
        rel_diff = (abs_diff / gt_abd * 100) if gt_abd > 0 else 0.0
        
        abundance_diffs.append(diff)
        abundance_abs_diffs.append(abs_diff)
        abundance_rel_diffs.append(rel_diff)
    
    # Statistiche abundance
    if abundance_abs_diffs:
        mean_abs_diff = sum(abundance_abs_diffs) / len(abundance_abs_diffs)
        mean_rel_diff = sum(abundance_rel_diffs) / len(abundance_rel_diffs)
        max_abs_diff = max(abundance_abs_diffs)
        
        # Conteggio abundance identiche
        identical_abundance = sum(1 for d in abundance_abs_diffs if d == 0)
    else:
        mean_abs_diff = 0.0
        mean_rel_diff = 0.0
        max_abs_diff = 0
        identical_abundance = 0
    
    return {
        'tp': tp,
        'fp': fp,
        'fn': fn,
        'precision': precision,
        'recall': recall,
        'f1_score': f1_score,
        'tp_nodes': tp_nodes,
        'fp_nodes': fp_nodes,
        'fn_nodes': fn_nodes,
        'mean_abs_diff': mean_abs_diff,
        'mean_rel_diff': mean_rel_diff,
        'max_abs_diff': max_abs_diff,
        'identical_abundance': identical_abundance,
        'ground_truth': ground_truth,
        'compressed': compressed
    }


def print_and_save_results(metrics: Dict, output_file: str):
    """
    Print results to terminal and save to file.
    """
    lines = []
    
    # Header
    lines.append("=" * 80)
    lines.append("COMPARATIVE ANALYSIS: Compressed vs Uncompressed Index (Ground Truth)")
    lines.append("=" * 80)
    lines.append("")
    
    # Basic statistics
    lines.append("### BASIC STATISTICS ###")
    lines.append(f"Total NODEs in Ground Truth (Unc): {metrics['tp'] + metrics['fn']}")
    lines.append(f"Total NODEs in Compressed (Comp):  {metrics['tp'] + metrics['fp']}")
    lines.append("")
    
    # Comparison metrics (presence/absence)
    lines.append("### PRESENCE/ABSENCE METRICS ###")
    lines.append(f"True Positives (TP):   {metrics['tp']} (NODEs present in both)")
    lines.append(f"False Positives (FP):  {metrics['fp']} (NODEs only in Compressed)")
    lines.append(f"False Negatives (FN):  {metrics['fn']} (NODEs only in Ground Truth)")
    lines.append("")
    lines.append(f"Precision:  {metrics['precision']:.4f} ({metrics['precision']*100:.2f}%)")
    lines.append(f"Recall:     {metrics['recall']:.4f} ({metrics['recall']*100:.2f}%)")
    lines.append(f"F1 Score:   {metrics['f1_score']:.4f}")
    lines.append("")
    
    # Interpretation
    lines.append("Interpretation:")
    lines.append(f"  - {metrics['recall']*100:.2f}% of NODEs in ground truth were found")
    lines.append(f"  - {metrics['precision']*100:.2f}% of NODEs found are correct")
    if metrics['fp'] > 0:
        lines.append(f"  - {metrics['fp']} NODEs were found erroneously (false positives)")
    if metrics['fn'] > 0:
        lines.append(f"  - {metrics['fn']} NODEs were missed (false negatives)")
    lines.append("")
    
    # Abundance analysis
    if metrics['tp'] > 0:
        lines.append("### ABUNDANCE ANALYSIS (for True Positives) ###")
        lines.append(f"NODEs with identical abundance:  {metrics['identical_abundance']} / {metrics['tp']} ({metrics['identical_abundance']/metrics['tp']*100:.2f}%)")
        lines.append(f"Mean absolute difference:        {metrics['mean_abs_diff']:.2f}")
        lines.append(f"Mean relative difference:        {metrics['mean_rel_diff']:.2f}%")
        lines.append(f"Maximum absolute difference:     {metrics['max_abs_diff']}")
        lines.append("")
        
        # All NODEs with abundance differences
        tp_nodes = metrics['tp_nodes']
        gt = metrics['ground_truth']
        comp = metrics['compressed']
        
        diffs_with_nodes = []
        for node in tp_nodes:
            diff = comp[node] - gt[node]
            if diff != 0:
                diffs_with_nodes.append((node, gt[node], comp[node], diff))
        
        if diffs_with_nodes:
            diffs_with_nodes.sort(key=lambda x: abs(x[3]), reverse=True)
            lines.append(f"All NODEs with abundance differences ({len(diffs_with_nodes)} NODEs):")
            lines.append(f"{'NODE':<50} {'Unc':>8} {'Comp':>8} {'Diff':>8}")
            lines.append("-" * 80)
            for node, gt_abd, comp_abd, diff in diffs_with_nodes:
                lines.append(f"{node:<50} {gt_abd:>8} {comp_abd:>8} {diff:>8}")
            lines.append("")
    
    # False Positives details
    if metrics['fp'] > 0:
        lines.append("### FALSE POSITIVES (NODEs only in Compressed) ###")
        fp_list = sorted(metrics['fp_nodes'])
        for i, node in enumerate(fp_list, 1):
            abd = metrics['compressed'][node]
            lines.append(f"{i}. {node} (abundance: {abd})")
        lines.append("")
    
    # False Negatives details
    if metrics['fn'] > 0:
        lines.append("### FALSE NEGATIVES (NODEs only in Ground Truth) ###")
        fn_list = sorted(metrics['fn_nodes'])
        for i, node in enumerate(fn_list, 1):
            abd = metrics['ground_truth'][node]
            lines.append(f"{i}. {node} (abundance: {abd})")
        lines.append("")
    
    lines.append("=" * 80)
    
    # Print to terminal
    output_text = "\n".join(lines)
    print(output_text)
    
    # Save to file
    with open(output_file, 'w') as f:
        f.write(output_text)
    
    print(f"\nResults saved to: {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description='Compare query results between compressed vs uncompressed indices'
    )
    parser.add_argument('ground_truth', help='CSV file with ground truth results (uncompressed)')
    parser.add_argument('compressed', help='CSV file with results from compressed index')
    parser.add_argument('-o', '--output', help='Output file (default: comparison_results.txt in ground truth folder)')
    
    args = parser.parse_args()
    
    # Check file existence
    gt_path = Path(args.ground_truth)
    comp_path = Path(args.compressed)
    
    if not gt_path.exists():
        print(f"ERROR: Ground truth file not found: {args.ground_truth}")
        sys.exit(1)
    
    if not comp_path.exists():
        print(f"ERROR: Compressed file not found: {args.compressed}")
        sys.exit(1)
    
    # Determine output file
    if args.output:
        output_file = args.output
    else:
        output_file = gt_path.parent / "comparison_results.txt"
    
    print(f"Loading ground truth file: {gt_path}")
    ground_truth = load_csv_results(str(gt_path))
    
    print(f"Loading compressed file: {comp_path}")
    compressed = load_csv_results(str(comp_path))
    
    print("Calculating metrics...\n")
    metrics = calculate_metrics(ground_truth, compressed)
    
    print_and_save_results(metrics, str(output_file))


if __name__ == "__main__":
    main()
