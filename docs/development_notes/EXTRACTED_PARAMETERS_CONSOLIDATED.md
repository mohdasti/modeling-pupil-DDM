# Extracted DDM Parameters - Consolidated Summary

**Date:** 
2025-11-26
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

```
# A tibble: 8 × 7
  param         scale  mean     sd    q2.5 q97.5 median
  <chr>         <chr> <dbl>  <dbl>   <dbl> <dbl>  <dbl>
1 bias_ADT_Low  logit 0.293 0.0673 0.161   0.424  0.294
2 bias_ADT_Low  prob  0.573 0.0165 0.540   0.604  0.573
3 bias_ADT_High logit 0.322 0.0675 0.189   0.454  0.323
4 bias_ADT_High prob  0.580 0.0164 0.547   0.612  0.580
5 bias_VDT_Low  logit 0.136 0.0666 0.00389 0.266  0.137
6 bias_VDT_Low  prob  0.534 0.0166 0.501   0.566  0.534
7 bias_VDT_High logit 0.165 0.0665 0.0346  0.296  0.165
8 bias_VDT_High prob  0.541 0.0165 0.509   0.573  0.541
```

**Key Interpretation:**
- ADT Low (baseline): z = 0.573 (57.3% bias toward 'Different' boundary)
- VDT Low: z = 0.534 (53.4% bias toward 'Different' boundary)

---

## 2. Standard-Only Bias Model - Bias Contrasts

```
# A tibble: 2 × 8
  contrast                   mean     sd    q2.5   q97.5 Pr_gt_0 Pr_lt_0 Pr_rope
  <chr>                     <dbl>  <dbl>   <dbl>   <dbl>   <dbl>   <dbl>   <dbl>
1 VDT - ADT (bias, logit) -0.157  0.0388 -0.232  -0.0814 6.25e-5   1.00  0.00388
2 High - Low (bias, logi…  0.0287 0.0362 -0.0426  0.101  7.87e-1   0.213 0.709  
```

---

## 3. Primary Model - Fixed Effects

**Model:** Primary model (17,834 total trials)
**Total Parameters:** 16 fixed effects

### All Fixed Effects

```
# A tibble: 16 × 7
   parameter                  estimate conf.low conf.high est.error  rhat    ess
   <chr>                         <dbl>    <dbl>     <dbl>     <dbl> <dbl>  <dbl>
 1 Intercept                   -1.26   -1.37      -1.16     0.0528   1.00  2165.
 2 bs_Intercept                 0.822   0.770      0.873    0.0263   1.00  1152.
 3 ndt_Intercept               -1.54   -1.56      -1.52     0.00974  1.00 15848.
 4 bias_Intercept               0.268   0.188      0.348    0.0409   1.00  4765.
 5 difficulty_levelHard         0.616   0.558      0.674    0.0297   1.00 10598.
 6 difficulty_levelEasy         2.17    2.11       2.23     0.0320   1.00 10789.
 7 taskVDT                      0.142   0.0980     0.186    0.0226   1.00 15672.
 8 effort_conditionHigh_40_M…  -0.0520 -0.0838    -0.0197   0.0166   1.00 21386.
 9 bs_difficulty_levelHard     -0.0664 -0.0859    -0.0469   0.00998  1.00 14230.
10 bs_difficulty_levelEasy     -0.131  -0.153     -0.109    0.0112   1.00 14448.
11 bs_taskVDT                  -0.0596 -0.0746    -0.0448   0.00762  1.00 18206.
12 ndt_taskVDT                  0.0359  0.0160     0.0563   0.0102   1.00 17447.
13 ndt_effort_conditionHigh_…   0.0227  0.00582    0.0394   0.00860  1.00 22738.
14 bias_difficulty_levelHard   -0.0504 -0.113      0.0113   0.0317   1.00 10589.
15 bias_difficulty_levelEasy   -0.0780 -0.145     -0.0110   0.0344   1.00 10652.
16 bias_taskVDT                -0.0620 -0.106     -0.0185   0.0224   1.00 14429.
```

---

## 4. Primary Model - Effect Contrasts

**Total Contrasts:** 15 (v=7, bs=3, ndt=2, bias=3)

### All Effect Contrasts

```
# A tibble: 15 × 12
   contrast parameter    mean      sd      q05      q95     q2.5   q97.5   p_gt0
   <chr>    <chr>       <dbl>   <dbl>    <dbl>    <dbl>    <dbl>   <dbl>   <dbl>
 1 difficu… bias      -0.0780 0.0344  -0.134   -0.0218  -0.145   -0.0110 0.0121 
 2 difficu… bias      -0.0504 0.0317  -0.103    0.00144 -0.113    0.0113 0.0548 
 3 taskVDT  bias      -0.0620 0.0224  -0.0989  -0.0253  -0.106   -0.0185 0.00262
 4 difficu… bs        -0.131  0.0112  -0.149   -0.112   -0.153   -0.109  0      
 5 difficu… bs        -0.0664 0.00998 -0.0827  -0.0501  -0.0859  -0.0469 0      
 6 taskVDT  bs        -0.0596 0.00762 -0.0719  -0.0472  -0.0746  -0.0448 0      
 7 effort_… ndt        0.0227 0.00860  0.00854  0.0368   0.00582  0.0394 0.996  
 8 taskVDT  ndt        0.0359 0.0102   0.0192   0.0528   0.0160   0.0563 1.00   
 9 Easy (a… v          0.910  0.0497   0.829    0.992    0.811    1.01   1      
10 Easy - … v          1.55   0.0256   1.51     1.60     1.50     1.60   1      
11 Easy - … v          2.17   0.0320   2.12     2.22     2.11     2.23   1      
12 Hard (a… v         -0.643  0.0490  -0.724   -0.564   -0.740   -0.546  0      
13 Hard - … v          0.616  0.0297   0.567    0.665    0.558    0.674  1      
14 High - … v         -0.0520 0.0166  -0.0790  -0.0247  -0.0838  -0.0197 0.001  
15 VDT - A… v          0.142  0.0226   0.105    0.180    0.0980   0.186  1      
# ℹ 3 more variables: p_lt0 <dbl>, p_in_rope <dbl>, credible <chr>
```

---

## 5. Primary Model - Condition-Specific Parameters

**On Natural Scales** (transformed from link scales)

```
# A tibble: 12 × 5
   condition parameter   mean ci_lower ci_upper
   <chr>     <chr>      <dbl>    <dbl>    <dbl>
 1 Standard  v         -1.26    -1.37    -1.16 
 2 Standard  a          2.28     2.16     2.39 
 3 Standard  t0         0.215    0.211    0.219
 4 Standard  z          0.567    0.547    0.586
 5 Hard      v         -0.643   -0.740   -0.546
 6 Hard      a          2.13     2.02     2.23 
 7 Hard      t0         0.215    0.211    0.219
 8 Hard      z          0.554    0.537    0.571
 9 Easy      v          0.910    0.811    1.01 
10 Easy      a          2.00     1.90     2.10 
11 Easy      t0         0.215    0.211    0.219
12 Easy      z          0.547    0.529    0.565
```

---

## 6. Statistical Hypothesis Tests

**Total Tests:** 8

```
# A tibble: 8 × 8
  hypothesis         formula    estimate ci_lower ci_upper probability_direction
  <chr>              <chr>         <dbl>    <dbl>    <dbl> <lgl>                
1 v_Easy_vs_Standard difficult…   2.17     2.11     2.23   NA                   
2 v_Hard_vs_Standard difficult…   0.616    0.558    0.674  NA                   
3 v_VDT_vs_ADT       taskVDT =…   0.142    0.0980   0.186  NA                   
4 v_High_vs_Low      effort_co…  -0.0520  -0.0838  -0.0197 NA                   
5 a_Easy_vs_Standard bs_diffic…  -0.131   -0.153   -0.109  NA                   
6 a_Hard_vs_Standard bs_diffic…  -0.0664  -0.0859  -0.0469 NA                   
7 z_VDT_vs_ADT       bias_task…  -0.0620  -0.106   -0.0185 NA                   
8 z_Easy_vs_Standard bias_diff…  -0.0780  -0.145   -0.0110 NA                   
# ℹ 2 more variables: evidence_ratio <lgl>, star <chr>
```

---

## 7. Effect Sizes

**Note:** For DDM, drift rate differences ARE the effect sizes (signal-to-noise ratio). Raw mean differences are reported.

```
# A tibble: 15 × 13
   contrast                  parameter effect_size_mean      sd     q2.5   q97.5
   <chr>                     <chr>                <dbl>   <dbl>    <dbl>   <dbl>
 1 difficulty_levelEasy      bias               -0.0780 0.0344  -0.145   -0.0110
 2 difficulty_levelHard      bias               -0.0504 0.0317  -0.113    0.0113
 3 taskVDT                   bias               -0.0620 0.0224  -0.106   -0.0185
 4 difficulty_levelEasy      bs                 -0.131  0.0112  -0.153   -0.109 
 5 difficulty_levelHard      bs                 -0.0664 0.00998 -0.0859  -0.0469
 6 taskVDT                   bs                 -0.0596 0.00762 -0.0746  -0.0448
 7 effort_conditionHigh_40_… ndt                 0.0227 0.00860  0.00582  0.0394
 8 taskVDT                   ndt                 0.0359 0.0102   0.0160   0.0563
 9 Easy (absolute)           v                   0.910  0.0497   0.811    1.01  
10 Easy - Hard               v                   1.55   0.0256   1.50     1.60  
11 Easy - Standard           v                   2.17   0.0320   2.11     2.23  
12 Hard (absolute)           v                  -0.643  0.0490  -0.740   -0.546 
13 Hard - Standard           v                   0.616  0.0297   0.558    0.674 
14 High - Low                v                  -0.0520 0.0166  -0.0838  -0.0197
15 VDT - ADT                 v                   0.142  0.0226   0.0980   0.186 
# ℹ 7 more variables: probability_direction <dbl>, evidence_ratio_stat <dbl>,
#   effect_magnitude <chr>, p_gt0 <dbl>, p_lt0 <dbl>, p_in_rope <dbl>,
#   credible <chr>
```

### Effect Size Summary

- **Large drift effects (|v| ≥ 1.0):** 2
- **Medium drift effects (0.5 ≤ |v| < 1.0):** 3
- **Small drift effects (0.2 ≤ |v| < 0.5):** 0
- **Negligible drift effects (|v| < 0.2):** 2

---

## Summary Statistics

### Model Convergence
- **Rhat:** All < 1.01 (excellent convergence)
- **ESS:** All > 1000 (sufficient effective sample size)

### Key Patterns
1. **Drift rate:** Strong negative on Standard/Hard, strong positive on Easy
2. **Boundary:** Lower (more liberal) on Easy/Hard compared to Standard
3. **NDT:** Slightly higher on VDT and High effort
4. **Bias:** Slight bias toward 'Different' (~0.55), lower on VDT and Easy trials

---

**End of Summary**
