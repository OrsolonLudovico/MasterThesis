#!/usr/bin/env python3
"""
Full GGCAT Analysis Pipeline
Runs queries on both graphs, compares graphs, and analyzes query results
"""

import subprocess
import sys
import os
import json
from pathlib import Path
from collections import defaultdict
import re

def run_command(cmd, description):
    """Run a shell command and return success status"""
    print(f"\n{'='*60}")
    print(f"Running: {description}")
    print(f"{'='*60}")
    try:
        result = subprocess.run(cmd, shell=True, check=True, 
                              capture_output=True, text=True)
        print(result.stdout)
        if result.stderr:
            print(f"Warnings/Info: {result.stderr}", file=sys.stderr)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error running {description}", file=sys.stderr)
        print(f"Exit code: {e.returncode}", file=sys.stderr)
        print(f"Output: {e.stdout}", file=sys.stderr)
        print(f"Error: {e.stderr}", file=sys.stderr)
        return False, None

def parse_query_results(result_file):
    """
    Parse GGCAT query results
    Returns: dict with found k-mers, colors, and statistics
    """
    if not os.path.exists(result_file):
        return None
    
    results = {
        'total_kmers': 0,
        'found_kmers': 0,
        'not_found_kmers': 0,
        'sequences': [],
        'colors': defaultdict(int)
    }
    
    try:
        with open(result_file, 'r') as f:
            content = f.read()
            
            # Count sequences (headers starting with >)
            sequences = content.split('>')[1:]  # Split by > and skip first empty
            results['total_kmers'] = len(sequences)
            
            for seq in sequences:
                lines = seq.strip().split('\n')
                if len(lines) < 2:
                    continue
                    
                header = lines[0]
                sequence = ''.join(lines[1:])
                
                # Extract color information from header (C:color_id:count)
                color_match = re.search(r'C:(\d+):(\d+)', header)
                if color_match:
                    color_id = int(color_match.group(1))
                    count = int(color_match.group(2))
                    results['colors'][color_id] += count
                    results['found_kmers'] += 1
                
                results['sequences'].append({
                    'header': header,
                    'sequence': sequence,
                    'length': len(sequence)
                })
    
    except Exception as e:
        print(f"Error parsing {result_file}: {e}", file=sys.stderr)
        return None
    
    results['not_found_kmers'] = results['total_kmers'] - results['found_kmers']
    return results

def compare_query_results(results1, results2, query_name):
    """
    Compare two query results and calculate metrics
    """
    if results1 is None or results2 is None:
        return None
    
    # Extract sequences for comparison
    seqs1 = set(s['sequence'] for s in results1['sequences'])
    seqs2 = set(s['sequence'] for s in results2['sequences'])
    
    # Calculate true positives, false positives, false negatives
    # Assuming results1 is the reference (ground truth)
    true_positives = len(seqs1 & seqs2)  # Found in both
    false_positives = len(seqs2 - seqs1)  # Found in 2 but not in 1
    false_negatives = len(seqs1 - seqs2)  # Found in 1 but not in 2
    true_negatives = 0  # Hard to define for this problem
    
    # Calculate metrics
    precision = true_positives / (true_positives + false_positives) if (true_positives + false_positives) > 0 else 0
    recall = true_positives / (true_positives + false_negatives) if (true_positives + false_negatives) > 0 else 0
    f1_score = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
    
    comparison = {
        'query_name': query_name,
        'true_positives': true_positives,
        'false_positives': false_positives,
        'false_negatives': false_negatives,
        'precision': precision,
        'recall': recall,
        'f1_score': f1_score,
        'total_seqs_graph1': len(seqs1),
        'total_seqs_graph2': len(seqs2),
        'identical': seqs1 == seqs2
    }
    
    return comparison

def analyze_abundance(results1, results2, query_name):
    """
    Compare abundance (color distribution) between two results
    """
    if results1 is None or results2 is None:
        return None
    
    colors1 = results1['colors']
    colors2 = results2['colors']
    
    all_colors = set(colors1.keys()) | set(colors2.keys())
    
    abundance_comparison = {
        'query_name': query_name,
        'colors': {}
    }
    
    for color in all_colors:
        count1 = colors1.get(color, 0)
        count2 = colors2.get(color, 0)
        diff = abs(count1 - count2)
        
        abundance_comparison['colors'][color] = {
            'graph1': count1,
            'graph2': count2,
            'difference': diff,
            'relative_diff': diff / max(count1, count2) if max(count1, count2) > 0 else 0
        }
    
    return abundance_comparison

def main():
    if len(sys.argv) != 3:
        print("Usage: python run_full_analysis.py <graph1_folder> <graph2_folder>")
        print("Example: python run_full_analysis.py ./testDataset_GGCAT ./Test2_GGCAT")
        sys.exit(1)
    
    graph1_folder = sys.argv[1]
    graph2_folder = sys.argv[2]
    
    # Validate inputs
    if not os.path.isdir(graph1_folder) or not os.path.isdir(graph2_folder):
        print("Error: Both graph folders must exist", file=sys.stderr)
        sys.exit(1)
    
    print("="*60)
    print("GGCAT FULL ANALYSIS PIPELINE")
    print("="*60)
    print(f"Graph 1: {graph1_folder}")
    print(f"Graph 2: {graph2_folder}")
    print()
    
    # Step 1: Run queries on both graphs
    success, _ = run_command(
        f"bash queryBothGGCAT.sh {graph1_folder} {graph2_folder}",
        "Querying both graphs"
    )
    if not success:
        print("Warning: Query execution had issues", file=sys.stderr)
    
    # Step 2: Compare graphs
    success, _ = run_command(
        f"bash compareGGCAT_graphs.sh {graph1_folder} {graph2_folder}",
        "Comparing graph structures"
    )
    if not success:
        print("Warning: Graph comparison had issues", file=sys.stderr)
    
    # Step 3: Analyze query results
    print("\n" + "="*60)
    print("ANALYZING QUERY RESULTS")
    print("="*60)
    
    query_dir1 = Path(graph1_folder) / "query_results"
    query_dir2 = Path(graph2_folder) / "query_results"
    
    if not query_dir1.exists() or not query_dir2.exists():
        print("Error: Query results directories not found", file=sys.stderr)
        sys.exit(1)
    
    # Find all result files
    result_files1 = sorted(query_dir1.glob("*_result.txt"))
    
    all_comparisons = []
    all_abundances = []
    
    for result_file1 in result_files1:
        query_name = result_file1.stem.replace('_result', '')
        result_file2 = query_dir2 / result_file1.name
        
        if not result_file2.exists():
            print(f"Warning: No matching result for {query_name} in graph 2", file=sys.stderr)
            continue
        
        print(f"\nAnalyzing query: {query_name}")
        
        # Parse results
        results1 = parse_query_results(str(result_file1))
        results2 = parse_query_results(str(result_file2))
        
        if results1 is None or results2 is None:
            print(f"  Error parsing results for {query_name}", file=sys.stderr)
            continue
        
        # Compare results
        comparison = compare_query_results(results1, results2, query_name)
        if comparison:
            all_comparisons.append(comparison)
            print(f"  True Positives: {comparison['true_positives']}")
            print(f"  False Positives: {comparison['false_positives']}")
            print(f"  False Negatives: {comparison['false_negatives']}")
            print(f"  Precision: {comparison['precision']:.4f}")
            print(f"  Recall: {comparison['recall']:.4f}")
            print(f"  F1 Score: {comparison['f1_score']:.4f}")
        
        # Analyze abundance
        abundance = analyze_abundance(results1, results2, query_name)
        if abundance:
            all_abundances.append(abundance)
            print(f"  Color diversity: {len(abundance['colors'])} unique colors")
    
    # Save detailed results
    output_file = "query_analysis_results.json"
    with open(output_file, 'w') as f:
        json.dump({
            'comparisons': all_comparisons,
            'abundances': all_abundances
        }, f, indent=2)
    
    print(f"\n\nDetailed results saved to: {output_file}")
    
    # Generate summary report
    summary_file = "analysis_summary.txt"
    with open(summary_file, 'w') as f:
        f.write("="*60 + "\n")
        f.write("GGCAT ANALYSIS SUMMARY\n")
        f.write("="*60 + "\n")
        f.write(f"Graph 1: {graph1_folder}\n")
        f.write(f"Graph 2: {graph2_folder}\n\n")
        
        if all_comparisons:
            avg_precision = sum(c['precision'] for c in all_comparisons) / len(all_comparisons)
            avg_recall = sum(c['recall'] for c in all_comparisons) / len(all_comparisons)
            avg_f1 = sum(c['f1_score'] for c in all_comparisons) / len(all_comparisons)
            
            f.write("OVERALL METRICS:\n")
            f.write(f"  Average Precision: {avg_precision:.4f}\n")
            f.write(f"  Average Recall: {avg_recall:.4f}\n")
            f.write(f"  Average F1 Score: {avg_f1:.4f}\n\n")
            
            f.write("PER-QUERY RESULTS:\n")
            for comp in all_comparisons:
                f.write(f"\n  Query: {comp['query_name']}\n")
                f.write(f"    TP: {comp['true_positives']}, ")
                f.write(f"FP: {comp['false_positives']}, ")
                f.write(f"FN: {comp['false_negatives']}\n")
                f.write(f"    Precision: {comp['precision']:.4f}, ")
                f.write(f"Recall: {comp['recall']:.4f}, ")
                f.write(f"F1: {comp['f1_score']:.4f}\n")
                f.write(f"    Identical: {comp['identical']}\n")
    
    print(f"Summary report saved to: {summary_file}")
    
    with open(summary_file, 'r') as f:
        print("\n" + f.read())

if __name__ == "__main__":
    main()
