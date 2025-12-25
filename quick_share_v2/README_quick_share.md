# Quick-Share QC Snapshot

Generated: 2025-12-22 15:29:51
Git hash: 24ef945

## Summary Totals

- **Total subjects**: 63
- **Total sessions**: 116
- **Total runs**: 488 (verified against 04_run_level_counts.csv)
- **Total trials**: 14586 (verified against 04_run_level_counts.csv)

## Trial Identity

**Trial Key**: `(sub, task, session_used, run_used, trial_index)`

**CRITICAL**: All trial counts use `n_distinct(trial_index)` within each (sub, task, session_used, run_used) to avoid double-counting.
`trial_label` is used ONLY as a phase annotation, never as part of trial identity.

## Windows

- **Baseline window**: -0.5 to 0 seconds (relative to squeeze onset)
- **Cognitive window**: 0.3 to 1.3 seconds (relative to squeeze onset)
- **Global window**: -0.5 to 5 seconds (for AUC computation)

## Timebase Validation

Trials with `timebase_flag == 1` are excluded from window validity and feature computation.
Timebase is considered valid if t_rel range is 10-30 seconds and t_rel_min < 0.

## Gates

Primary gate at threshold t requires:
- baseline_valid >= t
- cog_valid >= t
- timebase_flag == 0
- all_nan == 0
- window_oob == 0

## File Descriptions

1. **01_file_provenance.csv** - Input files processed
2. **02_design_expected_vs_observed.csv** - Design compliance (expected vs observed runs/trials)
3. **03_trials_per_subject_task_ses.csv** - Trial counts and gate pass counts (TRUE trial counts, no double-counting)
4. **04_run_level_counts.csv** - Run-level statistics (n_trials = distinct trial_index per run)
5. **05_window_validity_summary.csv** - Window validity distributions
6. **06_gate_pass_rates_by_threshold.csv** - Gate pass rates (counts distinct trials)
7. **07_bias_checks_key_gates.csv** - Logistic regression coefficients for selection bias
8. **08_prestim_dip_summary.csv** - Prestim dip diagnostics

## Validation

All trial counts have been verified:
- No double-counting: n_trials_with_behavioral <= observed_trials for all subjects
- Run trial counts: all runs have n_trials in [20, 35] range (typically ~30)
- No session 1 contamination: all trials have session_used in {2, 3}

