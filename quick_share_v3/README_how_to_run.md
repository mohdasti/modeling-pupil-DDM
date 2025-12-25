# Quick-Share v3: How to Run

## Prerequisites

1. **Trial-level QC file must exist**: `derived/triallevel_qc.csv`
   - Generate this by running: `Rscript R/quickshare_build_triallevel.R`

2. **Config file**: `config/data_paths.yaml`
   - Must specify `behavioral_csv` path
   - Example:
     ```yaml
     processed_dir: "/path/to/BAP_processed"
     behavioral_csv: "/path/to/behavior_TRIALLEVEL_normalized.csv"
     ```

## Run Command

```bash
Rscript scripts/make_merged_quickshare.R
```

## Outputs

### Quick-Share CSVs (8 files)
Located in: `quick_share_v3/quick_share/`

1. **01_merge_diagnostics.csv** - Match rates, unmatched keys
2. **02_trials_per_subject_task_ses.csv** - Coverage by subject/task/session
3. **03_condition_cell_counts.csv** - Trials by condition (effort × intensity)
4. **04_run_level_counts.csv** - QC metrics per run
5. **05_window_validity_summary.csv** - Window quality distributions
6. **06_gate_pass_rates_by_threshold.csv** - Pass rates at 0.50/0.60/0.70
7. **07_bias_checks_key_gates.csv** - Bias analysis (effort/task effects)
8. **08_trial_level_for_jitter.csv** - TR jitter diagnostics

### Merged Trial-Level Dataset
Located in: `quick_share_v3/merged/BAP_triallevel_merged.csv`

- One row per trial (sub, task, session_used, run_used, trial_index)
- Contains: behavioral columns (rt, choice, correct, effort, stimulus_intensity) + pupil QC + gate flags

## Validation

The script will:
- ✅ Assert that at least some trials matched (stops if n_matched == 0)
- ✅ Report match rates by task
- ✅ Show top 20 unmatched keys if mismatches exist

## Troubleshooting

**Problem**: `n_beh_trials=0` or all behavioral columns are NA

**Solutions**:
1. Check that `behavioral_csv` path in `config/data_paths.yaml` is correct
2. Verify behavioral file has columns: `subject_id` (or `sub`), `task_modality` (or `task`), `session_num` (or `session_used`), `run_num` (or `run_used`), `trial_num` (or `trial_index`)
3. Check that behavioral file is filtered to sessions 2-3 and tasks ADT/VDT
4. Verify merge keys match between pupil and behavioral data (check sample keys printed in error message)

**Problem**: `Error: Trial-level QC file not found`

**Solution**: Run `Rscript R/quickshare_build_triallevel.R` first to generate `derived/triallevel_qc.csv`

