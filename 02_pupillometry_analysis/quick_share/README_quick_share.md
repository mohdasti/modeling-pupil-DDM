# Quick-Share QC Snapshot

Generated: 2025-12-22 12:24:33

## Purpose

This export provides a compact QC snapshot to assess data readiness for:
- **Chapter 2**: Psychometric + pupil coupling analyses
- **Chapter 3**: DDM (Drift Diffusion Model) analyses

## Filters Applied

- **Sessions**: 2-3 only (session 1 / practice / OutsideScanner excluded)
- **Runs**: 1-5 only
- **Tasks**: ADT and VDT
- **Trial exclusions**: window_oob==1 or all_nan==1

## Top-Line Counts

- **N subjects**: 63
- **N trials (total)**: 27882
- **N trials (pupil-present)**: 27050
- **N trials (CH2 primary ready @ 0.60)**: 0
- **N trials (CH3 pupil+behavior ready @ 0.50)**: 0

## Window Validity Source

- **Source**: R proxies (computed from t_rel windows)
- **Baseline window**: first 0.5s of t_rel (relative time within trial)
- **Cognitive window**: t_rel [0.3, 1.3] seconds
- **Prestim window**: t_rel [-1.0, 0] seconds (if available)

## Files Generated

1. **01_file_provenance.csv** - Input paths, git hash, timestamps, file counts
2. **02_design_expected_vs_observed.csv** - Expected vs observed runs/trials per subject×task×session
3. **03_trials_per_subject_task_ses.csv** - Trial counts and gate counts by subject×task×session
4. **04_run_level_counts.csv** - Run-level statistics (n_trials, dt_median, max_gap, time_range, window_oob/all_nan fractions)
5. **05_window_validity_summary.csv** - Window validity distributions by task
6. **06_gate_pass_rates_by_threshold.csv** - CH2/CH3 gate pass rates at thresholds {0.50, 0.60, 0.70}
7. **07_bias_checks_key_gates.csv** - Gate bias by effort/intensity/RT quartile (if behavioral data available) or by task/session/run
8. **08_prestim_dip_summary.csv** - Prestim window depth/status by task

## Data Readiness Verdict

### Chapter 2 (Pupil Coupling)
- **Primary gate**: baseline_valid >= 0.60 AND cognitive_valid >= 0.60
- **Retention rate**: 0.0% of pupil-present trials pass
- **Decision**: See `03_trials_per_subject_task_ses.csv` for per-subject counts

### Chapter 3 (DDM)
- **Gate**: behavior-ready (RT 0.2-3.0s) AND baseline_valid >= 0.50 AND cognitive_valid >= 0.50
- **Retention rate**: 0.0% of pupil-present trials pass
- **Decision**: See `03_trials_per_subject_task_ses.csv` for per-subject counts

## Key Identifiers

- **subject_id**: from `sub` column
- **session**: from `session_used` (NOT `ses`, NOT `session_from_filename`)
- **run**: from `run_used` (NOT `run`, NOT `run_from_filename`)
- **trial_in_run**: from `trial_index` (primary), `trial_in_run_raw` (diagnostic)
- **trial_key**: paste(subject_id, task, session, run, trial_in_run, sep=":")

## Notes

- Per-trial relative time (`t_rel`) computed as `time - min(time)` within each trial
- Median time step expected ~0.004 seconds (250 Hz)
- All window validity computed from `t_rel`, not from `trial_start_time_ptb` (treated as metadata)

