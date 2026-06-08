# Supplementary Material S13: Exploratory LC Structural Correlates

## Overview

LC MRI metrics were acquired in a subset of BAP participants using the magnetization-transfer and diffusion pipeline described in Bennett et al. (2024). That sample overlaps substantially with the present chapter cohort (expanded here with additional behavioral task sessions). These analyses are **exploratory** and do not enter primary hypothesis tests or model selection.

**Script:** `scripts/lc_integrity_supplement_analysis.R`  
**Outputs:** `output/lc_integrity/`

## Sample

- **N = 67** participants with both LC metrics and primary DDM random effects
- **n = 57** with complete NODDI metrics (LC fISO / fICVF)
- LC-MRI and non-LC subsets did not differ on mean accuracy, RT, effort cost, or age (all *p* > .19)

## LC metrics

| Metric | Description |
|---|---|
| LC_CNR_max | Maximum magnetization-transfer contrast (MTC proxy) |
| LC_fISO | NODDI free-water fraction |
| LC_fICVF | NODDI restricted (intracellular) volume fraction |
| LC_Composite_v2 / PC1_v2 | Multivariate composites from the LC pipeline |

## Key findings (age + sex partialled)

### 1. Variability, not mean performance (Bennett-aligned)

Higher LC **free-water** fraction (fISO) predicted **greater cross-intensity d′ variability** (partial *r* = .40, *p* = .002, *n* = 57) but **not** mean d′ (*p* = .18). This parallels Bennett et al.'s report that LC diffusion metrics relate to recall **variability** rather than mean memory accuracy in older adults — here expressed in a perceptual decision domain.

### 2. DDM individual differences (exploratory)

| Outcome | LC predictor | Partial *r* | *p* |
|---|---|---|---|
| Baseline boundary *a* | LC fISO | −.39 | .003 |
| Baseline drift *v* | LC fISO | −.16 | .24 |
| Baseline bias *z* | LC fISO | −.03 | .81 |
| Mean TEPR | LC fISO | .22 | .10 |
| Mean TEPR | LC CNR_max | .18 | .19 |

Higher LC fISO was associated with **lower baseline boundary separation** (*a*). There was **no credible association** with baseline drift (*v*), bias (*z*), or trial-wise TEPR — consistent with treating pupil as a functional phasic-arousal index rather than an anatomical LC readout.

The primary **group-level effort effect on drift** (H1) is therefore unchanged: LC integrity does not substitute for or explain that contrast in this sample, though it may relate to **between-person consistency** and baseline decision thresholds.

### 3. Effort-related behavioral costs

LC fISO showed a marginal association with **absolute RT effort cost** (partial *r* = −.31, *p* = .019): participants with higher free-water fraction showed **smaller** RT slowing under High vs. Low grip. Accuracy effort costs were not significant.

## Multiplicity

Across the full predictor × outcome grid, two LC fISO associations survived FDR *q* < .10 (d′ variability, mean RT). Primary inferences are based on uncorrected *p* with explicit exploratory labeling; see @tbl-lc-exploratory-correlations in Appendix A8.

## Figures

- `fig_lc_fiso_dprime_variability` — headline variability association
- `fig_lc_fiso_four_panel` — variability vs. mean d′, baseline *a*, and TEPR

## Interpretation for Chapter 3

These results **do not alter** primary DDM conclusions (effort → drift reduction). They provide exploratory context: LC microstructure, particularly free-water diffusion, tracks **behavioral consistency** and baseline boundary settings in older adults performing concurrent grip — extending Bennett et al.'s variability-focused LC framework to dual-task perceptual decision making in an overlapping cohort.
