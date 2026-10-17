# Phase 1c

Branch `ch3-qmd-revision`. Nothing was pushed. The r9 and r10 pupil scripts and outputs were not changed.

## Part 1. One accuracy model

The requested model is a binomial GLMM on the primary 17,857 trials, with a by-subject effort slope. If that fit is singular, the correlation is dropped and effort is coded as −0.5/0.5. A random-intercept-only model is not an allowed fallback.

Both versions are singular, so the export stopped. `T13b` and `T13c` on disk are the previous tables. `T13d_accuracy_effort_contrasts.csv` was not written. The inline keys were not replaced. The two docx files were not re-rendered, and the key audit and number audit were not re-run, because their inputs did not change.

### Random-effects structure

Neither structure was used for inference.

Accuracy, bobyqa, `maxfun = 2e5`. Both fits finished (`conv$opt = 0`) on the boundary. `isSingular()` is TRUE. lme4 stored no warning text.

| Version | Random effects | Result |
| --- | --- | --- |
| Correlated | `(1 + effort_condition \| subject_id)` | Intercept SD 0.71700968. Effort-slope SD 0. Cholesky correlation −0.03126575. 328 function evaluations. |
| Uncorrelated | `(1 \| subject_id) + (0 + effort_c \| subject_id)`, effort coded ±0.5 | Intercept SD 0.701312. Effort SD 0. 254 function evaluations. |

A restart of the uncorrelated model from an effort SD of 0.4 returned the same boundary (effort SD 0). `nloptwrap` did too (effort SD 0, intercept SD 0.701234, 45 evaluations).

The median-RT model, fit on the same 774 subject × task × difficulty × effort cells with `lmerTest::lmer`, is also singular. The export halted on the accuracy model before writing `T13c`; this RT check used the same formula and the same fallback.

| Version | Result |
| --- | --- |
| Correlated | Intercept SD 0.250617. Effort SD 0.011183. Correlation 1.000. Residual SD 0.216398. Warning: `boundary (singular) fit`. |
| Uncorrelated, effort ±0.5 | Intercept SD 0.25614. Effort SD 0. Residual SD 0.21648. Singular. |

### T13d

Not produced. The singular fits were not turned into High − Low contrasts.

### `acc_high_low_*`

The keys still hold the paired *t* test on subject-mean accuracy. `acc_model_re` was not added.

| Key | Old value, still current | New value |
| --- | --- | --- |
| `acc_high_low_Standard` | mean 0.021835, *t*(66) = 2.332, *p* = .023 | not written |
| `acc_high_low_Hard` | mean −0.041784, *t*(66) = −4.833, *p* = 8.37e-06 | not written |
| `acc_high_low_Easy` | mean −0.008477, *t*(66) = −1.156, *p* = .252 | not written |

`inline_values.json` is identical to the copy taken before the fit. The random-intercept GLMM in `T13b` is also unchanged: the Standard High-versus-Low term `effort_conditionhigh` is 0.204, Wald *p* = .068.

### Convergence warnings

Accuracy: no warning text. The singularity flag and an effort-slope SD of exactly 0 are the evidence. Median RT: `boundary (singular) fit: see help('isSingular')` for both the correlated and the uncorrelated fit.

## Part 2. Queue, not started

`scripts/r11/refit_failing_behavioral.R` and `scripts/r11/README.md` are written. The script was not run.

It fits M1, M2, and M4 at the 0.15 s cutoff with the original formulas, priors, data, init, and seed. The sampler is 8 chains, 4,500 iterations, 1,500 warmup, `adapt_delta` 0.95, `max_treedepth` 12, seed 2026, and `save_pars(all = TRUE)`. Output is `output/ddm_refits/runs/r11_<timestamp>/`.

M1 and M2 get LOO with moment matching and reloo, as in the original procedure. The script rebuilds the M0–M4b comparison from the new M1 and M2 LOO objects and the stored M0, M3, M4, and M4b objects, re-extracts the M4_thr0.15 effort terms, and writes old-versus-new estimates in the run directory.

A model passes when max R-hat is below 1.01, bulk ESS and tail ESS are at least 400, and there are 0 divergences. If any of the three still fails, the script writes `r11_STOPPED.md` and stops. It does not add iterations and it does not edit `tables/final`.

If all three pass, it keeps the replaced files as `*_pre_r11` and updates `T5`, `T5_delta_M0_vs_M1`, `T6a`, `T10`, `T10b`, and the inline values. It then redraws only the effort forest. The 0.15 s dagger and dashed interval now follow `max_rhat >= 1.01` in `scripts/final/F_figures.R`. The current PNG was not regenerated, so it still shows the dagger. The robustness table already uses the same R-hat rule.

### Command and order

r10 must be finished and exported first. The script checks `output/ddm_refits/runs/r10_latest_run_id.txt`, that run's `logs/r8_status.txt` for `pupil fit/loo finished`, and that run's `tables/r8_slopes.csv` and `tables/r8_effort_terms.csv`.

```bash
cd ~/Feb2026
Rscript scripts/r11/refit_failing_behavioral.R
```

## What is in this zip

- This report.
- `T13b_accuracy_glmm.csv` and `T13c_rt_lmm.csv`, unchanged.
- `T13d_NOT_WRITTEN.txt`, because the contrast file was not created.
- `inline_values.diff`. The two JSON files match.
- `chap3_revised.docx` and `chap3_revised_dissertation.docx`, the existing renders, not a new render.
- `scripts/r11/`.
