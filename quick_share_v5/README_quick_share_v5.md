# Quick-Share v5

 This folder contains analysis-ready trial-level datasets and QC tables
 built from quick_share_v4/merged/BAP_triallevel_merged_v2.csv.

 Key files:

 - analysis/ch2_analysis_ready.csv
 - analysis/ch3_ddm_ready.csv
 - qc/01_join_health_by_subject_task.csv
 - qc/02_missing_behavioral_sample_keys.csv
 - qc/03_timing_target_onset_qc.csv (if target_onset_found exists)
 - qc/04_gate_pass_rates_by_task_threshold.csv
 - qc/05_bias_missingness_logit_inputs.csv

 For now, v5 focuses on join health, timing QC summaries, and
 analysis-ready Ch2/Ch3 tables using existing QC metrics.
