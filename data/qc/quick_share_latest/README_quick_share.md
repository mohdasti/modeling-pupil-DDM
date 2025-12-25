# Quick-Share QC Snapshot

Generated: 2025-12-22 13:16:53
Git hash: 24ef945

## Trial Identity

**Trial UID Definition**: `paste(sub, task, session_used, run_used, trial_in_run_raw, sep=":")`

This is the canonical identifier for each trial. All trial counts use `n_distinct(trial_uid)` to avoid double-counting.

## Hard Assertions

- **Sessions**: Only sessions 2-3 are included (session 1 excluded)
- **Runs per subject-task-session**: Expected 5 runs
- **Trials per run**: Median should be 28-30 (target range)
- **Total trials per subject-task-session**: Expected 150 (5 runs × 30 trials)

## File Descriptions

1. **01_file_provenance.csv** - List of flat files processed with metadata
2. **02_design_expected_vs_observed.csv** - Expected vs observed runs/trials per subject×task×session
3. **03_trials_per_subject_task_ses.csv** - Trial counts and segmentation source breakdown
4. **04_run_level_counts.csv** - Per-run statistics (n_trials must be ~30, not 60)
5. **05_window_validity_summary.csv** - Window validity distributions by task
6. **06_gate_pass_rates_by_threshold.csv** - Pass rates for baseline and overall gates at multiple thresholds
7. **07_bias_checks_key_gates.csv** - Selection bias diagnostics by effort/oddball (if behavioral data available)
8. **08_prestim_dip_summary.csv** - Prestim dip diagnostics (simplified)

## Known Limitations

- **Window validity**: Computed from `trial_label` matching "Baseline" or "ITI_Baseline". Falls back to `baseline_quality` column if labels not available.
- **Prestim dip**: Currently simplified (would require sample-level computation for full implementation)
- **Behavioral merge**: Only available if `behavioral_csv` is configured in `config/data_paths.yaml`

## Validation

After running this script, verify:
- Median n_trials per run is 28-30
- No runs show exactly 60 trials (indicates double-counting bug)
- All 8 CSVs are present in output directory

