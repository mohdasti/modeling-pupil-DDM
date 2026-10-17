# R11: refit M1, M2, and M4 at the 0.15 s cutoff

Do not start this until r10 has finished and its extract has been written.
The script refuses to run otherwise. It does not write into the r9 or r10 directories, and it does not change `tables/final` unless all three models pass.

## Run order

1. Finish and export r10. The run id in `output/ddm_refits/runs/r10_latest_run_id.txt` must start with `r10_`. That run must contain `logs/r8_status.txt` with the line `pupil fit/loo finished`, plus `tables/r8_slopes.csv` and `tables/r8_effort_terms.csv`.
2. Only then start r11.

## Command

From the repo root on the VM:

```bash
cd ~/Feb2026
Rscript scripts/r11/refit_failing_behavioral.R
```

Output goes to `output/ddm_refits/runs/r11_<timestamp>/`.

## What it fits

| Model | Data | Formula, priors, init, seed |
| --- | --- | --- |
| M1, M2 | Canonical 17,857-trial fit, 0.20 s | Same as `scripts/refit_r3/refit_behavioral_r3.R` |
| M4_thr0.15 | `data/analysis_ready/r7/ddm_m4_cue_thr0.15.csv`, 17,981 trials | Same as `scripts/r7/refit_behavioral_r7.R` |

Sampler for every model: 8 chains, `iter = 4500`, `warmup = 1500`, `adapt_delta = 0.95`, `max_treedepth = 12`, seed 2026, `save_pars(all = TRUE)`.

M1 and M2 then get PSIS-LOO, moment matching when any Pareto k exceeds 0.7, and reloo when 1 to 5 of those points remain. M4_thr0.15 does not get a new LOO. The M0–M4b comparison uses the new M1 and M2 LOO objects and the stored M0, M3, M4, and M4b objects. It stops if the new pointwise LOO length differs from M4.

## Pass rule

A model passes when max R-hat is below 1.01, bulk ESS and tail ESS are at least 400, and there are 0 divergences.

If any of the three still fails, the script writes `tables/r11_STOPPED.md` in the run directory and stops. It does not add iterations, and it does not edit `tables/final`.

If all three pass, it copies the replaced files to `*_pre_r11` and updates `T5_model_comparison.csv`, `T5_delta_M0_vs_M1.csv`, `T6a_robustness_effort_terms.csv`, `T10_convergence_all.csv`, `T10b_convergence_display.csv`, and the inline values. It then redraws only `F3_effort_forest`. The 0.15 s row loses its dagger when that model's max R-hat is below 1.01.
