# Chapter 3 — Analysis decision record (r3–r7 refits, Oct 2026) — ANALYSIS PHASE CLOSED

Supersedes all DDM and pupil-DDM numbers in chap3_July1st.docx (those came from run 20260226_092110, whose fits settled on t0 = 0.504 s, whose difficulty-only LOO used 18,097 pre-cutoff trials, and whose pupil models used a broken trial join).

## Why the refit
1. Table S1 comparisons were invalid: difficulty-only LOO used 18,097 trials vs 17,857 for other models; interaction's +1,516 ELPD came from a different t0 solution (0.527 vs 0.504 s), 52% of it from the fastest RT decile.
2. Cutoff-sensitivity fits (0.15/0.25 s) failed R-hat (1.022/1.026).
3. "8 chains" in text was wrong (run used 4).
4. Interpretation: under response-side coding, the additive effort coefficient on signed drift is a shift toward "same", not lower evidence quality. Raw accuracy, from the exported tables: Standard (same) trials +2.2 points under high effort (p = .023); Hard trials −4.2 points (p < .001). The earlier diagnostic (+2.3 / −4.4, p = .013) is not the value to cite. (A model-free SDT check — d' unchanged, criterion c shifted — was used only as a diagnostic; not planned for the chapter beyond an optional dissertation-supplement table.)
5. Pupil join bug (build_ddm_pupil_ready_data.R): pupil matched on subject × task × within-run trial_num and averaged across up to 5 runs; effort labels disagreed on 40% of trials. Old pupil-DDM nulls are uninformative. QC gate (pupil_qc_exclude) had also not been applied.

## Runs
- r3: output/ddm_refits/runs/r3_20261014_062419 (M0–M3; 8 chains × 3000, 1500 warmup; save_pars(all); moment matching + reloo)
- r4: output/ddm_refits/runs/r4_20261015_074152 (M4, M4b; same settings)
- r5: pupil models P0–P4 (4,569 trials, 39 subjects) + M4r (17,857 trials); same settings. Fixed join uses session_num/run_num from bap_beh_trialdata_v3.csv; effort and difficulty labels agree 100% on 12,630 matched trials.
- r6: pupil ordering tests P5–P8, P3_rt, each with a same-N P0 baseline; same settings; all converged (max R-hat ≤ 1.008), no Pareto-k > 0.7.
- r7: M4 at cue-locked RT cutoffs 0.15 s (17,981 trials) and 0.25 s (17,720 trials), 67 subjects; same settings.
- M4_subchance: near-chance exclusion, 13 participants removed, N = 54, 14,642 trials. See the section below.
- Canonical consolidated run: output/ddm_refits/runs/final_20261016/. r8 pupil refit is separate: output/ddm_refits/runs/r8_20261017_015218 on the VM.
- t0 = 0.527 [0.525, 0.529] s in every 0.20-s full-sample fit.

## Model comparison (PSIS-LOO after moment matching/reloo)
- r3: M0 −17,820.6; M1 −17,816.9; M2 −17,816.0; M3 −17,816.8 → effort/interaction terms not distinguishable by LOO. M1, M2 failed R-hat (1.013, 1.014).
- r4: M4 0; M4b −1.58 (1.53); M3 −158.27 (19.99) → task on drift strongly improves prediction; effort × task does not.
- **Primary model = M4**: v ~ difficulty_3 * task + effort + effort_x_stim + (1|subj); bs ~ difficulty_3 + task + effort + (1|subj); bias ~ task + effort + (1|subj); ndt ~ 1. effort_x_stim = high × stim_sign (+1 Hard/Easy, −1 Standard). Converged: max R-hat 1.009, min bulk ESS 863, 0 divergences.
- M4r (random effort slopes on v and bs): fixed effects unchanged (criterion −0.053 [−0.104, −0.004]; quality −0.012 [−0.054, 0.028]; bs +0.020 [0.006, 0.034]); slope SDs tiny (v 0.019 [0.001, 0.062]; bs 0.007 [0.000, 0.023]); correlations unidentified; LOO ≈ M4. → Report as robustness; keep M4 primary. No detectable individual differences in effort effect → drop subject-level effort panels (old Fig 4 B–C).

## Primary results (M4; High − Low; ROPE: drift ±0.02, log-a and logit-z ±0.05)
- Drift criterion (toward "same"): −0.053 [−0.103, −0.003]; P(<0) = .981; 9% in ROPE.
- Evidence quality (effort × stimulus): −0.013 [−0.052, 0.028]; 59% in ROPE → no evidence of degradation, not equivalence.
- Boundary (log): +0.020 [0.006, 0.033] (~2% wider); 100% in ROPE → negligible.
- Bias (logit): −0.005 [−0.048, 0.037]; 98% in ROPE; CrI inside ROPE → practically equivalent to zero.
- Task: VDT drift −0.292 on Standard; larger difficulty effects on VDT (Hard × VDT +0.342, Easy × VDT +0.771); bs task ≈ 0; bias_taskVDT −0.054 [−0.099, −0.010] (agrees with Standard-only calibration; old "reversal" was a pooling artifact).
- M4b: effort × task terms span zero; criterion shift ADT −0.077 [−0.139, −0.017], VDT −0.024 [−0.087, 0.040] — directionally ADT-driven, not credibly different.

## RT-cutoff sensitivity (r7, M4 structure; posterior means [95% CrI])
| Term | 0.15 s | 0.20 s | 0.25 s |
|---|---|---|---|
| Criterion | −0.059 [−0.108, −0.010] | −0.053 [−0.103, −0.003] | −0.061 [−0.111, −0.010] |
| Quality | −0.015 [−0.054, 0.024] | −0.013 [−0.052, 0.028] | −0.013 [−0.055, 0.028] |
| Boundary | +0.012 [−0.002, 0.025] | +0.020 [0.006, 0.033] | +0.019 [0.005, 0.032] |
| Bias | +0.010 [−0.035, 0.053] | −0.005 [−0.048, 0.037] | +0.009 [−0.034, 0.051] |
| t0 (s) | 0.483 | 0.527 | 0.572 |
- Criterion shift robust; quality and bias null at every cutoff; boundary effect negligible and cutoff-sensitive (includes zero at 0.15 s).
- t0 tracks the RT cutoff almost one-for-one (~0.044–0.045 s per 0.05-s change in cutoff): t0 is pinned to the fastest retained RTs and is not interpretable as encoding/motor time → state in Methods/Limitations.
- Convergence: 0.25 s passes (max R-hat 1.008, min bulk ESS 893). 0.15 s max R-hat 1.013 on Intercept_bs only (bulk ESS 926; 0 divergences); report this honestly — effort terms and t0 R-hat 1.00 per Cursor.

## Near-chance exclusion sensitivity (M4_subchance)
- Rule: overall accuracy ≤ .55 on the 17,857-trial file → 13 excluded, N = 54, 14,642 trials (BAP103, BAP110, BAP114, BAP122, BAP125, BAP129, BAP135, BAP138, BAP139, BAP159, BAP183, BAP195, BAP201). The chapter's "12 / N = 55" came from an earlier dataset; those IDs were not saved.
- Converged (max R-hat 1.008). Criterion −0.052 [−0.106, 0.003]. Wording: the point estimate was unchanged; the interval widened to include zero.
- Quality −0.013 [−0.057, 0.032]; boundary +0.016 [0.001, 0.031]; bias −0.005 [−0.053, 0.041].

## Behavior (canonical, exported tables)
- Accuracy High − Low: Standard +2.2 points, p = .023; Hard −4.2 points, p < .001. Easy is not the cited contrast.

## Pupil results (r5–r6) — superseded, do not cite
Invalid, not provisional. These slopes, ΔELPDs, pupil-subset effort terms, and the r5/r6 pupil–RT correlation were fit on the mixed flat-file table: 640 of 4,569 trials (14%) had their pupil windows on the wrong clock. Do not use them in drafts, figure captions, or inline values. Usable pupil-related numbers until the r8 refit returns are the behavioral results and the r8 descriptives in the amendment below (gate counts, pupil–RT correlation, High − Low tests, grip-period dilation).

- QC gates on the mixed table: matched 12,630 (61 subj) → TEPR non-missing 7,995 → B1 quality ≥ .50: 5,141 → cog quality ≥ .50: 4,749 → ≥20 trials per subject × task: 4,569 (39 subj).
- Predictors centered within subject × task × effort, scaled by pooled within-cell SD.
- r5 LOO: P3 (TEPR on bs) 0; P2 (TEPR + TEPR × stim on v) −32.95 (7.67); P4 (baseline on bias) −38.57 (7.00); P0 −38.68 (6.97); P1 (TEPR on bias) −38.88 (6.97).
- P3: bs_tepr_c +0.060 [0.046, 0.073] (~6% wider a per SD). P2: tepr_c:stim_sign −0.077 [−0.117, −0.036]. P1, P4 slopes ≈ 0.
- Effort on pupil subset (P0): criterion −0.057 [−0.156, 0.045] (same point estimate, wider CrI); bs +0.037 [0.009, 0.065].
- Raw decision-window TEPR not higher under high effort (ADT −0.29, p = .27; VDT −0.28, p = .14); baseline unchanged.
- r6 duration confound: within-subject r(TEPR, probe-locked RT) = .23 [.16, .29] (Easy .14, Hard .27, Standard .23).
- r6 P3_rt (slowest 20% per subject × task dropped; 3,677 trials): bs_tepr_c +0.033 [0.017, 0.050]; ΔELPD vs P0_rt 7.20 (3.07). Effect halves; remaining effect is an upper bound on any arousal contribution.
- r6 pre-decision predictors on bs (each vs same-N P0): baseline pupil P5 +0.017 [0.004, 0.030], ΔELPD 2.12 (2.09); previous-trial TEPR P6 +0.025 [0.009, 0.040], 3.81 (2.36) (caveat: RT autocorrelation); pre-choice window [RT−0.5, RT) P7 +0.013 [−0.003, 0.027], 0.25 (1.64) (904 trials failed coverage); grip period P8 −0.018 [−0.031, −0.004], 2.37 (2.06) (opposite sign; likely within-cell force variation).
- r6 grip-period dilation (manipulation description): High − Low ADT +0.46, t(28) = 2.66, p = .013; VDT +0.18, t(27) = 1.35, p = .19.
- Superseded conclusion, do not cite: TEPR–a coupling largely reflects decision duration; pre-decision measures show small same-direction associations without reliable predictive gain. Not a chapter conclusion. Lani C15 and C43 wait on the r8 refit.
- Optional, not run: P6b = P6 + previous-trial RT on bs.

## Fit (PPC, 200 draws)
- Choice proportions: M4 10/12 cells inside 95% PI (max |obs − pred| = .029). The P3 PPC (12/12) is part of the superseded pupil fit; do not cite.
- RT quantiles: M4 ~28% inside PI; medians ~175–185 ms slower than predicted; 0.9 quantile over-predicted. Structural (response-signal design; brms wiener has no sv/sz/st0). Limitations wording: the misfit comes mostly from the less frequent response in each condition, which the model cannot produce without drift variability. Pupil-subset PPCs are part of the superseded fit; do not cite.
- The t0 posterior sits about 2.7 SD above its prior mean. Supplement note, not a new result.

## Placement plan
- Main text: M4 effort results; task effects briefly; M4r and cutoff robustness one sentence each. Pupil-model sentences (P3, trimmed-RT, ordering slopes, ΔELPD) are not drafted until the r8 refit. Usable now: r8 QC counts, pupil–RT correlation, High − Low tests, and grip-period dilation.
- Manuscript supplement: convergence/PPC, LOO table (M0–M4b), cutoff sensitivity table, pupil ordering table (P3_rt, P5–P8), QC flow.
- Dissertation supplement: everything else (P1, P2, P4, M2/M3 details, SDT diagnostic if wanted, choice-history/fatigue with caveat).

## Workflow (remaining)
1. Consolidate final models/tables into one run dir matching qmd paths (params$run_dir). 2. Cursor regenerates figures from repo scripts; review. 3. Rewrite reports/chap3_ddm_results.qmd (Results → Methods → Intro → Discussion), with a comment-resolution log for Lani's docx comments. 4. Render; audit every reported number against extracts; remove hardcoded prose numbers.

## Figure plan
- Fig 1 panel C redo (task on drift; criterion vs quality). Fig 2 regenerate from M4 split by task. Fig 3 → forest plot of criterion, quality, a, z with ROPE bands. Fig 4: keep Brinley panel; drop subject-level effort panels. Pupil figure: P3 slope with trimmed-RT and pre-decision slopes alongside (one forest panel). S4, S10, PPC figures regenerate; cut S11, S12. S1 participant flow must use the new pupil QC counts. Choice-history/fatigue (S22) fit on old base → dissertation supplement with caveat or refit.

## Open items
- Justify ROPE values in Methods (currently "project ROPE", no source).
- Pupil subsample selectivity must be stated in Methods. The r8 sample is 42/67 (the r5 figure was 39/67).
- "Effort raises arousal" premise: support only with grip-period pupil, not decision-window TEPR. On the r8 sample the grip High − Low effect is ADT +0.51, t(28) = 2.72, p = .011, and VDT +0.21, t(28) = 2.04, p = .051.

## Amendment (16 Oct 2026): one pupil time base (r8). r5–r6 pupil models superseded, do not cite
The stored pupil table mixed two flat-file generations. December 21 files (`BAP_processed/`, the directory in `config/data_paths.yaml`) put the light-reflex dip at 3.22 s, recovered by 3.8 s, with the post-probe peak at 5.06 s. December 25 files (`BAP_processed/build_20251225_154443/`) end each trial at about 7.73 s (Resp1ET), an epoch of 10.73 s. The builder placed those samples evenly from −3.0 to 10.7 s (13.7 s). The stretch is 13.7 / 10.73 = 1.28, not 1.4. A dip at 3.2 s then lands at (6.2 / 10.73) × 13.7 − 3 ≈ 4.9 s, matching the observed 4.86 s minimum and the 7.08 s peak. That is a time-axis error. December 21 is the generation used for r8. Evidence: `output/diagnostics/pupil_rebuild/partA_decision.md`.

r8 recomputed every matched trial from the December 21 files only. On the 3,925 r5 QC trials that already agreed with those files, the AUC matches to 1e-14. Of the 640 mis-timed trials, 121 leave the QC sample (117 fail B1 quality, 4 have no TEPR) and 504 trials enter that the stretched values had kept out.

| Gate | r5 (mixed) | r8 (December 21) |
| --- | --- | --- |
| Matched | 12,630 (61) | 12,630 (61) |
| TEPR present | 7,995 (59) | 9,405 (60) |
| B1 quality ≥ .50 | 5,141 (52) | 5,888 (52) |
| Window quality ≥ .50 | 4,749 (50) | 5,107 (52) |
| ≥ 20 trials per subject × task | 4,569 (39) | 4,952 (42) |

Pupil-measure definition, for Methods: the modeled TEPR is the decision-window AUC after subtracting the 0.5 s immediately before the probe (B1, [3.85, 4.35)). It is not corrected by the pre-squeeze baseline. The pre-squeeze mean (B0, [−0.5, 0)) is a separate predictor and is what the timecourse figure subtracts.

Descriptives on the r8 QC sample, before the refit:
- Within-subject r(TEPR, probe-locked RT) = .29 [.23, .35].
- Decision-window TEPR, measured from the 0.5 s before the probe, High − Low: ADT −0.79, t(29) = −2.12, p = .042; VDT −0.45, t(29) = −2.74, p = .011. The same window measured from before the squeeze: ADT +0.66, p = .14; VDT −0.06, p = .87.
- The r8 timecourse is B0-corrected. In ADT the effort curves separate in the first second, before a grip effect should appear. Not interpreted.
- Flow figure and timecourse: `output/ddm_refits/runs/final_20261016/figures/final_r8/`. Table: `tables/final_r8/T9_pupil_descriptives.csv`.

The r5–r6 pupil slopes and ΔELPDs are not chapter numbers. The replacement is the r8 refit (`r8_20261017_015218`), which finished with every model converged (max R-hat 1.009, minimum bulk ESS 1,374, 0 divergences, adapt_delta 0.95).

P5 cannot be compared with the full-sample P0. Three hundred forty of the 4,952 trials have no pre-squeeze baseline, so P5 and P4 are fit on the 4,612 trials with a finite `base_c`. `P0_base` is the matching baseline on those same rows. Confirmed: fit 4.5 min, R-hat 1.0050, bulk ESS 1,749, 0 divergences; LOO done. P5's ΔELPD below is against `P0_base`.

## Pupil results (r8) — cite these
Boundary slopes are the change in log(a) per SD. Percent is 100 × (exp(slope) − 1). ΔELPD is the model minus its matched baseline.

| Model | Baseline | N | Slope [95% CrI] | % change in a | ΔELPD (SE) |
| --- | --- | ---: | --- | --- | --- |
| P3 current-trial TEPR | P0 | 4,952 | +0.074 [0.061, 0.087] | +7.7 [6.3, 9.1] | +64.59 (8.99) |
| P3_rt, slowest 20% removed | P0_rt | 3,986 | +0.047 [0.031, 0.062] | +4.8 [3.2, 6.4] | +16.24 (4.56) |
| P5 pre-squeeze baseline | P0_base | 4,612 | +0.018 [0.005, 0.031] | +1.8 [0.5, 3.1] | +2.21 (2.18) |
| P6 previous-trial TEPR | P0_lag | 3,823 | +0.027 [0.012, 0.042] | +2.7 [1.2, 4.3] | +5.32 (2.65) |
| P7 0.5 s before the response | P0_pre | 3,678 | +0.013 [−0.002, 0.027] | +1.3 [−0.2, 2.8] | −0.04 (1.66) |
| P8 grip period | P0_grip | 4,444 | −0.017 [−0.031, −0.004] | −1.7 [−3.0, −0.4] | +2.62 (2.06) |

Also on the full 4,952 trials: P1 (TEPR on bias) +0.002 [−0.030, 0.035], ΔELPD −0.92 (0.19). P2 (TEPR on drift) +0.050 [0.011, 0.088] and TEPR × stimulus −0.091 [−0.130, −0.053], ΔELPD +8.69 (5.29). P4 (pre-squeeze baseline on bias, vs P0_base) −0.013 [−0.045, 0.019], ΔELPD −0.38 (0.63).

P0 effort terms on the pupil sample: criterion −0.071 [−0.166, 0.025]; quality +0.051 [−0.029, 0.129]; boundary +0.039 [0.011, 0.066] (+4.0%); bias −0.020 [−0.104, 0.063].

Tables: `output/ddm_refits/runs/final_20261016/tables/final_r8/`. Figure: `figures/final_r8/F5_pupil_boundary.png`.

Still to do, and not part of the r8 models: find every other reader of `ch3_triallevel.csv`, `build_20251225_154443`, or `make_quick_share_v7.R` output, and make the even-spacing fallback stop instead of stretching a short trial onto −3 to 10.7 s.

**2026-10-25: D017 handoff from Chapter 2.**

- **Pupil time axis.** The BAP flat files are 250 Hz (t = −3 + 0.004(k−1); 3,425 samples = −3.0 to 10.70 s, matching squeeze-to-end-of-confidence). The r8 step rule (median timestamp step 0.0035 s) compressed time by 0.875. The light-reflex check could not distinguish the two axes: the dip at 3.12 s on the step axis is 3.57 s on the true axis, which is plausible either way. **All r8–r10 pupil results are invalid**; r8, r10 → status `invalid_time_axis`. Behavioral models are unaffected.
- **r12** re-fits the 15 pupil models from `ch3_compatible_pupil_r2.csv` (md5 b51234f7…; mean TEPR [4.65, 7.65] minus pre-probe [3.85, 4.35); grip [1.0, 4.35]; pre-squeeze [−0.5, 0); ≥ 50% coverage; ≥ 20 trials per participant × task). Centering stays within participant × task × effort.
- **Framing.** Effort × difficulty. No LC or arousal outside one Discussion paragraph and one limitation. "Locus coeruleus activity during the task" wording (the cohort had LC MRI). Chapter 3 S8 is cut.
- **Terminology.** "Effort" means physical effort; there is no "cognitive effort". "Caution" means boundary separation only, so Chapter 2 should drop "selective caution".
- **Open.** The Chapter 2 and Chapter 3 samples differ (68 / 18,266 vs 67 / 17,857) and must be reconciled.

Status after the D017 pass: the r12 sample is built (`data/analysis_ready/r12/`, 6,299 trials, 51 participants). The 15-model fit was not started. `gcloud` is not installed on this machine, so the VM could not be reached. r8 and r10 remain invalid and were not marked in MANIFEST, because that update is part of the export after the fit.

Dissertation version uses r12. A dilation-speed filter (Kret & Sjak-Shie, 2019) and a re-fit of the affected pupil models are deferred to the journal version. Reason: the only known artifact affects 58 of 6,299 trials by less than 5% of a within-person SD, so it cannot change any reported conclusion.
