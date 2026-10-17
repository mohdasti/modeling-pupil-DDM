# Phase 1b report

Branch `ch3-qmd-revision`. No model was refit. The July chapter was not edited.

Commits: `07fca67` A, `3d48b37` B, `a54d35d` C, `3597b9a` D. F3, F4, and F5 edit the same qmd as the comment fixes, so they are in `3597b9a` rather than a separate commit. This report is the E commit.

No fix was blocked. There is no `STOPPED.md`.

## Summary

**A.** Table S2 and Table S16 are Word tables. Each note is one paragraph under the table. `fmt_num()` prints a negative zero as `0.0`. The only `kable()` left in the helpers is inside `make_table()`.

**B.** Table 1 uses the MoCA-telephone label, a computed Not reported row (2 of 67), and an Ethnicity sub-header. Table S3 drops the superseded cutoff rows, adds P0_base from the fit file via `T10b_convergence_display.csv`, and names the three failures. Table S4 blanks ROPE and Direction off the effort terms and puts the link in the row label. Table S5 is wide: six rows, task by difficulty, with starting point and non-decision time in the note. Table S10 shows the P2 delta ELPD once. Table S11a is six paired rows and drops the QC gates and the TEPR–RT correlation. Tables S14 and S15 use the lookup, keep d′ as descriptive, add BH FDR by family, and split the baseline into S15a. Table S12 is a logit GLMM. Table S13 is median RT in seconds and has no p values. The Standard High − Low accuracy p values disagree and were not changed. The empty temporal model cell is `fatigue`.

**C.** The evidence-quality axis no longer says same/different. The 0.15 s cutoff row is an open dashed interval, and Table S7 (crossref; the manual heading is S4) marks it. F5 says Post-probe TEPR, takes the window from `tepr_window_post_probe`, and prints `0.0 ± 1.7`. Both rendered docx files embed the new PNGs.

**D.** C51 is on the 2.7.2 placeholder. No comment is mapped to Discussion or 4.1. The two r5 keys remain only on S12.

**E.** M1, M2, and M4_thr0.15 fail, all on max R-hat. Recorded fit times are 35.5, 37.1, and 39.8 minutes. A 2× post-warmup refit, warmup held at 1,500, is about 53, 56, and 60 minutes. It was not started. Page counts are a content-height estimate. The number audit has no `result` row. No key passed to `v()` is missing.

## A. Table rendering

`as.character(knitr::kable())` is one string per line. `paste0` of that vector and a footnote recycled the note onto every line, so pandoc left the pipes as text. `make_table()` now collapses the body with newlines and appends `*Note.*` once.

In `reports/chap3_revised_dissertation.docx`, Table S2 and Table S16 are `w:tbl` tables. The model-comparison note and the temporal note each appear once. The manuscript docx has no raw pipe tables. A pipe character inside a cell such as `|RT effort difference|` is the label, not a broken table.

`fmt_num()` treats a formatted value whose numeric value is 0 as unsigned. `tests/test_report_helpers.R` covers `fmt_num(-0.04, 1)`, `fmt_num(-1e-8, 1)`, and `fmt_num(-0.0004, 3)`.

## B. Tables

**B1.** The MoCA row is `MoCA-telephone, score /22 (SD)`. The source spreadsheet has race missing for BAP001 and BAP003, so the added row is Not reported. The count is N minus the four displayed race counts: 2 (3.0%). Hispanic/Latino is indented under an Ethnicity sub-header.

**B2.** `M3_thr0.15` and `M3_thr0.25` are dropped. P0_base was not in T10. Its diagnostics were read from the fit and written to `tables/final/T10b_convergence_display.csv`. The qmd convergence chunk reads that file. Order is primary, comparison, robustness, pupil baselines, pupil models. The note states the pass rule and `Fails: M1, M2, M4_thr0.15.`

**B3.** Direction and ROPE are blank except `b_effort_conditionhigh`, `b_effort_x_stim`, `b_bs_effort_conditionhigh`, and `b_bias_effort_conditionhigh`. Row labels name the link. The boundary and starting-point effort rows are `High effort (boundary separation, log)` and `High effort (starting point, logit)`.

**B4.** Wide layout. Six rows: task by difficulty. Columns are drift at low effort, drift at high effort, boundary at low effort, and boundary at high effort. Starting point (four task-by-effort cells) and the single non-decision time are in the note, on the probability and seconds scales.

**B5.** The P2 interaction row leaves delta ELPD blank. The block label is `Effort effects in the pupil subsample (P0)`. The note gives the baselines: P1–P3 vs P0; P4 and P5 vs P0_base; P3_rt vs P0_rt; P6 vs P0_lag; P7 vs P0_pre; P8 vs P0_grip.

**B6.** Table S11a has six rows: TEPR (B1), TEPR (B0), and grip-period pupil, each for ADT and VDT. Columns are n, High M (SD), Low M (SD), High − Low, t(df), and p. QC-gate rows and the TEPR–RT correlation are not in the table. The n of 30 (TEPR) and 29 (grip), against 42 in the pupil sample, is the both-levels filter. `paired_one` in `scripts/r8/D_descriptives.R` drops a subject who is missing high or low, and the grip block does the same with `is.finite`. The note states that rule and takes 42 from the `subject_task_ge_20` gate. It does not hard-code 30 or 29.

**B7.** The lookup in the prompt is applied. Two further labels come from the export's own column titles, not from a guess: `tmt_a` is Trail Making A (`Trail Making 1 (seconds)`), and `moca` is `MoCA-telephone, score /22` (`MoCA (phone screen; Out of 22)`). `accuracy` is mean accuracy. `accuracy_diff_abs` is labeled `|accuracy difference|` because the export stores the mean absolute accuracy difference; it is not an SD of accuracy.

No accuracy column, and no SD of accuracy across conditions, exists in the LC rows. The neuropsych rows have mean accuracy and `|accuracy difference|`, and no SD of accuracy. The d′ rows stay, labeled `d′ (descriptive)`. BH FDR is recomputed within family. The note counts are 35 (LC × behavioral), 15 (LC × DDM), 45 (neuropsych × behavioral), and 27 (neuropsych × DDM). The Analysis column is gone.

S15a, Baseline characteristics, is Measure, n, M (SD) or n (%), Range. T14 had dropped the ranges. The values, including Range, are from `output/neuropsych_demographics/extended_baseline_continuous.csv` and `extended_baseline_categorical.csv`, the July S9 source. Correlations stay in S15b.

**B8.** The accuracy caption and note say binomial GLMM, logit scale, Wald z, no denominator df. The RT caption and note say the outcome is the cell median RT in seconds, not log RT. `lme4::lmer` stored no p and no Satterthwaite df, so Table S13 has no p column. Reference levels are Standard, low effort, and auditory (ADT).

The Standard High − Low accuracy tests were not changed.

| Source | What it is | p |
|---|---|---|
| GLMM, `effort_conditionhigh` in `T13b_accuracy_glmm.csv` | trial-level logit coefficient at the Standard reference | 0.06796581183118545 |
| Inline key `acc_high_low_Standard` | paired t on subject-mean Standard accuracy | 0.0228 |

The GLMM is `glmer(correct ~ difficulty_3 * effort_condition + task + (1 | subject_id), family = binomial)` in `scripts/final/T_export_tables.R`, then `tidy(..., effects = "fixed")`. The p is the Wald p for `effort_conditionhigh`. The paired test is `paired_acc` in the same file: within Standard, subject means, both effort levels present, `t.test(..., paired = TRUE)`. `beh_of("Standard")` in `scripts/final/V_inline_values.R` copies that row into the inline key. The paired contrast pools tasks and is on the accuracy scale. The GLMM coefficient is a logit contrast at the Standard reference with task in the model.

**B9.** `exploratory_fatigue_trajectory_posterior_summary.csv` has no model column. The blank cell is filled with `fatigue`, the consolidate id. The note says the file has no model column.

## C. Figures

Old PNGs are `F3_effort_forest_v1.png` and `F5_pupil_boundary_v1.png` in `figures/final`. The new files were written with a Cairo PNG device so the dagger and the arrows survive.

**C1.** Drift criterion keeps `← toward 'same' / toward 'different' →`. Evidence quality is `← lower evidence quality / higher evidence quality →`. Boundary and starting point axis titles are `(log scale)` and `(logit scale)`.

**C2.** The `M4_thr0.15` interval is open and dashed, the y label carries ‡, and the caption is `‡ did not meet the R-hat < 1.01 criterion`. Table S7 is `ch3_tbl_robustness` (`supptbl-robustness`). In the dissertation docx that crossref is Table S7. The manual heading above it is S4. The Pass cell is `No‡` when max R-hat is at least 1.01, and the note names `M4_thr0.15`. Nothing was refit.

**C3.** Labels are `Post-probe TEPR (0.3–3.3 s after probe)` and `Post-probe TEPR, slowest 20% removed`. The window string is `iv$tepr_window_post_probe` (`0.3–3.3 s`), not a literal in the label. Delta ELPD is one decimal, with a Unicode minus on negative values. P7 is −0.037 ± 1.657, which prints as `0.0 ± 1.7`. Every other displayed delta is positive, so no minus sign is visible on those rows.

**C4.** Both docx files embed the new F3 and F5 PNGs. The sha256 matches the files in `figures/final` and does not match the `*_v1.png` copies.

**F2.** `S_lc_fiso_dprime_variability.png` is still the copied d′ figure. `S_lc_fiso_four_panel` still has panels `dprime_variability` and `dprime_mean`. No accuracy-SD column exists, so those figures were not regenerated. They sit with the d′ decision above.

## D. Comments

**D1.** C51 was absent from every placeholder. It is now on `### 2.7.2 Model specification`, which is the skeleton heading for the July section below. C47–C50 share that July section and were already listed on the parent 2.7 placeholder; they were left there.

- Author: Ilana Bennett
- Anchor: `Behavioral validation checks.`
- Comment: `stated earlier; not necessary to run/report`
- July section: `2.7.2 Model specification: standard-only calibration and primary model`

**D2.** No comment has July section `4 Discussion` or `4.1`. Comment ids run C0–C78 with none missing, and `new_section` is empty for every row, so the mapping lives in the placeholders. The July chapter has `# Discussion` and `## Limitations and future directions`, and no logged comment is anchored there.

Two comments use the word "discussion" and are not section 4:

- C54. Anchor: `Results`. July section: `3. Results`. Comment: `The results section is very challenging to get through. You have combined methods details and results and discussion-style summaries. Instead, create separate sections for each of the models that you ran and report the results in a clear format.`
- C66. Anchor: `As context for the effort tests, difficulty produced large, graded effects on drift rate (v; Easy > Hard > Standard), whereas boundary separation (a) and starting-point bias (z) varied less.` July section: `3.2.1 Behavioral hypothesis tests (H1-H4)`. Comment: `is this a results summary? just walk through the actual results and summarize in the discussion`

**D3.** `n_pupil_entered_vs_r5` and `n_pupil_left_vs_r5` were removed from the 2.6, 3.5, and pupil-supplement placeholder lists. They remain on S12 only.

## E. Report only

### E1. Convergence failures

Pass rule used for the list: max R-hat < 1.01, bulk ESS ≥ 400, tail ESS ≥ 400, 0 divergences. All three fail on max R-hat only. ESS and divergences pass. No refit was started.

| Model | Max R-hat | Min bulk ESS | Min tail ESS | Chains | Iterations | Warmup | Recorded fit | 2× post-warmup estimate |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| M1 | 1.013 | 664 | 1,216 | 8 | 3,000 | 1,500 | 35.5 min | 53 min |
| M2 | 1.014 | 652 | 1,217 | 8 | 3,000 | 1,500 | 37.1 min | 56 min |
| M4_thr0.15 | 1.013 | 926 | 1,843 | 8 | 3,000 | 1,500 | 39.8 min | 60 min |

Recorded times are the first `brm()` wall times in `r3_20261014_062419/logs/r3_status.txt` (M1, M2) and `r7_20261016_051737/logs/r7_status.txt` (M4_thr0.15). Later log lines say `done M1 in 0.0 min` because `file_refit = "on_change"` reloaded the saved fit. The `fit_minutes` values near 0.02 in `convergence_models.csv` are that reload, and they are not used here.

Post-warmup draws are 1,500 per chain. Twice that, with warmup held at 1,500, is 4,500 iterations, 1.5 times the recorded iteration count. The estimate multiplies the recorded minutes by 1.5. It assumes iteration cost stays constant.

### E2. Page counts

Word's page count was not available (`mdls` did not return `kMDItemNumberOfPages`, and LibreOffice is not installed). The figures below are content height divided by 9 inches (letter, 1 inch margins). Text is 12 pt single-spaced. Each drawing is counted once, at the embedded extent. Each table row is 0.22 inches. The unexpanded table-of-contents field is not given a page of its own. A section shown as 0.0 is a heading plus its placeholder, about 0.3 inches.

These totals are lower than the Phase 1 estimate. This pass does not add extra padding for the callout boxes.

#### Manuscript (`chap3_revised.docx`)

| Section | Estimated pages |
|---|---:|
| Front matter | 0.1 |
| Abstract | 0.0 |
| 1 Introduction | 0.0 |
| 2 Methods | 1.2 |
| 3 Results | 2.4 |
| 4 Discussion | 0.0 |
| References | 0.0 |
| Supplementary Materials | 7.1 |
| **Total** | **10.9** |

#### Dissertation (`chap3_revised_dissertation.docx`)

| Section | Estimated pages |
|---|---:|
| Front matter | 0.1 |
| Abstract | 0.0 |
| 1 Introduction | 0.0 |
| 2 Methods | 1.2 |
| 3 Results | 2.4 |
| 4 Discussion | 0.0 |
| References | 0.0 |
| Supplementary Materials | 15.0 |
| **Total** | **18.8** |

Methods is about 1.2 pages because it holds Table 1 and Figure 1. The Methods prose is still the placeholder. `number-sections: false` is set for html, pdf, and docx. Heading text in both docx files is `1 Introduction`, `2 Methods`, and so on. No heading has a second automatic number.

### E3. Audits

Both renders used `-P diag_dir:output/diagnostics/qmd_phase1b`. The default in the qmd is `output/diagnostics/qmd_current`. `keys_used.csv` is written there. The dissertation render ran second and wrote the same seven keys as the manuscript render.

`v()` calls, all present in `inline_keys.csv`: `tepr_window_start`, `tepr_window_end`, `tepr_baseline_start`, `tepr_baseline_end`, `rope_v`, `rope_a`, `rope_z`. Missing keys: none.

Unused keys: 113. Prose still does not call `v()`. `inline_keys.csv` has 121 rows and 120 unique names. `n_pupil_matched_trials` is stored twice, both 12630. `v()` returns the first.

`tepr_window_post_probe` is in the unused list because the figure script reads the rds directly. It is not a missing key. The F5 label is built from that string.

`hardcoded_audit.csv` has no row classified `result`.

| Classification | Count | What it is |
|---|---:|---|
| heading | 38 | Section numbers on markdown headings |
| format | 10 | YAML: CSL name, run-directory date, toc depth, margin, font size, line spacing, dpi |
| identifier | 4 | `params$pupil_run` and the r10 note on that line |
| crossref | 4 | The digit in `supptbl-fixef-m4` and `supptbl-m4b`, each in the div and in one placeholder reference |
| result | 0 | |

Digits inside comment ids, inline-key names, and table stems were left out of that table. They are identifiers. None is a typed result.

## F. Addendum

**F1.** The A and B table changes are in `R/ch3_report_helpers.R`. The helpers file has one `kable()`, inside `make_table()`, and no hand-built pipe table.

**F2.** Listed under B7 and C. The d′ figures were not regenerated.

**F3.** The three `tbl-cap` strings no longer contain U+200B. The helpers file has none. The captions still start with `[CAPTION TO BE SUPPLIED]`. Both docx renders completed with those captions. Grep of the qmd found no remaining U+200B.

**F4.** `params$diag_dir` defaults to `output/diagnostics/qmd_current`. The keys writer and this audit read that parameter. This run overrode it to `output/diagnostics/qmd_phase1b`.

**F5.** `number-sections: false` in html, pdf, and docx. Manual heading numbers are unchanged. Neither docx shows a double number.

## Lookup labels left for a decision

None of the names in the requested lookup were left raw.

Left as `d′ (descriptive)`, because the replacement columns are not in the source and new measures were not computed:

- `dprime_mean`, `dprime_variability` (LC table and `S_lc_fiso_four_panel`)
- `dprime_var` (neuropsych table)
- `S_lc_fiso_dprime_variability.png` (unchanged copy)
