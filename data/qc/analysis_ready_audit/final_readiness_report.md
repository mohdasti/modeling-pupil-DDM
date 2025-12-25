# BAP Pupillometry Pipeline - Final Readiness Report

Generated: 2025-12-21 21:16:05

## Contamination Checks

- **Session 1/Practice contamination**: **PASS** - No contamination
- **Alignment failures**: 0 runs failed falsification checks

## Final Dataset Statistics

- **N subjects**: 61
- **N trials (total)**: 12715
- **N trials by task**:
  - ADT: 6404
  - VDT: 6311

## Gate Retention

- **ch2_primary** (baseline≥0.60 & cog≥0.60): 116 trials
- **ch2_sens_050** (baseline≥0.50 & cog≥0.50): 128 trials
- **ch2_sens_070** (baseline≥0.70 & cog≥0.70): 101 trials
- **ch3_ddm_ready** (RT filter + minimal pupil): 128 trials

## Final Outputs

- **Trial-level dataset (CSV)**: `data/analysis_ready/BAP_TRIALLEVEL.csv`
- **Trial-level dataset (Parquet)**: `data/analysis_ready/BAP_TRIALLEVEL.parquet`
- **DDM-ready dataset (CSV)**: `data/analysis_ready/BAP_TRIALLEVEL_DDM_READY.csv`

## Merge Match Rates

See: `data/qc/merge_audit/match_rate_by_subject_task_session_run.csv`

## Falsification Results

See: `data/qc/merge_audit/rt_plausibility_by_run.csv`
See: `data/qc/merge_audit/intensity_integrity_by_run.csv`

## Overall Status

**PASS** - All checks passed. Datasets ready for analysis.

