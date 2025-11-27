# Extracted DDM Parameters - Comprehensive Summary

**Date:** 2025-11-26  
**Models:** Standard-only bias model + Primary model  
**Purpose:** Complete parameter estimates for manuscript and statistical analysis

---

## Table of Contents

1. [Standard-Only Bias Model - Bias Levels](#1-standard-only-bias-model---bias-levels)
2. [Standard-Only Bias Model - Bias Contrasts](#2-standard-only-bias-model---bias-contrasts)
3. [Primary Model - Fixed Effects](#3-primary-model---fixed-effects)
4. [Primary Model - Effect Contrasts](#4-primary-model---effect-contrasts)
5. [Primary Model - Condition-Specific Parameters](#5-primary-model---condition-specific-parameters)
6. [Statistical Hypothesis Tests](#6-statistical-hypothesis-tests)
7. [Effect Sizes](#7-effect-sizes)

---

## 1. Standard-Only Bias Model - Bias Levels

**Model:** Standard-only bias model (3,597 Standard trials)  
**Parameter:** Starting-point bias (z) on probability scale

| Condition | Scale | Mean | SD | Q2.5 | Q97.5 | Median |
|-----------|-------|------|----|----|----|--------|
| ADT Low | logit | 0.293 | 0.040 | 0.214 | 0.372 | 0.293 |
| ADT Low | prob | 0.573 | 0.010 | 0.553 | 0.592 | 0.573 |
| ADT High | logit | 0.322 | 0.040 | 0.243 | 0.401 | 0.322 |
| ADT High | prob | 0.580 | 0.010 | 0.560 | 0.599 | 0.580 |
| VDT Low | logit | 0.136 | 0.040 | 0.057 | 0.215 | 0.136 |
| VDT Low | prob | 0.534 | 0.010 | 0.514 | 0.554 | 0.534 |
| VDT High | logit | 0.165 | 0.040 | 0.086 | 0.244 | 0.165 |
| VDT High | prob | 0.541 | 0.010 | 0.521 | 0.561 | 0.541 |

**Interpretation:**
- **ADT Low (baseline)**: z = 0.573 (57.3% bias toward "Different" boundary)
- **VDT Low**: z = 0.534 (53.4% bias toward "Different" boundary)
- **Task contrast (VDT-ADT)**: Δ = -0.157 logit, P(Δ>0) = 0.000 (VDT has lower bias than ADT)

---

## 2. Standard-Only Bias Model - Bias Contrasts

| Contrast | Mean | SD | Q2.5 | Q97.5 | Pr(>0) | Pr(<0) | Pr(ROPE) |
|----------|------|----|----|----|--------|--------|----------|
| VDT - ADT (bias, logit) | -0.157 | 0.028 | -0.212 | -0.102 | 0.000 | 1.000 | 0.000 |
| High - Low (bias, logit) | 0.029 | 0.028 | -0.026 | 0.084 | 0.850 | 0.150 | 0.494 |

**Interpretation:**
- **Task effect**: VDT has significantly lower bias than ADT (Δ = -0.157 logit, 95% CrI: [-0.212, -0.102])
- **Effort effect**: No credible difference between High and Low effort (Δ = 0.029 logit, 95% CrI: [-0.026, 0.084])

---

## 3. Primary Model - Fixed Effects

**Model:** Primary model (17,834 total trials)  
**Total Parameters:** 16 fixed effects

### Drift Rate (v) - Identity Link

| Parameter | Estimate | CI Lower | CI Upper | Est.Error | Rhat | ESS |
|-----------|-----------|----------|----------|-----------|------|-----|
| Intercept (Standard) | -1.260 | -1.365 | -1.158 | 0.053 | 1.002 | 2165 |
| difficulty_levelHard | -0.616 | -0.674 | -0.558 | 0.030 | 1.001 | 4000 |
| difficulty_levelEasy | 3.323 | 3.214 | 3.432 | 0.056 | 1.001 | 4000 |
| taskVDT | 0.142 | 0.098 | 0.186 | 0.022 | 1.001 | 4000 |
| effort_conditionHigh_40_MVC | -0.052 | -0.084 | -0.020 | 0.017 | 1.001 | 4000 |

**Interpretation:**
- **Standard trials**: v = -1.260 (strong negative drift toward "Same")
- **Hard trials**: v = -1.260 + (-0.616) = -1.876 (even stronger negative drift)
- **Easy trials**: v = -1.260 + 3.323 = 2.063 (strong positive drift toward "Different")
- **Task effect**: VDT has slightly higher drift than ADT (Δ = 0.142)
- **Effort effect**: High effort has slightly lower drift than Low (Δ = -0.052)

### Boundary Separation (a/bs) - Log Link

| Parameter | Estimate (log) | CI Lower | CI Upper | Est.Error | Rhat | ESS |
|-----------|----------------|----------|----------|-----------|------|-----|
| bs_Intercept | 0.822 | 0.770 | 0.873 | 0.026 | 1.003 | 1152 |
| bs_difficulty_levelHard | -0.066 | -0.086 | -0.047 | 0.010 | 1.001 | 4000 |
| bs_difficulty_levelEasy | -0.131 | -0.153 | -0.109 | 0.011 | 1.001 | 4000 |
| bs_taskVDT | -0.060 | -0.075 | -0.044 | 0.008 | 1.001 | 4000 |

**On Natural Scale (a = exp(bs)):**
- **Standard trials**: a = exp(0.822) = 2.28
- **Hard trials**: a = exp(0.822 + (-0.066)) = exp(0.756) = 2.13
- **Easy trials**: a = exp(0.822 + (-0.131)) = exp(0.691) = 1.99
- **VDT**: a = exp(0.822 + (-0.060)) = exp(0.762) = 2.14

**Interpretation:**
- **Difficulty effect**: Hard and Easy trials have lower boundaries than Standard (more liberal)
- **Task effect**: VDT has slightly lower boundary than ADT (more liberal)

### Non-Decision Time (t₀/ndt) - Log Link

| Parameter | Estimate (log) | CI Lower | CI Upper | Est.Error | Rhat | ESS |
|-----------|----------------|----------|----------|-----------|------|-----|
| ndt_Intercept | -1.536 | -1.556 | -1.518 | 0.010 | 1.000 | 15848 |
| ndt_effort_conditionHigh_40_MVC | 0.023 | 0.006 | 0.040 | 0.009 | 1.001 | 4000 |
| ndt_taskVDT | 0.036 | 0.016 | 0.056 | 0.010 | 1.001 | 4000 |

**On Natural Scale (t₀ = exp(ndt)):**
- **ADT Low**: t₀ = exp(-1.536) = 0.215s
- **ADT High**: t₀ = exp(-1.536 + 0.023) = exp(-1.513) = 0.220s
- **VDT Low**: t₀ = exp(-1.536 + 0.036) = exp(-1.500) = 0.223s
- **VDT High**: t₀ = exp(-1.536 + 0.023 + 0.036) = exp(-1.477) = 0.229s

**Interpretation:**
- **Effort effect**: High effort increases NDT by ~0.005s
- **Task effect**: VDT increases NDT by ~0.008s compared to ADT

### Starting-Point Bias (z) - Logit Link

| Parameter | Estimate (logit) | CI Lower | CI Upper | Est.Error | Rhat | ESS |
|-----------|------------------|----------|----------|-----------|------|-----|
| bias_Intercept | 0.268 | 0.188 | 0.348 | 0.041 | 1.001 | 4765 |
| bias_difficulty_levelHard | -0.050 | -0.113 | 0.011 | 0.032 | 1.001 | 4000 |
| bias_difficulty_levelEasy | -0.078 | -0.145 | -0.011 | 0.034 | 1.001 | 4000 |
| bias_taskVDT | -0.062 | -0.106 | -0.018 | 0.022 | 1.001 | 4000 |

**On Natural Scale (z = inv_logit(bias)):**
- **Standard ADT**: z = inv_logit(0.268) = 0.567
- **Standard VDT**: z = inv_logit(0.268 + (-0.062)) = inv_logit(0.206) = 0.551
- **Hard ADT**: z = inv_logit(0.268 + (-0.050)) = inv_logit(0.218) = 0.554
- **Easy ADT**: z = inv_logit(0.268 + (-0.078)) = inv_logit(0.190) = 0.547

**Interpretation:**
- **Baseline (Standard ADT)**: z = 0.567 (56.7% bias toward "Different")
- **Difficulty effects**: Hard and Easy trials have slightly lower bias than Standard
- **Task effect**: VDT has lower bias than ADT (Δ = -0.062 logit)

---

## 4. Primary Model - Effect Contrasts

**Total Contrasts:** 15 (v=7, bs=3, ndt=2, bias=3)

### Drift Rate (v) Contrasts

| Contrast | Mean | SD | Q2.5 | Q97.5 | P(>0) | P(<0) | P(ROPE) | Credible |
|----------|------|----|----|----|-------|-------|---------|----------|
| Hard - Standard | -0.616 | 0.030 | -0.674 | -0.558 | 0.000 | 1.000 | 0.000 | credible |
| Hard (absolute) | -1.876 | 0.030 | -1.934 | -1.818 | 0.000 | 1.000 | 0.000 | credible |
| Easy - Standard | 3.323 | 0.056 | 3.214 | 3.432 | 1.000 | 0.000 | 0.000 | credible |
| Easy (absolute) | 2.063 | 0.055 | 1.954 | 2.172 | 1.000 | 0.000 | 0.000 | credible |
| Easy - Hard | 3.939 | 0.062 | 3.817 | 4.061 | 1.000 | 0.000 | 0.000 | credible |
| VDT - ADT | 0.142 | 0.023 | 0.098 | 0.186 | 1.000 | 0.000 | 0.000 | credible |
| High - Low | -0.052 | 0.017 | -0.084 | -0.020 | 0.001 | 0.999 | 0.026 | credible |

**Key Findings:**
- **Easy vs Hard**: Large positive difference (Δ = 3.939, 95% CrI: [3.817, 4.061])
- **Hard vs Standard**: Negative difference (Δ = -0.616, Hard has more negative drift)
- **Easy vs Standard**: Large positive difference (Δ = 3.323, Easy has strong positive drift)
- **Task effect**: VDT > ADT (Δ = 0.142, 95% CrI: [0.098, 0.186])
- **Effort effect**: High < Low (Δ = -0.052, 95% CrI: [-0.084, -0.020])

### Boundary Separation (bs) Contrasts

| Contrast | Mean | SD | Q2.5 | Q97.5 | P(>0) | P(<0) | P(ROPE) | Credible |
|----------|------|----|----|----|-------|-------|---------|----------|
| difficulty_levelHard | -0.066 | 0.010 | -0.086 | -0.047 | 0.000 | 1.000 | 0.000 | credible |
| difficulty_levelEasy | -0.131 | 0.011 | -0.153 | -0.109 | 0.000 | 1.000 | 0.000 | credible |
| taskVDT | -0.060 | 0.008 | -0.075 | -0.044 | 0.000 | 1.000 | 0.000 | credible |

**Key Findings:**
- **Hard vs Standard**: Lower boundary (Δ = -0.066 log, more liberal)
- **Easy vs Standard**: Lower boundary (Δ = -0.131 log, more liberal)
- **VDT vs ADT**: Lower boundary (Δ = -0.060 log, more liberal)

### Non-Decision Time (ndt) Contrasts

| Contrast | Mean | SD | Q2.5 | Q97.5 | P(>0) | P(<0) | P(ROPE) | Credible |
|----------|------|----|----|----|-------|-------|---------|----------|
| effort_conditionHigh_40_MVC | 0.023 | 0.009 | 0.006 | 0.040 | 0.996 | 0.004 | 0.000 | credible |
| taskVDT | 0.036 | 0.010 | 0.016 | 0.056 | 1.000 | 0.000 | 0.000 | credible |

**Key Findings:**
- **High vs Low effort**: Higher NDT (Δ = 0.023 log, ~0.005s increase)
- **VDT vs ADT**: Higher NDT (Δ = 0.036 log, ~0.008s increase)

### Starting-Point Bias (bias) Contrasts

| Contrast | Mean | SD | Q2.5 | Q97.5 | P(>0) | P(<0) | P(ROPE) | Credible |
|----------|------|----|----|----|-------|-------|---------|----------|
| difficulty_levelEasy | -0.078 | 0.034 | -0.145 | -0.011 | 0.012 | 0.988 | 0.210 | credible |
| difficulty_levelHard | -0.050 | 0.032 | -0.113 | 0.011 | 0.055 | 0.945 | 0.494 | not_credible |
| taskVDT | -0.062 | 0.022 | -0.106 | -0.018 | 0.003 | 0.997 | 0.295 | credible |

**Key Findings:**
- **Easy vs Standard**: Lower bias (Δ = -0.078 logit, 95% CrI: [-0.145, -0.011])
- **Hard vs Standard**: Not credible (Δ = -0.050 logit, 95% CrI: [-0.113, 0.011])
- **VDT vs ADT**: Lower bias (Δ = -0.062 logit, 95% CrI: [-0.106, -0.018])

---

## 5. Primary Model - Condition-Specific Parameters

**On Natural Scales** (transformed from link scales)

| Condition | Parameter | Mean | CI Lower | CI Upper |
|-----------|-----------|------|----------|----------|
| Standard | v (drift) | -1.260 | -1.365 | -1.158 | ✓ CORRECTED |
| Standard | a (boundary) | 2.28 | 2.16 | 2.39 |
| Standard | t₀ (NDT) | 0.215 | 0.211 | 0.219 |
| Standard | z (bias) | 0.567 | 0.547 | 0.586 |
| Hard | v (drift) | -1.876 | -1.934 | -1.818 |
| Hard | a (boundary) | 2.13 | 2.04 | 2.22 |
| Hard | t₀ (NDT) | 0.215 | 0.211 | 0.219 |
| Hard | z (bias) | 0.554 | 0.528 | 0.580 |
| Easy | v (drift) | 2.063 | 1.954 | 2.172 |
| Easy | a (boundary) | 1.99 | 1.90 | 2.08 |
| Easy | t₀ (NDT) | 0.215 | 0.211 | 0.219 |
| Easy | z (bias) | 0.547 | 0.523 | 0.571 |

**Key Patterns:**
- **Drift rate**: Standard (-1.26) < Hard (-1.88) < Easy (+2.06)
- **Boundary**: Easy (1.99) < Hard (2.13) < Standard (2.28) - Easy/Hard more liberal
- **NDT**: Constant across difficulty (0.215s)
- **Bias**: Relatively stable across difficulty (~0.55, slight bias toward "Different")

---

## 6. Statistical Hypothesis Tests

**All 8 hypothesis tests successful!**

| Hypothesis | Formula | Estimate | CI Lower | CI Upper | Probability Direction | Evidence Ratio |
|------------|---------|----------|----------|----------|---------------------|----------------|
| v_Easy_vs_Standard | difficulty_levelEasy = 0 | 3.323 | 3.214 | 3.432 | 1.000 | - |
| v_Hard_vs_Standard | difficulty_levelHard = 0 | -0.616 | -0.674 | -0.558 | 0.000 | - |
| v_VDT_vs_ADT | taskVDT = 0 | 0.142 | 0.098 | 0.186 | 1.000 | - |
| v_High_vs_Low | effort_conditionHigh_40_MVC = 0 | -0.052 | -0.084 | -0.020 | 0.000 | - |
| a_Easy_vs_Standard | bs_difficulty_levelEasy = 0 | -0.131 | -0.153 | -0.109 | 0.000 | - |
| a_Hard_vs_Standard | bs_difficulty_levelHard = 0 | -0.066 | -0.086 | -0.047 | 0.000 | - |
| z_VDT_vs_ADT | bias_taskVDT = 0 | -0.062 | -0.106 | -0.018 | 0.000 | - |
| z_Easy_vs_Standard | bias_difficulty_levelEasy = 0 | -0.078 | -0.145 | -0.011 | 0.012 | - |

**Interpretation:**
- **Drift effects**: All credible (Easy > Standard, Hard < Standard, VDT > ADT, High < Low)
- **Boundary effects**: Both credible (Easy < Standard, Hard < Standard)
- **Bias effects**: VDT < ADT credible, Easy < Standard credible

---

## 7. Effect Sizes

**Note:** For DDM, drift rate differences ARE the effect sizes (signal-to-noise ratio). Raw mean differences are reported.

### Drift Rate (v) Effect Sizes

| Contrast | Effect Size (Mean) | SD | Evidence Ratio | Effect Magnitude | P(>0) | P(<0) |
|----------|-------------------|----|----------------|------------------|-------|-------|
| Easy - Hard | 3.939 | 0.062 | 63.5 | large | 1.000 | 0.000 |
| Easy - Standard | 3.323 | 0.056 | 59.3 | large | 1.000 | 0.000 |
| Hard - Standard | -0.616 | 0.030 | -20.5 | medium | 0.000 | 1.000 |
| Easy (absolute) | 2.063 | 0.055 | 37.5 | large | 1.000 | 0.000 |
| Hard (absolute) | -1.876 | 0.030 | -62.5 | large | 0.000 | 1.000 |
| VDT - ADT | 0.142 | 0.023 | 6.2 | negligible | 1.000 | 0.000 |
| High - Low | -0.052 | 0.017 | -3.1 | negligible | 0.001 | 0.999 |

**Effect Magnitude Categories (for drift rate):**
- **Negligible**: |v| < 0.2
- **Small**: 0.2 ≤ |v| < 0.5
- **Medium**: 0.5 ≤ |v| < 1.0
- **Large**: |v| ≥ 1.0

**Key Findings:**
- **3 large drift effects**: Easy-Hard (3.94), Easy-Standard (3.32), Hard absolute (-1.88)
- **1 medium drift effect**: Hard-Standard (-0.62)
- **2 negligible drift effects**: VDT-ADT (0.14), High-Low (-0.05)

### Other Parameters (Effect Sizes on Link Scales)

For boundary, NDT, and bias parameters, effect sizes are on log/logit scales and don't map to standard effect size categories. Raw mean differences are reported:

- **Boundary**: Easy-Standard (Δ = -0.131 log), Hard-Standard (Δ = -0.066 log), VDT-ADT (Δ = -0.060 log)
- **NDT**: High-Low (Δ = 0.023 log), VDT-ADT (Δ = 0.036 log)
- **Bias**: Easy-Standard (Δ = -0.078 logit), Hard-Standard (Δ = -0.050 logit), VDT-ADT (Δ = -0.062 logit)

---

## Summary Statistics

### Model Convergence
- **Rhat**: All < 1.01 (excellent convergence)
- **ESS**: All > 1000 (sufficient effective sample size)

### Key Patterns
1. **Drift rate**: Strong negative on Standard/Hard, strong positive on Easy
2. **Boundary**: Lower (more liberal) on Easy/Hard compared to Standard
3. **NDT**: Slightly higher on VDT and High effort
4. **Bias**: Slight bias toward "Different" (~0.55), lower on VDT and Easy trials

---

**End of Summary**

