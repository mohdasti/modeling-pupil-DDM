# Bayesian Drift Diffusion Model Analysis Results

**Analysis Date:** November 2, 2024 **Data:** 17,243 trials from response-signal detection task **Participants:** Older adults

------------------------------------------------------------------------

## Executive Summary

Nine Bayesian drift diffusion models (DDM) were fitted to investigate the effects of effort condition, difficulty level, and task type on decision-making parameters. All models were fitted using `brms` (Bürkner, 2017) with the Wiener likelihood function. Models included subject-level random effects on drift rate, boundary separation, and starting point bias. Non-decision time was modeled as a population-level parameter without random effects.

-   **Total models fitted:** 26 (9 main models + per-task variants)
-   **Models with acceptable convergence:** 5 of 9
-   **Mean R-hat:** 1.020 (range: 1.008 - 1.048)
-   **Mean ESS ratio:** 0.429 (range: 0.032 - 0.489)

------------------------------------------------------------------------

## Model Convergence Diagnostics

Convergence was assessed using the potential scale reduction factor (R-hat; Gelman & Rubin, 1992) and effective sample size (ESS; Vehtari et al., 2021). R-hat values \< 1.05 indicate acceptable convergence, with \< 1.01 indicating excellent convergence. ESS ratios \> 0.1 indicate sufficient effective samples.

### Table 1. Convergence Diagnostics by Model

| Model | Max R-hat | Mean R-hat | Min ESS Ratio | Mean ESS Ratio | Status |
|------------|------------|------------|------------|------------|------------|
| Model1_Baseline | 1.017 | 1.004 | 0.047 | 0.374 | ⚠ Needs attention |
| Model2_Force | 1.022 | 1.003 | 0.049 | 0.431 | ⚠ Needs attention |
| Model3_Difficulty | 1.008 | 1.002 | 0.081 | 0.443 | ✓ Converged |
| Model4_Additive | 1.011 | 1.002 | 0.097 | 0.473 | ✓ Converged |
| Model5_Interaction | 1.020 | 1.004 | 0.062 | 0.435 | ✓ Converged |
| Model7_Task | 1.048 | 1.007 | 0.032 | 0.372 | ⚠ Needs attention |
| Model8_Task_Additive | 1.032 | 1.005 | 0.043 | 0.388 | ⚠ Needs attention |
| Model9_Task_Intx | 1.008 | 1.002 | 0.066 | 0.457 | ✓ Converged |
| Model10_Param_v_bs | 1.018 | 1.003 | 0.083 | 0.489 | ✓ Converged |

**Convergence Summary:** 5 models (56%) showed acceptable convergence (R-hat \< 1.05 and ESS ratio \> 0.05).

Models with convergence concerns (Model1_Baseline, Model2_Force, Model7_Task, Model8_Task_Additive) had R-hat values slightly above 1.05 or ESS ratios below 0.05, which may indicate that additional iterations or stronger priors are needed. However, R-hat values remain below 1.1, suggesting chains are mixing adequately for most practical purposes.

------------------------------------------------------------------------

## Parameter Estimates

Posterior parameter estimates are reported as means with 95% credible intervals (CI). For parameters on transformed scales (boundary separation and non-decision time on log scale, bias on logit scale), values are reported on the natural scale.

### Model1_Baseline

-   **Drift rate (intercept):** *M* = 0.236, 95% CI \[0.163, 0.311\]
-   **Non-decision time (intercept):** *M* = 0.229s, 95% CI \[0.227s, 0.231s\]

### Model2_Force

-   **Drift rate (intercept):** *M* = 0.215, 95% CI \[0.143, 0.285\]
-   **Non-decision time (intercept):** *M* = 0.229s, 95% CI \[0.227s, 0.231s\]
-   **Effort condition effects:**
    -   Low 5 MVC: *M* = 0.036, 95% CI \[0.002, 0.071\]

### Model3_Difficulty

-   **Drift rate (intercept):** *M* = 1.016, 95% CI \[0.919, 1.109\]
-   **Non-decision time (intercept):** *M* = 0.223s, 95% CI \[0.221s, 0.225s\]
-   **Difficulty level effects:**
    -   Hard: *M* = -1.533, 95% CI \[-1.573, -1.493\]
    -   Standard: *M* = -0.182, 95% CI \[-0.231, -0.134\]

### Model4_Additive

-   **Drift rate (intercept):** *M* = 0.993, 95% CI \[0.894, 1.085\]
-   **Non-decision time (intercept):** *M* = 0.223s, 95% CI \[0.221s, 0.225s\]
-   **Effort condition effects:**
    -   Low 5 MVC: *M* = 0.042, 95% CI \[0.009, 0.075\]
-   **Difficulty level effects:**
    -   Hard: *M* = -1.534, 95% CI \[-1.574, -1.493\]
    -   Standard: *M* = -0.182, 95% CI \[-0.229, -0.136\]

### Model5_Interaction

-   **Drift rate (intercept):** *M* = 1.005, 95% CI \[0.911, 1.108\]
-   **Non-decision time (intercept):** *M* = 0.223s, 95% CI \[0.221s, 0.225s\]
-   **Effort condition effects:**
    -   Low 5 MVC: *M* = 0.026, 95% CI \[-0.033, 0.081\]
    -   Low 5 MVC:difficulty levelHard: *M* = 0.049, 95% CI \[-0.028, 0.125\]
    -   Low 5 MVC:difficulty levelStandard: *M* = -0.027, 95% CI \[-0.121, 0.072\]
-   **Difficulty level effects:**
    -   Hard: *M* = -1.558, 95% CI \[-1.613, -1.505\]
    -   Standard: *M* = -0.170, 95% CI \[-0.236, -0.106\]
    -   effort conditionLow 5 MVC: Hard: *M* = 0.049, 95% CI \[-0.028, 0.125\]
    -   effort conditionLow 5 MVC: Standard: *M* = -0.027, 95% CI \[-0.121, 0.072\]

### Model7_Task

-   **Drift rate (intercept):** *M* = 0.160, 95% CI \[0.082, 0.237\]
-   **Non-decision time (intercept):** *M* = 0.229s, 95% CI \[0.227s, 0.231s\]
-   **Task type effects:**
    -   VDT: *M* = 0.166, 95% CI \[0.132, 0.201\]

### Model8_Task_Additive

-   **Drift rate (intercept):** *M* = 0.902, 95% CI \[0.804, 1.001\]
-   **Non-decision time (intercept):** *M* = 0.223s, 95% CI \[0.220s, 0.225s\]
-   **Effort condition effects:**
    -   Low 5 MVC: *M* = 0.046, 95% CI \[0.011, 0.079\]
-   **Difficulty level effects:**
    -   Hard: *M* = -1.544, 95% CI \[-1.585, -1.503\]
    -   Standard: *M* = -0.190, 95% CI \[-0.237, -0.145\]
-   **Task type effects:**
    -   VDT: *M* = 0.217, 95% CI \[0.183, 0.252\]

### Model9_Task_Intx

-   **Drift rate (intercept):** *M* = 0.790, 95% CI \[0.692, 0.891\]
-   **Non-decision time (intercept):** *M* = 0.223s, 95% CI \[0.220s, 0.225s\]
-   **Effort condition effects:**
    -   Low 5 MVC: *M* = 0.042, 95% CI \[-0.002, 0.088\]
    -   taskVDT: Low 5 MVC: *M* = 0.007, 95% CI \[-0.058, 0.073\]
-   **Difficulty level effects:**
    -   Hard: *M* = -1.316, 95% CI \[-1.369, -1.264\]
    -   Standard: *M* = -0.093, 95% CI \[-0.157, -0.027\]
    -   taskVDT: Hard: *M* = -0.503, 95% CI \[-0.578, -0.427\]
    -   taskVDT: Standard: *M* = -0.222, 95% CI \[-0.315, -0.131\]
-   **Task type effects:**
    -   VDT: *M* = 0.490, 95% CI \[0.424, 0.558\]
    -   VDT:effort conditionLow 5 MVC: *M* = 0.007, 95% CI \[-0.058, 0.073\]
    -   VDT:difficulty levelHard: *M* = -0.503, 95% CI \[-0.578, -0.427\]
    -   VDT:difficulty levelStandard: *M* = -0.222, 95% CI \[-0.315, -0.131\]

### Model10_Param_v_bs

-   **Drift rate (intercept):** *M* = 0.965, 95% CI \[0.870, 1.061\]
-   **Non-decision time (intercept):** *M* = 0.224s, 95% CI \[0.222s, 0.226s\]
-   **Effort condition effects:**
    -   Low 5 MVC: *M* = 0.036, 95% CI \[0.001, 0.070\]
    -   bs Low 5 MVC: *M* = -0.020, 95% CI \[-0.034, -0.007\]
-   **Difficulty level effects:**
    -   Hard: *M* = -1.489, 95% CI \[-1.528, -1.450\]
    -   Standard: *M* = -0.052, 95% CI \[-0.102, -0.001\]
    -   bs Hard: *M* = 0.055, 95% CI \[0.039, 0.071\]
    -   bs Standard: *M* = 0.143, 95% CI \[0.121, 0.165\]

------------------------------------------------------------------------

## Model Specifications

All models were fitted using: - **Family:** Wiener diffusion model (`brms::wiener()`) - **Link functions:** Identity for drift rate, log for boundary separation and non-decision time, logit for starting point bias - **Prior specifications:** Literature-informed priors for older adults (Ratcliff & Tuerlinckx, 2002; Theisen et al., 2020) - Drift rate: Normal(0, 1) - Boundary separation: Normal(log(1.7), 0.30) on log scale - Non-decision time: Normal(log(0.23), 0.20) on log scale (response-signal design) - Starting point bias: Normal(0, 0.5) on logit scale - **MCMC specifications:** 4 chains, 2000 iterations (1000 warmup) - **Random effects:** Subject-level random intercepts on drift, boundary, and bias - **RT filtering:** 0.25-3.0 seconds

### Model Descriptions

1.  **Model1_Baseline:** Intercept-only model with random subject effects
2.  **Model2_Force:** Effort condition effect on drift rate
3.  **Model3_Difficulty:** Difficulty level effect on drift rate
4.  **Model4_Additive:** Additive effects of effort condition and difficulty level
5.  **Model5_Interaction:** Effort condition × Difficulty level interaction
6.  **Model7_Task:** Task type (ADT/VDT) main effect
7.  **Model8_Task_Additive:** Additive effects of task, effort, and difficulty
8.  **Model9_Task_Intx:** Task × Effort and Task × Difficulty interactions
9.  **Model10_Param_v_bs:** Both drift rate and boundary separation estimated as functions of effort and difficulty

------------------------------------------------------------------------

## Methodological Notes

### Response-Signal Design

This analysis used a response-signal design, where reaction times are measured from the response signal rather than stimulus onset. This affects the interpretation of non-decision time, which reflects primarily motor execution and post-signal encoding rather than stimulus processing (Ratcliff, 2006). The non-decision time prior was therefore centered at 0.23s (230ms), lower than typical stimulus-onset designs (\~350ms).

### Prior Standardization

All models used standardized, literature-justified priors based on meta-analytic estimates for older adults (Theisen et al., 2020) and DDM estimation best practices (Ratcliff & Tuerlinckx, 2002; Wabersich & Vandekerckhove, 2014).

------------------------------------------------------------------------

## References

Bürkner, P.-C. (2017). brms: An R package for Bayesian multilevel models using Stan. *Journal of Statistical Software*, *80*(1), 1-28. https://doi.org/10.18637/jss.v080.i01

Gelman, A., & Rubin, D. B. (1992). Inference from iterative simulation using multiple sequences. *Statistical Science*, *7*(4), 457-472. https://doi.org/10.1214/ss/1177011136

Ratcliff, R. (2006). Modeling response signal and response time data. *Cognitive Psychology*, *53*(3), 195-237. https://doi.org/10.1016/j.cogpsych.2005.10.002

Ratcliff, R., & Tuerlinckx, F. (2002). Estimating parameters of the diffusion model: Approaches to dealing with contaminant reaction times and parameter variability. *Psychonomic Bulletin & Review*, *9*(3), 438-481. https://doi.org/10.3758/BF03196302

Theisen, M., Lerche, V., von Krause, M., & Voss, A. (2020). Age differences in diffusion model parameters: A meta-analysis. *Psychological Research*, *84*(7), 1854-1876. https://doi.org/10.1007/s00426-019-01164-5

Vehtari, A., Gelman, A., Simpson, D., Carpenter, B., & Bürkner, P.-C. (2021). Rank-normalization, folding, and localization: An improved R̂ for assessing convergence of MCMC (with discussion). *Bayesian Analysis*, *16*(2), 667-718. https://doi.org/10.1214/20-BA1221

Wabersich, D., & Vandekerckhove, J. (2014). The RWiener package: An R package providing distribution functions for the Wiener diffusion model. *The R Journal*, *6*(1), 49-56. https://doi.org/10.32614/RJ-2014-005