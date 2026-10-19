# Phase 1d

Pupil results now come from `r10_20261017_081458` (4,935 trials, 43 participants). All 15 models pass the convergence rule, including tail ESS. The accuracy and median-RT models use a random intercept. The Standard high-effort accuracy coefficient is unchanged at 0.204, p = .068.

r11 was not started. The laptop cannot reach the VM, and this commit has not been synced there.

## 1. Part A

The r10 run id is `r10_20261017_081458`. The log line is `Full QC 4935 with base_c 4488 missing base_c 447`.

A misrouted r9 job had pointed `r8_latest_run_id.txt` at `r8_20261017_060429`. On the VM, `scripts/r10/a3_tail_ess.R` restored it to `r8_20261017_015218` at 2026-10-19 04:50:50 and wrote `output/ddm_refits/runs/MANIFEST.csv`.

| run_id | status | note |
| --- | --- | --- |
| r8_20261017_015218 | superseded_gate_clock | Original r8 pupil run |
| r8_20261017_060429 | abandoned_r9_misrouted | r9 runner fell back to the r8 input; duplicate of r8; do not use |
| r10_20261017_081458 | final_pupil | 4,935-trial pupil sample. Fit, extract, and tail ESS finished |

Nothing was deleted. Tail ESS below is the value printed on the VM. R-hat and bulk ESS are the full-precision values in `convergence.csv`, which match that print. Every model used adapt_delta 0.95 and had 0 divergences.

| model | n | max R-hat | min bulk ESS | min tail ESS | pass |
| --- | ---: | ---: | ---: | ---: | --- |
| P0 | 4935 | 1.006004 | 1394.457 | 2609.826 | yes |
| P1 | 4935 | 1.004939 | 1413.651 | 2404.898 | yes |
| P2 | 4935 | 1.007432 | 1248.058 | 2264.492 | yes |
| P3 | 4935 | 1.005587 | 1177.325 | 2475.774 | yes |
| P0_base | 4488 | 1.008676 | 1550.085 | 2831.084 | yes |
| P4 | 4488 | 1.005246 | 1601.814 | 2943.145 | yes |
| P5 | 4488 | 1.006917 | 1560.950 | 3063.620 | yes |
| P0_rt | 3973 | 1.004606 | 1775.767 | 3651.568 | yes |
| P3_rt | 3973 | 1.006422 | 1798.962 | 3222.511 | yes |
| P0_lag | 3842 | 1.005215 | 1215.826 | 2231.456 | yes |
| P6 | 3842 | 1.003613 | 1340.803 | 2780.349 | yes |
| P0_pre | 3799 | 1.006435 | 1537.268 | 3114.655 | yes |
| P7 | 3799 | 1.005856 | 1355.476 | 2750.402 | yes |
| P0_grip | 4209 | 1.004775 | 1683.255 | 3104.713 | yes |
| P8 | 4209 | 1.004068 | 1639.033 | 3275.657 | yes |

Worst R-hat is P0_base, 1.0087. Smallest bulk ESS is P3, 1,177. Smallest tail ESS is P0_lag, 2,231. No model is near the threshold (R-hat < 1.01, bulk and tail ESS ≥ 400, 0 divergences).

## 2. Pupil slopes, r8 versus r10

Medians are the posterior median. The interval is the 95% CrI. Percent is the posterior median percent change in boundary separation. ELPD is the LOO difference from the matched baseline, ± its SE.

| model | term | r8 median [95% CrI] | r8 % | r8 ΔELPD | r8 n | r10 median [95% CrI] | r10 % | r10 ΔELPD | r10 n |
| --- | --- | --- | --- | ---: | --- | --- | ---: | --- | --- |
| P1 | starting point | 0.0020 [−0.0301, 0.0346] |  | −0.92 ± 0.19 | 4952/42 | 0.0083 [−0.0235, 0.0410] |  | −0.19 ± 0.45 | 4935/43 |
| P2 | drift | 0.0504 [0.0107, 0.0883] |  | 8.69 ± 5.29 | 4952/42 | 0.0487 [0.0099, 0.0879] |  | 8.80 ± 5.14 | 4935/43 |
| P2 | drift × stimulus | −0.0914 [−0.1301, −0.0528] |  | same model | 4952/42 | −0.0891 [−0.1275, −0.0503] |  | same model | 4935/43 |
| P3 | boundary | 0.0741 [0.0611, 0.0868] | 7.69 | 64.59 ± 8.99 | 4952/42 | 0.0759 [0.0629, 0.0884] | 7.88 | 67.95 ± 9.15 | 4935/43 |
| P4 | baseline on starting point | −0.0130 [−0.0447, 0.0191] |  | −0.38 ± 0.63 | 4612/42 | −0.0097 [−0.0430, 0.0232] |  | −0.58 ± 0.50 | 4488/43 |
| P5 | baseline on boundary | 0.0177 [0.0049, 0.0309] | 1.79 | 2.21 ± 2.18 | 4612/42 | 0.0151 [0.0015, 0.0286] | 1.52 | 1.72 ± 1.78 | 4488/43 |
| P3_rt | boundary, RT trim | 0.0467 [0.0313, 0.0625] | 4.78 | 16.24 ± 4.56 | 3986/42 | 0.0485 [0.0327, 0.0644] | 4.97 | 17.58 ± 4.72 | 3973/43 |
| P6 | previous-trial TEPR | 0.0270 [0.0119, 0.0418] | 2.73 | 5.32 ± 2.65 | 3823/42 | 0.0280 [0.0133, 0.0426] | 2.84 | 6.83 ± 2.71 | 3842/43 |
| P7 | pre-response | 0.0129 [−0.0018, 0.0274] | 1.30 | −0.04 ± 1.66 | 3678/42 | 0.0122 [−0.0021, 0.0266] | 1.23 | 0.19 ± 1.68 | 3799/43 |
| P8 | grip period | −0.0175 [−0.0308, −0.0042] | −1.73 | 2.62 ± 2.06 | 4444/42 | −0.0172 [−0.0310, −0.0036] | −1.71 | 2.35 ± 2.01 | 4209/42 |

P0 effort terms on the pupil sample:

| term | r8 median [95% CrI] | r10 median [95% CrI] |
| --- | --- | --- |
| Drift criterion | −0.0708 [−0.1658, 0.0254] | −0.0481 [−0.1418, 0.0452] |
| Evidence quality | 0.0512 [−0.0290, 0.1289] | 0.0255 [−0.0502, 0.1010] |
| Boundary separation | 0.0388 [0.0113, 0.0661], +3.95% | 0.0296 [0.0028, 0.0563], +3.01% |
| Starting point | −0.0198 [−0.1043, 0.0625] | −0.0187 [−0.1014, 0.0640] |

The RT-trim comparison keeps 100 × (1 − ΔELPD_P3rt / ΔELPD_P3) = 74.1% of the P3 ELPD gain. After moment matching, 0 of 15 models have a Pareto k above 0.7.

## 3. Pupil descriptives, r8 versus r10

High minus low. The correlation is the Fisher-z mean within participant, with a 95% CI.

| measure | r8 | r10 |
| --- | --- | --- |
| TEPR, B1, ADT | −0.791, t(29) = −2.12, p = .042, n = 30 | −0.723, t(30) = −2.35, p = .026, n = 31 |
| TEPR, B1, VDT | −0.454, t(29) = −2.74, p = .011, n = 30 | −0.432, t(29) = −2.40, p = .023, n = 30 |
| TEPR, B0, ADT | 0.659, t(29) = 1.50, p = .145, n = 30 | 1.003, t(30) = 2.45, p = .020, n = 31 |
| TEPR, B0, VDT | −0.061, t(29) = −0.16, p = .874, n = 30 | 0.028, t(29) = 0.10, p = .919, n = 30 |
| Grip, ADT | 0.513, t(28) = 2.72, p = .011, n = 29 | 0.593, t(27) = 3.37, p = .002, n = 28 |
| Grip, VDT | 0.206, t(28) = 2.04, p = .051, n = 29 | 0.212, t(28) = 2.08, p = .047, n = 29 |
| r(TEPR, RT) | 0.292 [0.227, 0.354], 42 participants | 0.297 [0.229, 0.362], 43 participants |

## 4. Gate counts

Recomputed from `output/diagnostics/r9_precheck/trial_window_quality.csv`. The r10 sequence ends at 4,935 trials and 43 participants.

| step | r8 trials / participants | r10 trials / participants |
| --- | --- | --- |
| Matched to a recording | 12,630 / 61 | 12,630 / 61 |
| TEPR present | 9,405 / 60 | 7,806 / 54 |
| Baseline quality ≥ 0.50 | 5,888 / 52 | 5,895 / 52 |
| Decision-window quality ≥ 0.50 | 5,107 / 52 | 5,077 / 49 |
| At least 20 trials per participant and task | 4,952 / 42 | 4,935 / 43 |

r8 called the window step `cog_quality_ge_0.50`. r10 uses the 4.65–7.65 s AUC window (`auc_window_ge_0.50`).

Trials in r10 that were not in r8: 432. Trials in r8 that are not in r10: 449. Those replace `n_pupil_entered_vs_r5` and `n_pupil_left_vs_r5`, and they are the S12 keys.

Subset sizes used by the ordering models: baseline 4,488, RT trim 3,973, previous trial 3,842, pre-response 3,799, grip 4,209.

## 5. Accuracy and median RT

Both maximal models and both uncorrelated-slope models were singular in phase 1c, so the random-intercept model is the one used. The accuracy intercept-only refit matches the stored T13b row: estimate 0.2039297469824211, p = 0.06796581183118545.

Reduction log (`T13a_reduction_log.csv`):

| outcome | step | random effects | singular | slope SD | intercept SD | correlation | used |
| --- | --- | --- | --- | ---: | ---: | ---: | --- |
| accuracy | maximal | (1 + effort_condition \| subject_id) | yes | 0 | 0.717 | −0.031 | no |
| accuracy | no correlation | (1 \| subject_id) + (0 + effort_c \| subject_id) | yes | 0 | 0.701 |  | no |
| accuracy | intercepts | (1 \| subject_id) | no |  | 0.701 |  | yes |
| RT | maximal | (1 + effort_condition \| subject_id) | yes | 0.011 | 0.251 | 1.000 | no |
| RT | no correlation | (1 \| subject_id) + (0 + effort_c \| subject_id) | yes | 0 | 0.256 |  | no |
| RT | intercepts | (1 \| subject_id) | no |  | 0.256 |  | yes |

Accuracy, high minus low (`T13d`). Percentage points are 100 times the probability difference. The odds ratio, z, and p are the logit-scale contrast. Task is averaged with equal weights. df is asymptotic.

| difficulty | pp | 95% CI | OR | 95% CI | z | p |
| --- | ---: | --- | ---: | --- | ---: | ---: |
| Standard | 1.69 | [−0.14, 3.52] | 1.23 | [0.99, 1.53] | 1.83 | .068 |
| Hard | −4.51 | [−6.64, −2.38] | 0.80 | [0.72, 0.89] | −4.19 | <.001 |
| Easy | −0.90 | [−2.36, 0.56] | 0.92 | [0.80, 1.06] | −1.21 | .226 |

The previous keys were paired t tests on the participant-level difference (df = 66): Standard mean 0.022, t = 2.33, p = .023; Hard mean −0.042, t = −4.83, p < .001; Easy mean −0.008, t = −1.16, p = .252. Those mean/t/df fields are gone. The new keys carry pp, pp_lo, pp_hi, or, or_lo, or_hi, z, and p.

Median RT, high minus low, in milliseconds (`T13e`). df and p use Satterthwaite. 774 cells.

| difficulty | ms | 95% CI | t | df | p |
| --- | ---: | --- | ---: | ---: | ---: |
| Standard | 36.3 | [−16.6, 89.2] | 1.35 | 700.7 | .179 |
| Hard | 7.0 | [−45.9, 59.9] | 0.26 | 700.7 | .795 |
| Easy | 11.1 | [−41.8, 64.0] | 0.41 | 700.7 | .681 |

`acc_model_re` is `(1 | subject_id)`.

The reduction sentence cites three keys that were added to `reports/references.bib`: `barr2013maximal`, `bates2015parsimonious`, and `brauer2018lmm`. `bates2015lme4` was already in the bibliography and is the lme4 software paper, so it is not used for this rule.

The accuracy GLMM, the reduction log, the accuracy contrasts, the RT model, and the RT contrasts are in dissertation section S7. The qmd has no S13. S12 remains the provenance section and now names the r8 comparison keys.

## 6. Audits

Key audit: the rendered chapter calls eight keys (`tepr_window_start`, `tepr_window_end`, `tepr_baseline_start`, `tepr_baseline_end`, `rope_v`, `rope_a`, `rope_z`, `acc_model_re`). All eight are in `inline_values.json`. Missing keys: 0. This is the same for the manuscript and dissertation renders; the dissertation-only chunk is executed in both, and the manuscript omits that text.

Hard-coded number audit of `reports/chap3_revised.qmd`, skipping code fences: the numbers that remain are section numbers, YAML layout values, and the run id `r10_20261017_081458`. Result rows: 0.

Pupil-key contract: after renaming `n_pupil_entered_vs_r5` and `n_pupil_left_vs_r5` to the r8 names, the key names and field lists match `pupil_key_contract.csv`. No other name differs.

`max_k_pupil_models` is present and its value is null. The LOO `.rds` files were not in the local table copy, so the maximum Pareto k could not be read. The status files do show that every model has zero Pareto k values above 0.7 after moment matching, so `n_pupil_models_k_gt_0.7` is 0.

D3, both docx files: no occurrence of `4,952`, `4952`, `64.6`, `16.2`, `5.3 ±`, `+7.7%`, `+4.8%`, `+2.7%`, `+1.8%`, `9,405`, `5,888`, or `5,107`. A search for the digits 5.3 hits `155.3` in the model-comparison table, which is an SE, not the forbidden pupil string. The pupil table shows the r10 values (P3 ΔELPD 67.9 ± 9.1, +7.9% [6.5, 9.2], 4,935 trials). The draft banner reads `r10_20261017_081458`.

B6. `reports/chap3_revised.qmd` has none of `3.75`, `0.3–3.3`, `4.65`, or `7.65`. In `scripts/final/F_figures.R` the blue AUC band and its caption read `tepr_window_start` and `tepr_window_end`. The y-coordinate 17.65 on the flow diagram contains the digit sequence 7.65 and is a box position, not the window. `scripts/final/V_inline_values.R` and `scripts/r10/build_r10_sample.R` set or apply the window (4.65 to 7.65 s; 0.3–3.3 s after the probe). The same literals remain in the r8 rebuild, the waveform helpers, and older window-selection scripts. Those files define the clock used to build the sample; they are not chapter prose.

## 7. r11

Not started. No pid and no log. Start it only after this commit is on the VM, from `~/Feb2026`:

```bash
cd ~/Feb2026
Rscript scripts/r11/refit_failing_behavioral.R
```

`scripts/final/V_inline_values.R` now rebuilds the contract-shaped pupil keys from T7, T8, and T9, and the accuracy and RT keys from T13d and T13e. On the VM that script reads `tables/final`. Those tables are not in git. The VM copy has to be the phase 1d tables before r11 runs, or the inline values will be rebuilt from the old files.

## 8. Not determined

`max_k_pupil_models`. It needs the r10 LOO objects (`loo_<model>.rds`, field `diagnostics$pareto_k`). They were not in the downloaded tables.
