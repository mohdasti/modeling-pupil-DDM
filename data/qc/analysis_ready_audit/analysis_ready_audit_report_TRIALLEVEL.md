# Trial-Level Analysis-Ready Data Audit Report

**Generated:** 2025-12-20 00:20:12

## Executive Summary

**STATUS: ❌ FAIL**

## Hard Truths

### Dataset Characteristics

- **Total trials:** 3357
- **Total subjects:** 50
- **Tasks:** ADT, VDT
- **Sessions:** 1
- **Runs:** 5

### Trials per Subject×Task

- **Min:** 1
- **Median:** 27.5
- **Max:** 126

### Inventory Coverage

- **Coverage:** Not available

### Gate Pass Rates (Trial-Level) at Threshold 0.80

- **pass_stimlocked_t080:** 46.5 %
- **pass_total_auc_t080:** 57.7 %
- **pass_cog_auc_t080:** 44.8 %

---

## Detailed Results

### STEP 1: File Freshness / Provenance

| File Type | Path | Exists | Last Modified | Size (MB) | Rows | Cols |
|-----------|------|--------|---------------|-----------|------|------|
| triallevel | BAP_analysis_ready_TRIALLEVEL.csv | Yes | 2025-12-20 00:16:59 | 0.77 | 3357 | 32 |
| inventory | 00_data_inventory_file_inventory.csv | Yes | 2025-12-19 23:05:51 | 0.02 | 90 | 6 |
| trial_coverage | 01_trial_coverage_prefilter.csv.gz | Yes | 2025-12-19 23:05:51 | 0.17 | 3357 | 54 |
| subject_stats | 08_analysis_ready_subject_stats.csv | Yes | 2025-12-19 23:05:52 | 0 | 50 | 19 |
| threshold_sweep | 03_threshold_sweep_long.csv.gz | Yes | 2025-12-19 23:05:52 | 0.06 | 16704 | 7 |

### STEP 2: Inventory Completeness

| Metric | Value |
|--------|-------|
| expected_units | 0 |
| observed_units | 287 |
| missing_units | 0 |
| missing_pct | NA |
| coverage_pct | NA |

### STEP 3: Uniqueness Checks

| Check | Value |
|-------|-------|
| total_trials | 3357 |
| unique_trial_uid | 3357 |
| duplicate_trial_uid | 0 |
| granularity | trial_level |

### STEP 4: Gate Logic Validation

| Gate Column | Mismatch Rate | N Mismatches | N Total |
|-------------|---------------|--------------|---------|
| pass_stimlocked_t080 | 0.0000 | 0 | 3339 |
| pass_total_auc_t080 | 0.0000 | 0 | 3357 |
| pass_cog_auc_t080 | 0.0000 | 0 | 3319 |

### STEP 5: Trial Retention Curves

| Threshold | Gate Type | N Pass | N Total | Retention Rate |
|-----------|-----------|--------|---------|----------------|
| 0.50 | stimlocked | 2458 | 3334 | 0.737 |
| 0.50 | total_auc | 3326 | 3357 | 0.991 |
| 0.50 | cog_auc | 2716 | 3314 | 0.820 |
| 0.60 | stimlocked | 2213 | 3335 | 0.664 |
| 0.60 | total_auc | 3231 | 3357 | 0.962 |
| 0.60 | cog_auc | 2358 | 3316 | 0.711 |
| 0.70 | stimlocked | 1977 | 3335 | 0.593 |
| 0.70 | total_auc | 2883 | 3357 | 0.859 |
| 0.70 | cog_auc | 1972 | 3316 | 0.595 |
| 0.80 | stimlocked | 1553 | 3339 | 0.465 |
| 0.80 | total_auc | 1937 | 3357 | 0.577 |
| 0.80 | cog_auc | 1488 | 3319 | 0.448 |
| 0.85 | stimlocked | 1218 | 3344 | 0.364 |
| 0.85 | total_auc | 1298 | 3357 | 0.387 |
| 0.85 | cog_auc | 1280 | 3319 | 0.386 |
| 0.90 | stimlocked | 920 | 3348 | 0.275 |
| 0.90 | total_auc | 728 | 3357 | 0.217 |
| 0.90 | cog_auc | 1107 | 3319 | 0.334 |
| 0.95 | stimlocked | 547 | 3349 | 0.163 |
| 0.95 | total_auc | 269 | 3357 | 0.080 |
| 0.95 | cog_auc | 992 | 3320 | 0.299 |

### STEP 6: Bias Checks

| Gate Column | Predictor | Max Pass Rate | Min Pass Rate | Difference (%) | Flagged |
|-------------|-----------|---------------|---------------|----------------|---------|
| gate_stimlocked_T | task | 0.672 | 0.644 | 2.7 | ✓ |
| gate_stimlocked_T | effort | 0.667 | 0.659 | 0.8 | ✓ |
| gate_stimlocked_T | oddball | 0.663 | NA | 0.1 | ✓ |
| gate_total_auc_T | task | 0.978 | 0.944 | 3.4 | ✓ |
| gate_total_auc_T | effort | 0.966 | 0.966 | 0.0 | ✓ |
| gate_total_auc_T | oddball | 0.970 | NA | 1.0 | ✓ |
| gate_cog_auc_T | task | 0.719 | 0.682 | 3.7 | ✓ |
| gate_cog_auc_T | effort | 0.703 | 0.701 | 0.2 | ✓ |
| gate_cog_auc_T | oddball | 0.703 | NA | 0.2 | ✓ |
| pass_stimlocked_t080 | task | 0.495 | 0.428 | 6.7 | ✓ |
| pass_stimlocked_t080 | effort | 0.474 | 0.462 | 1.2 | ✓ |
| pass_stimlocked_t080 | oddball | 0.474 | NA | 1.5 | ✓ |
| pass_total_auc_t080 | task | 0.642 | 0.498 | 14.3 | ⚠️ |
| pass_total_auc_t080 | effort | 0.589 | 0.574 | 1.5 | ✓ |
| pass_total_auc_t080 | oddball | 0.601 | NA | 3.1 | ✓ |
| pass_cog_auc_t080 | task | 0.487 | 0.402 | 8.5 | ✓ |
| pass_cog_auc_t080 | effort | 0.457 | 0.438 | 1.8 | ✓ |
| pass_cog_auc_t080 | oddball | 0.463 | NA | 2.6 | ✓ |

---

## What to Fix Next

### Critical Issues

1 . Task bias in pass_total_auc_t080: 14.3 percentage point difference

---

## Supporting Files

All supporting CSV tables are available in: `data/qc/analysis_ready_audit/`

- `file_provenance_triallevel.csv` - File timestamps and sizes
- `inventory_summary_triallevel.csv` - Expected vs observed data counts
- `missing_subject_task_run_triallevel.csv` - Missing data units
- `uniqueness_checks_triallevel.csv` - Duplicate row analysis
- `gate_recompute_mismatch_triallevel.csv` - Gate logic validation
- `retention_curves_triallevel.csv` - Trial retention by threshold
- `gate_bias_checks_triallevel.csv` - Selection bias analysis

