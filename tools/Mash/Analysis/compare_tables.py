#!/usr/bin/env python3
"""
Script to compare two Mash distance tables to evaluate compression quality.
Combines error statistics, correlation analysis, and Bland-Altman plot.
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats
import sys

def load_mash_table(filepath):
    """Load Mash distance table and convert to matrix."""
    print(f"Loading {filepath}...")
    
    # Read the table (skip comment line if present)
    df = pd.read_csv(filepath, sep='\t', comment='#', header=None)
    
    # Extract genome names from first column
    genomes = df.iloc[:, 0].values
    
    # Extract distance matrix (skip first column which contains names)
    distances = df.iloc[:, 1:].values.astype(float)
    
    print(f"  - Found {len(genomes)} genomes")
    print(f"  - Matrix shape: {distances.shape}")
    
    return genomes, distances

def calculate_error_metrics(orig, comp):
    """Calculate various error metrics between original and compressed distances."""
    
    # Get upper triangle (exclude diagonal) to avoid counting pairs twice
    mask = np.triu(np.ones_like(orig, dtype=bool), k=1)
    orig_flat = orig[mask]
    comp_flat = comp[mask]
    
    # Calculate errors
    diff = np.abs(orig_flat - comp_flat)
    
    metrics = {
        'MAE': np.mean(diff),
        'RMSE': np.sqrt(np.mean(diff**2)),
        'Max Error': np.max(diff),
        'Min Error': np.min(diff),
        'Median Error': np.median(diff),
        'Std Error': np.std(diff),
        'Total Comparisons': len(orig_flat)
    }
    
    # Percentage under thresholds
    for threshold in [0.001, 0.005, 0.01, 0.05]:
        pct = 100 * np.sum(diff < threshold) / len(diff)
        metrics[f'% < {threshold}'] = pct
    
    return metrics, orig_flat, comp_flat, diff

def plot_correlation(orig, comp, output_file='correlation_plot.png'):
    """Create scatter plot of original vs compressed distances."""
    
    fig, ax = plt.subplots(figsize=(10, 10))
    
    # Scatter plot
    ax.scatter(orig, comp, alpha=0.5, s=20, edgecolors='none')
    
    # Perfect correlation line
    min_val = min(orig.min(), comp.min())
    max_val = max(orig.max(), comp.max())
    ax.plot([min_val, max_val], [min_val, max_val], 'r--', 
            label='Perfect correlation', linewidth=2)
    
    # Calculate correlation
    pearson_r, pearson_p = stats.pearsonr(orig, comp)
    spearman_r, spearman_p = stats.spearmanr(orig, comp)
    
    # Add text with correlations
    textstr = f'Pearson r = {pearson_r:.6f}\nSpearman ρ = {spearman_r:.6f}'
    ax.text(0.05, 0.95, textstr, transform=ax.transAxes, 
            fontsize=12, verticalalignment='top',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    ax.set_xlabel('Original Distances', fontsize=12)
    ax.set_ylabel('Compressed Distances', fontsize=12)
    ax.set_title('Original vs Compressed Distance Correlation', fontsize=14, fontweight='bold')
    ax.legend()
    ax.grid(True, alpha=0.3)
    ax.set_aspect('equal')
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"\nCorrelation plot saved: {output_file}")
    
    return pearson_r, spearman_r

def plot_bland_altman(orig, comp, output_file='bland_altman_plot.png'):
    """
    Create Bland-Altman plot to identify systematic bias.
    
    Note: The difference is calculated as (original - compressed).
    - Positive mean difference: compression UNDERESTIMATES distances
    - Negative mean difference: compression OVERESTIMATES distances
    """
    
    mean_dist = (orig + comp) / 2
    diff_dist = orig - comp  # IMPORTANT: orig - comp (not comp - orig)
    
    mean_diff = np.mean(diff_dist)
    std_diff = np.std(diff_dist)
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # Scatter plot
    ax.scatter(mean_dist, diff_dist, alpha=0.5, s=20, edgecolors='none')
    
    # Mean line
    ax.axhline(mean_diff, color='blue', linestyle='-', linewidth=2, 
               label=f'Mean difference = {mean_diff:.6f}')
    
    # Limits of agreement (mean ± 1.96*SD)
    upper_loa = mean_diff + 1.96 * std_diff
    lower_loa = mean_diff - 1.96 * std_diff
    
    ax.axhline(upper_loa, color='red', linestyle='--', linewidth=2,
               label=f'Upper LoA = {upper_loa:.6f}')
    ax.axhline(lower_loa, color='red', linestyle='--', linewidth=2,
               label=f'Lower LoA = {lower_loa:.6f}')
    
    # Zero line
    ax.axhline(0, color='gray', linestyle=':', linewidth=1, alpha=0.5)
    
    ax.set_xlabel('Mean of Original and Compressed Distances', fontsize=12)
    ax.set_ylabel('Difference (Original - Compressed)', fontsize=12)
    ax.set_title('Bland-Altman Plot: Systematic Bias Analysis', fontsize=14, fontweight='bold')
    ax.legend(loc='best')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"Bland-Altman plot saved: {output_file}")
    
    return mean_diff, std_diff, upper_loa, lower_loa

def find_worst_cases(genomes, orig_matrix, comp_matrix, n=10):
    """Find genome pairs with largest distance differences."""
    
    n_genomes = len(genomes)
    worst_cases = []
    
    for i in range(n_genomes):
        for j in range(i+1, n_genomes):
            diff = abs(orig_matrix[i, j] - comp_matrix[i, j])
            worst_cases.append({
                'Genome1': genomes[i],
                'Genome2': genomes[j],
                'Original_Distance': orig_matrix[i, j],
                'Compressed_Distance': comp_matrix[i, j],
                'Absolute_Difference': diff,
                'Relative_Error_%': 100 * diff / orig_matrix[i, j] if orig_matrix[i, j] > 0 else 0
            })
    
    # Sort by absolute difference
    worst_cases.sort(key=lambda x: x['Absolute_Difference'], reverse=True)
    
    return worst_cases[:n]

def main():
    """Main analysis function."""
    
    # Parse command line arguments
    if len(sys.argv) == 3:
        original_file = sys.argv[1]
        compressed_file = sys.argv[2]
        print(f"Comparing: {original_file} (original) vs {compressed_file} (compressed)")
    elif len(sys.argv) == 1:
        # Default files for backward compatibility
        original_file = "TestDataset_table.txt"
        compressed_file = "Test2_table.txt"
        print("\n" + "!"*70)
        print("WARNING: Using default file names!")
        print("!"*70)
        print(f"Original:   {original_file}")
        print(f"Compressed: {compressed_file}")
        print("\nIMPORTANT: Make sure to put UNCOMPRESSED file first, COMPRESSED second")
        print("Usage: python3 compare_tables.py <uncompressed_table.txt> <compressed_table.txt>")
        print("!"*70 + "\n")
    else:
        print("Usage: python3 compare_tables.py <original_table.txt> <compressed_table.txt>")
        print("\nArguments:")
        print("  original_table.txt    - Mash distance table for UNCOMPRESSED/ORIGINAL genomes")
        print("  compressed_table.txt  - Mash distance table for COMPRESSED genomes")
        print("\nNote: Order matters for Bland-Altman bias interpretation!")
        print("      Always put uncompressed/original file FIRST.")
        print("\nIf no arguments provided, defaults to:")
        print("  - TestDataset_table.txt (original)")
        print("  - Test2_table.txt (compressed)")
        sys.exit(1)
    
    print("="*70)
    print("MASH DISTANCE TABLE COMPARISON - COMPRESSION QUALITY ANALYSIS")
    print("="*70)
    print()
    
    # Load tables
    orig_genomes, orig_matrix = load_mash_table(original_file)
    comp_genomes, comp_matrix = load_mash_table(compressed_file)
    
    # Verify same genomes
    if not np.array_equal(orig_genomes, comp_genomes):
        print("\nWARNING: Genome names don't match perfectly!")
        print("Attempting to align genomes...")
        # Simple name matching (you might need more sophisticated matching)
        orig_names = [g.split('/')[-1] for g in orig_genomes]
        comp_names = [g.split('/')[-1] for g in comp_genomes]
        if orig_names != comp_names:
            print("ERROR: Cannot align genomes. Exiting.")
            sys.exit(1)
    
    print("\n" + "="*70)
    print("1. ERROR STATISTICS")
    print("="*70)
    
    metrics, orig_flat, comp_flat, diff = calculate_error_metrics(orig_matrix, comp_matrix)
    
    for key, value in metrics.items():
        if key.startswith('%'):
            print(f"{key:25s}: {value:8.2f}%")
        elif 'Comparisons' in key:
            print(f"{key:25s}: {value:8.0f}")
        else:
            print(f"{key:25s}: {value:8.6f}")
    
    print("\n" + "="*70)
    print("2. CORRELATION ANALYSIS")
    print("="*70)
    
    pearson_r, spearman_r = plot_correlation(orig_flat, comp_flat)
    
    print(f"\nPearson correlation:  {pearson_r:.6f}")
    print(f"Spearman correlation: {spearman_r:.6f}")
    
    if pearson_r > 0.99:
        print("✓ Excellent correlation - compression preserves distances very well!")
    elif pearson_r > 0.95:
        print("✓ Good correlation - compression quality is acceptable")
    else:
        print("⚠ Moderate correlation - significant information loss in compression")
    
    print("\n" + "="*70)
    print("3. BLAND-ALTMAN ANALYSIS")
    print("="*70)
    
    mean_diff, std_diff, upper_loa, lower_loa = plot_bland_altman(orig_flat, comp_flat)
    
    print(f"\nMean difference:          {mean_diff:.6f}")
    print(f"Std of differences:       {std_diff:.6f}")
    print(f"Limits of Agreement:      [{lower_loa:.6f}, {upper_loa:.6f}]")
    
    if abs(mean_diff) < 0.001:
        print("✓ No systematic bias detected")
    elif mean_diff > 0:
        print("⚠ Systematic bias: compression tends to UNDERESTIMATE distances")
    else:
        print("⚠ Systematic bias: compression tends to OVERESTIMATE distances")
    
    print("\n" + "="*70)
    print("4. WORST CASES (Top 10 largest differences)")
    print("="*70)
    
    worst = find_worst_cases(orig_genomes, orig_matrix, comp_matrix, n=10)
    
    print(f"\n{'Rank':<5} {'Genome 1':<30} {'Genome 2':<30} {'Original':<10} {'Compressed':<10} {'Diff':<10} {'Rel.Err%':<10}")
    print("-"*120)
    
    for i, case in enumerate(worst, 1):
        g1 = case['Genome1'].split('/')[-1][:28]
        g2 = case['Genome2'].split('/')[-1][:28]
        print(f"{i:<5} {g1:<30} {g2:<30} {case['Original_Distance']:<10.6f} "
              f"{case['Compressed_Distance']:<10.6f} {case['Absolute_Difference']:<10.6f} "
              f"{case['Relative_Error_%']:<10.2f}")
    
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    print(f"\nCompression Quality Score:")
    print(f"  - Correlation: {pearson_r:.4f} (higher is better, max 1.0)")
    print(f"  - MAE: {metrics['MAE']:.6f} (lower is better)")
    print(f"  - {metrics['% < 0.01']:.1f}% of distances have error < 0.01")
    
    # Overall assessment
    score = pearson_r * 0.5 + (metrics['% < 0.01'] / 100) * 0.3 + (1 - min(metrics['MAE'] * 10, 1)) * 0.2
    
    print(f"\nOverall Quality Score: {score:.3f} / 1.000")
    if score > 0.95:
        print("Rating: ★★★★★ EXCELLENT - Compression is nearly lossless")
    elif score > 0.85:
        print("Rating: ★★★★☆ GOOD - Compression preserves most information")
    elif score > 0.70:
        print("Rating: ★★★☆☆ FAIR - Noticeable information loss")
    else:
        print("Rating: ★★☆☆☆ POOR - Significant information loss")
    
    print("\n" + "="*70)

if __name__ == "__main__":
    main()
