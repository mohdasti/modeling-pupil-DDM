# Chapter 3 qmd phase 1 report

## 1. Branch and commits

Branch `ch3-qmd-revision`, created from `ch3-r8-finalize` at `7c00aa5`. Not pushed.

| Commit | Message |
|---|---|
| `8f14fe9` | qmd phase1: inventory, citekeys, comment log |
| `ac42636` | qmd phase1: new qmd + YAML + tiers |
| `33ef9a1` | qmd phase1: helpers + tests |
| `1e9c346` | qmd phase1: section skeleton |
| `ff4c006` | qmd phase1: table and figure chunks |
| (this commit) | qmd phase1: render + audits |

Part 7 has no commit of its own. The July-chunk list is in section 6.

## 2. Render status, both tiers

Quarto 1.9.38. Both renders exited 0 with no warnings.

| Tier | Command flag | Output | Embedded figures | S7–S12 |
|---|---|---|---|---|
| Manuscript | default `dissertation: false` | `reports/chap3_revised.docx` | 9 | absent |
| Dissertation | `-M dissertation:true` | `reports/chap3_revised_dissertation.docx` | 15 | present |

`when-meta="dissertation"` is honored on this Quarto. The heading text in both files matches the Part 4 tree, including 2.7.1–2.7.3. Main cross-references resolve (Figure 1–5, Table 1–3, Figure S, Table S).

## 3. Unit tests

`tests/test_report_helpers.R` with testthat: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 74 ]`.

## 4. Comment log

`reports/ch3_comment_resolution_log.csv` has 79 rows (Word ids 0–78), from `/Users/mohdasti/Downloads/chap3_July1st.docx`.

78 comments are mapped, each in exactly one placeholder. 1 is unmapped:

| ID | Author | Anchor | Comment | July section |
|---|---|---|---|---|
| C51 | Ilana Bennett | Behavioral validation checks. | stated earlier; not necessary to run/report | 2.7.2 Model specification: standard-only calibration and primary model |

## 5. Figures and tables placed

| Tier | Figures | Tables |
|---|---:|---:|
| Main text | 5 | 3 |
| Manuscript supplement (always rendered) | 4 | 11 |
| Dissertation supplement only | 6 | 5 |
| **Total** | **15** | **19** |

S12 is a placeholder only. Every placed label is named in its section placeholder.

## 6. July chunks not carried over

79 July labels. 4 display labels are reused (`tbl-demographics`, `supptbl-trial-counts`, `suppfig-caf`, `supptbl-rt-lmm`). The bibliography div `refs` is kept. 74 labels are not carried over: 30 cut, 27 replaced, 17 superseded.

| July label | Line | Reason | Note |
|---|---:|---|---|
| `setup` | 64 | cut | July render plumbing, not a result display |
| `fig-ddm-process` | 1086 | replaced by fig-design | design schematic |
| `methods-demographics-inline` | 1112 | superseded | sample counts now come from inline_values.rds |
| `ddm-sample-counts-early` | 1153 | superseded | sample counts now come from inline_values.rds |
| `tbl-trial-exclusions` | 1507 | cut | no exclusion table in the placement list; processing is prose in section 2.5 |
| `setup_ddm_results_run` | 1621 | cut | July render plumbing, not a result display |
| `crossref_audit` | 1632 | cut | July render plumbing, not a result display |
| `pre_render_checks` | 1847 | cut | July render plumbing, not a result display |
| `ddm-paths-and-imports` | 1980 | cut | July render plumbing that read superseded run paths |
| `h-evidence-setup` | 2465 | cut | old H1-H4 hypothesis tables |
| `null-evidence-helpers` | 2886 | cut | old H1-H4 hypothesis tables |
| `trial-counts-inline` | 3588 | superseded | trial counts now come from inline_values.rds and T12a |
| `ddm-params-inline` | 3931 | superseded | parameter summaries now come from inline_values.rds |
| `fig-central-result` | 3996 | replaced by fig-condition-params | condition-parameter figure |
| `fig-parameter-forest` | 4046 | replaced by fig-effort-forest | effort forest |
| `pupil-quality-inline` | 4056 | superseded | pupil gate counts now come from inline_values.rds |
| `tbl-hyp-summary` | 4109 | cut | old H1-H4 hypothesis table |
| `drift-standard-compute` | 4254 | cut | standard-only bias calibration |
| `fig-individual-diffs` | 4303 | cut | subject-level effort panels dropped; Brinley is the new fig-brinley |
| `pupil-evidence-setup` | 4320 | superseded | r5/r6 pupil output |
| `pupil-interaction-stats` | 4333 | superseded | r5/r6 pupil output |
| `null-evidence-pupil-apply` | 4425 | superseded | r5/r6 pupil output |
| `fig-difficulty-posterior-diffs` | 4565 | cut | difficulty-posterior-differences figure |
| `bias-inline-compute` | 4686 | cut | standard-only bias calibration |
| `supptbl-loo-comparison` | 4740 | replaced by supptbl-model-comparison | model comparison table |
| `supptbl-convergence-detailed` | 4761 | replaced by supptbl-convergence | convergence table |
| `suppfig-ndt-prior-posterior` | 4794 | replaced by suppfig-ndt | non-decision time prior figure |
| `suppfig-loo-comparison` | 4838 | cut | old LOO-comparison figure |
| `suppfig-participant-flow` | 4890 | replaced by suppfig-flow | participant flow figure |
| `supptbl-ddm-posterior-estimates` | 4994 | replaced by supptbl-fixef-m4 and supptbl-condition-cells | fixed effects and condition cells |
| `supptbl-standard-only-bias-levels` | 5033 | cut | standard-only bias calibration |
| `suppfig-a2-bias-calibration-panel` | 5066 | cut | standard-only bias calibration |
| `supptbl-baseline-pupil` | 5159 | superseded | r5/r6 pupil output; descriptives replaced by supptbl-pupil-descriptives |
| `supptbl-bias-drift-intercept` | 5279 | cut | standard-only bias calibration |
| `supptbl-convergence-ppc-gate-appendix` | 5332 | replaced by supptbl-convergence and supptbl-ppc-choice | convergence and choice PPC |
| `supptbl-ppc-midbody` | 5532 | replaced by supptbl-ppc-choice | choice posterior predictive check |
| `suppfig-ppc-heatmaps` | 5576 | replaced by suppfig-ppc | posterior predictive check figure |
| `supptbl-sensitivity-subchance` | 5599 | replaced by supptbl-robustness | robustness effort terms |
| `supptbl-sensitivity-thresholds` | 5860 | replaced by supptbl-robustness | robustness effort terms |
| `supptbl-h1-h2-by-cutoff` | 5898 | cut | old H1-H4 hypothesis table |
| `supptbl-app-sensitivity-full` | 5927 | replaced by supptbl-robustness | robustness effort terms |
| `suppfig-a4-2a-drift-by-difficulty` | 5954 | cut | cutoff drift-by-difficulty figure |
| `suppfig-suppl-drift-by-task` | 6003 | cut | task-modality sensitivity profiles |
| `suppfig-additivity-check` | 6084 | cut | additivity check |
| `supptbl-task-sensitivity` | 6179 | cut | task-sensitivity table |
| `pdf-sanity-check` | 6222 | cut | July render plumbing, not a result display |
| `supptbl-pupil-loo-unified` | 6294 | superseded | r5/r6 pupil output; replaced by supptbl-pupil-models |
| `supptbl-pupil-key-effects-appendix` | 6390 | superseded | r5/r6 pupil output |
| `supptbl-pupil-boundary-appendix` | 6486 | superseded | r5/r6 pupil output; replaced by tbl-pupil-ordering |
| `supptbl-tepr` | 6568 | superseded | r5/r6 pupil output; replaced by supptbl-pupil-descriptives |
| `suppfig-tepr-timecourse-supp` | 6646 | replaced by suppfig-tepr | TEPR time course |
| `suppfig-tepr-slopes-supp` | 6858 | cut | TEPR x difficulty slopes |
| `suppfig-timing-supp` | 6979 | replaced by fig-design | design and timing schematic |
| `suppfig-rt-distributions` | 6992 | replaced by suppfig-rtdist | RT distributions |
| `suppfig-ddm-dag-plate` | 7074 | replaced by suppfig-dag | model DAG |
| `mc-sample-size` | 7137 | cut | July render plumbing, not a result display |
| `supptbl-accuracy-glmm` | 7231 | replaced by supptbl-acc-glmm | accuracy mixed model |
| `suppfig-accuracy-distribution` | 7315 | replaced by suppfig-accuracy | accuracy by condition |
| `overall-accuracy-compute` | 7444 | cut | July render plumbing, not a result display |
| `supptbl-overall-accuracy` | 7483 | cut | not in the revised table list; accuracy display is suppfig-accuracy and supptbl-acc-glmm |
| `rt-medians-compute` | 7581 | cut | July render plumbing, not a result display |
| `suppfig-rt-distribution` | 7698 | replaced by suppfig-rtdist | RT distributions |
| `lc-a8-setup` | 7803 | cut | July render plumbing, not a result display |
| `supptbl-lc-exploratory-correlations` | 7836 | replaced by supptbl-lc | LC correlates |
| `suppfig-lc-fiso-dprime-variability` | 7880 | replaced by suppfig-lc-variability | LC variability figure |
| `suppfig-lc-fiso-four-panel` | 7896 | replaced by suppfig-lc-four-panel | LC four-panel figure |
| `np-a9-setup` | 7915 | cut | July render plumbing, not a result display |
| `supptbl-extended-baseline-categorical` | 7942 | replaced by supptbl-neuropsych | baseline rows of T14 |
| `supptbl-extended-baseline` | 7967 | replaced by supptbl-neuropsych | baseline rows of T14 |
| `supptbl-neuropsych-ddm-exploratory` | 7989 | replaced by supptbl-neuropsych | neuropsych rows of T14 |
| `choice-history-load` | 8062 | superseded | pre-revision temporal structure; replaced by supptbl-temporal |
| `fatigue-trajectory-load` | 8098 | superseded | pre-revision temporal structure; replaced by supptbl-temporal |
| `fatigue-build-figure` | 8124 | superseded | pre-revision temporal structure; replaced by supptbl-temporal |
| `suppfig-temporal-dynamics` | 8286 | superseded | pre-revision temporal figure; replaced by supptbl-temporal |

## 7. Key audit

`.keys_used` after the manuscript render, overwritten by the dissertation render with the same calls. Seven calls, all present in `inline_keys.csv`:

`tepr_window_start`, `tepr_window_end`, `tepr_baseline_start`, `tepr_baseline_end`, `rope_v`, `rope_a`, `rope_z`.

These are the design constants `v()` reads when the helpers load. Missing keys: none.

Keys available but unused: 113. Prose has not called `v()` yet, so every key that is not a design constant is unused. Full list: P0_bias, P0_bs, P0_crit, P0_qual, P1_bias, P2_drift_tepr, P2_drift_tepr_x_stim, P3_bs, P3_rt_bs, P4_bias_base, P5_bs, P6_bs, P7_bs, P8_bs, acc_high_low_Easy, acc_high_low_Hard, acc_high_low_Standard, adapt_delta, bias, bs, bs_pct_change, crit, crit_ADT_M4b, crit_M4r, crit_VDT_M4b, crit_subchance, crit_thr015, crit_thr025, delta_elpd_M0_vs_M1, delta_elpd_M3_vs_M4, delta_elpd_M4b_vs_M4, delta_elpd_P1_vs_P0, delta_elpd_P2_vs_P0, delta_elpd_P3_vs_P0, delta_elpd_P3rt_vs_P0rt, delta_elpd_P4_vs_P0base, delta_elpd_P5_vs_P0base, delta_elpd_P6_vs_P0lag, delta_elpd_P7_vs_P0pre, delta_elpd_P8_vs_P0grip, drift_diff_trials, drift_same_trials, grip_high_low_ADT, grip_high_low_VDT, m4b_effort_x_task, m4b_quality_x_task, max_k_pupil_models, max_rhat_M4, max_treedepth, min_bulk_ess_M4, min_tail_ess_M4, n_adt, n_chains, n_enrolled, n_excluded, n_final, n_iter, n_pupil_b1_quality_subjects, n_pupil_b1_quality_trials, n_pupil_base_trials, n_pupil_entered_vs_r5, n_pupil_final_subjects, n_pupil_final_trials, n_pupil_grip_trials, n_pupil_lag_trials, n_pupil_left_vs_r5, n_pupil_matched_subjects, n_pupil_matched_trials, n_pupil_models_k_gt_0.7, n_pupil_pre_trials, n_pupil_rt80_trials, n_pupil_tepr_present_subjects, n_pupil_tepr_present_trials, n_pupil_window_quality_subjects, n_pupil_window_quality_trials, n_subchance_excluded, n_subchance_remaining, n_trials_cutoff_excluded, n_trials_primary, n_trials_thr015, n_trials_thr025, n_vdt, n_warmup, pct_gain_lost_rt_trim, ppc_choice_inside_M4, ppc_rt_inside_pct_M4, ppc_rt_median_bias_ms_M4, qual, qual_M4r, qual_subchance, qual_thr015, qual_thr025, sd_bs_effort_M4r, sd_effort_M4r, se_delta_elpd_M0_vs_M1, se_delta_elpd_M3_vs_M4, se_delta_elpd_M4b_vs_M4, seed, t0_M4, t0_thr015, t0_thr025, task_bias, task_bs, task_easy_x_vdt, task_hard_x_vdt, task_v, tepr_baseline_pre_probe, tepr_high_low_ADT_B0, tepr_high_low_ADT_B1, tepr_high_low_VDT_B0, tepr_high_low_VDT_B1, tepr_rt_r, tepr_window_post_probe.

`inline_keys.csv` has 121 rows and 120 unique names. `n_pupil_matched_trials` is stored twice, both values 12630. `v()` returns the first.

## 8. Hard-coded audit

`hardcoded_audit.csv` has no row classified `result`.

| Classification | Count | What it is |
|---|---:|---|
| heading | 38 | Section numbers in headings |
| format | 10 | YAML only: CSL name, run-directory date, toc depth, 1 in margin, 11 pt, 1.5 line spacing, 300 dpi |
| identifier | 4 | `params$pupil_run` (`r8_20261017_015218`) and the r10 note on that line |
| crossref | 2 | The digit in `supptbl-fixef-m4` and `supptbl-m4b` |
| result | 0 | |

## 9. Page counts

Word's AppleEvent timed out (`-1712`) before it returned a paginated count. The counts below are a layout estimate from the docx itself: letter, 1 inch margins, 12 pt body, single spacing, image heights taken from the embedded drawings. The table of contents is an unexpanded field and is not included. Placeholders count as about 0 pages of prose toward Lani's Methods limit.

### Manuscript (`chap3_revised.docx`)

| Section | Estimated pages |
|---|---:|
| Front matter (title, author, unexpanded table-of-contents field) | 0.2 |
| Abstract | 0.2 |
| 1 Introduction | 0.2 |
| 2 Methods | 3.2 |
| 3 Results | 4.4 |
| 4 Discussion | 0.4 |
| References | 0.1 |
| Supplementary Materials | 16.2 |
| **Total** | **24.8** |

### Dissertation (`chap3_revised_dissertation.docx`)

| Section | Estimated pages |
|---|---:|
| Front matter (title, author, unexpanded table-of-contents field) | 0.2 |
| Abstract | 0.2 |
| 1 Introduction | 0.2 |
| 2 Methods | 3.2 |
| 3 Results | 4.4 |
| 4 Discussion | 0.4 |
| References | 0.1 |
| Supplementary Materials | 27.7 |
| **Total** | **36.2** |

Methods renders at about 3.2 pages because the callouts, the demographics table, and the design figure are in the file. The Methods prose is about 0 pages. The only non-placeholder Methods objects are Table 1 and Figure 1, together about 1 page, inside the 6–8 page limit.

## 10. Undetermined items and disagreements

Switching r8 → r10 requires only replacing inline_values.rds pupil keys and T7/T8/T9/F5/S_tepr/S_flow files; no qmd edit.

The pupil-key contract is `pupil_key_contract.csv` (56 keys, with fields). It is the pupil keys named in the placeholders, including the TEPR window bounds the helpers already read.

Undetermined or recorded disagreements:

- Lani's commented draft was not in the repo or in `reports/`. The log was parsed from `/Users/mohdasti/Downloads/chap3_July1st.docx`.
- C4 is named on both the Abstract line (C0–C6) and the Introduction line. It is placed only in the Introduction. The Abstract placeholder lists C0, C1, C2, C3, C5, C6.
- C51 does not fit a revised section. The explicit 2.7 range stops at C50, and the comment says the check was already stated and need not be reported.
- `number-sections: true` is unchanged. Every heading also has `{.unnumbered}`, so the rendered heading text is the Part 4 tree rather than a double number.
- A table caption that starts with `[` is parsed as a JSON subcaption and the render stops. Main-text table captions therefore start with a zero-width space. Supplement captions are a paragraph inside the fenced div, which is how the July chapter registers `suppfig` and `supptbl`. A chunk option `#| label: suppfig-*` did not register.
- `T11a_ppc_choice.csv` also contains P3 rows. The display keeps `model == "M4"` because the decision record treats the P3 choice check as superseded.
- `T10_convergence_all.csv` includes `P0_r6`, a duplicate of the r5 P0. That row is dropped. The other T10 rows are shown.
- July S9's extended baseline is the neuropsych and neuropsych-baseline rows of `T14_lc_neuropsych_ddm.csv`. There is no separate extended-baseline file in `tables/final/`.
- `report_effect()` adds the percent change only on the log scale. The logit scale uses the drift-scale sentence.
- The July YAML has no `reference-doc`. None was added.
- flextable is not installed. Tables use `knitr::kable` in pipe format, which is what renders in docx. The July chapter used kableExtra for HTML.
- Page counts are the layout estimate in section 9, not a Word pagination.
