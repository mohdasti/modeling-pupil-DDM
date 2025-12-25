# Analysis-Ready Data Audit Report

**Generated:** 2025-12-20 00:09:00

## Executive Summary

**STATUS: ✅ PASS**

### Key Findings

**Key Strengths:**

1. All files are up-to-date
2. Data completeness is within acceptable range
3. Gate logic is consistent

---

## STEP 1: File Freshness / Provenance

### File Information

| File Type | Path | Exists | Last Modified | Size (MB) | Rows | Cols |
|-----------|------|--------|---------------|-----------|------|------|
| merged | BAP_analysis_ready_MERGED.csv | Yes | 2025-12-19 23:06:01 | 1529.96 | N/A | 18 |
| inventory | 00_data_inventory_file_inventory.csv | Yes | 2025-12-19 23:05:51 | 0.02 | 90 | 6 |
| trial_coverage | 01_trial_coverage_prefilter.csv.gz | Yes | 2025-12-19 23:05:51 | 0.17 | N/A | 54 |
| subject_stats | 08_analysis_ready_subject_stats.csv | Yes | 2025-12-19 23:05:52 | 0 | 50 | 19 |
| threshold_sweep | 03_threshold_sweep_long.csv.gz | Yes | 2025-12-19 23:05:52 | 0.06 | N/A | 7 |
| avail_stim | 06_availability_stimulus_locked_long.csv | Yes | 2025-12-19 23:05:52 | 0.15 | 2740 | 6 |
| avail_resp | 07_availability_response_locked_long.csv | Yes | 2025-12-19 23:05:52 | 6.85 | 157312 | 6 |

---

## STEP 2: Inventory Completeness

### Summary

| Metric | Value |
|--------|-------|
| expected_units | 90 |
| observed_units | 287 |
| missing_units | 90 |
| missing_pct | 100 |

---

## STEP 3: Uniqueness Checks

| Check | Value |
|-------|-------|
| total_rows | 11322088 |
| unique_trials | 3357 |
| duplicate_rows | 11318731 |
| duplicate_pct | 99.97 |
| granularity | sample_level |

---

## STEP 4: Gate Logic Validation

*No gate mismatches detected*

---

## STEP 5: Trial Retention Curves

### Retention by Threshold

| Threshold | Gate Type | N Pass | N Total | Retention Rate |
|-----------|-----------|--------|---------|----------------|
| 0.50 | stimlocked | 8334692 | 11292319 | 0.738 |
| 0.50 | total_auc | 11217982 | 11322088 | 0.991 |
| 0.50 | cog_auc | 9236640 | 11256374 | 0.821 |
| 0.60 | stimlocked | 7500670 | 11293646 | 0.664 |
| 0.60 | total_auc | 10894052 | 11322088 | 0.962 |
| 0.60 | cog_auc | 8019774 | 11259922 | 0.712 |
| 0.70 | stimlocked | 6703558 | 11293646 | 0.594 |
| 0.70 | total_auc | 9728689 | 11322088 | 0.859 |
| 0.70 | cog_auc | 6701506 | 11259922 | 0.595 |
| 0.80 | stimlocked | 5267025 | 11298728 | 0.466 |
| 0.80 | total_auc | 6540913 | 11322088 | 0.578 |
| 0.80 | cog_auc | 5054697 | 11264843 | 0.449 |
| 0.85 | stimlocked | 4135429 | 11305106 | 0.366 |
| 0.85 | total_auc | 4385801 | 11322088 | 0.387 |
| 0.85 | cog_auc | 4346547 | 11264843 | 0.386 |
| 0.90 | stimlocked | 3122711 | 11310047 | 0.276 |
| 0.90 | total_auc | 2461296 | 11322088 | 0.217 |
| 0.90 | cog_auc | 3756493 | 11264843 | 0.333 |
| 0.95 | stimlocked | 1856492 | 11311450 | 0.164 |
| 0.95 | total_auc | 906812 | 11322088 | 0.080 |
| 0.95 | cog_auc | 3368093 | 11266216 | 0.299 |

---

## STEP 6: Prestim Dip Containment

*See figures in `figures/` directory*

---

## STEP 7: Bias Checks

| Gate Column | Predictor | Max Pass Rate | Min Pass Rate | Difference (%) | Flagged |
|-------------|-----------|---------------|---------------|----------------|---------|
| gate_stimlocked_T | task | 0.676 | 0.646 | 3.0 | ✓ |
| gate_stimlocked_T | effort | 0.671 | 0.661 | 1.0 | ✓ |
| gate_stimlocked_T | oddball | 0.673 | 0.661 | 1.2 | ✓ |
| gate_total_auc_T | task | 0.978 | 0.943 | 3.4 | ✓ |
| gate_total_auc_T | effort | 0.966 | 0.965 | 0.1 | ✓ |
| gate_total_auc_T | oddball | 0.972 | 0.960 | 1.2 | ✓ |
| gate_cog_auc_T | task | 0.725 | 0.688 | 3.8 | ✓ |
| gate_cog_auc_T | effort | 0.707 | 0.707 | 0.1 | ✓ |
| gate_cog_auc_T | oddball | 0.710 | 0.700 | 1.0 | ✓ |

---

## What to Fix Next

*No critical issues identified*

---

## Supporting Files

All supporting CSV tables are available in: `data/qc/analysis_ready_audit/`

- `file_provenance.csv` - File timestamps and sizes
- `inventory_summary.csv` - Expected vs observed data counts
- `missing_subject_task_run.csv` - Missing data units
- `uniqueness_checks.csv` - Duplicate row analysis
- `gate_column_presence.csv` - Gate column inventory
- `gate_recompute_mismatch.csv` - Gate logic validation
- `gate_overlap_jaccard.csv` - Gate overlap analysis
- `retention_curves_from_merged.csv` - Trial retention by threshold
- `prestim_dip_containment_summary.csv` - Prestim dip analysis
- `gate_bias_checks.csv` - Selection bias analysis

