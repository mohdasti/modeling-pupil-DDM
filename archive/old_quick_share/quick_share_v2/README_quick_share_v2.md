# Quick-Share v2 QC Snapshot

Generated: 2025-12-22 15:49:52
Git hash: 24ef945

## Summary Totals

- **Total subjects**: 63
- **Total trials**: 14586
- **Total runs**: 488

## Trial Identity

**Trial Key**: `(sub, task, ses_key, run_key, trial_index)`

- `ses_key` = `session_used` if available, else `ses`
- `run_key` = `run_used` if available, else `run`
- `trial_index` is the true trial ID within run (NOT `trial_in_run_raw`)

**CRITICAL**: All trial counts use `n_distinct(trial_index)` within each (sub, task, ses_key, run_key).
Never count samples as trials.

## Windows (Relative to Squeeze Onset at t=0)

- **Baseline window**: -0.5 to 0 seconds
- **Total AUC window**: 0 to 5.65 seconds
- **Cognitive window**: 4.65 to 5.65 seconds (post-target)

**Time computation**: `t_rel = -3 + (sample_i - 1) * dt` where `dt = 13.7 / (n_samples - 1)`
(Window spans [-3, +10.7] = 13.7s total)

## Gates

Gate pass at threshold t requires:
- `pct_non_nan_baseline >= t`
- `pct_non_nan_cog >= t`
- `pct_non_nan_total >= t`

Thresholds: 50, 60, 70 (percentages)

## File Descriptions

1. **01_file_provenance.csv** - Input files processed, sizes, git hash
2. **02_design_expected_vs_observed.csv** - Design compliance (expected vs observed runs/trials)
3. **03_trials_per_subject_task_ses.csv** - Trial counts and gate pass counts per subject/task/session
4. **04_run_level_counts.csv** - Run-level statistics (n_trials, pass counts, validity)
5. **05_window_validity_summary.csv** - Window validity distributions (mean/median/percentiles)
6. **06_gate_pass_rates_by_threshold.csv** - Gate pass rates by task and threshold
7. **07_bias_checks_key_gates.csv** - Logistic regression coefficients for selection bias (or 'behavior not merged')
8. **08_prestim_dip_summary.csv** - Prestim/baseline failure diagnostics

