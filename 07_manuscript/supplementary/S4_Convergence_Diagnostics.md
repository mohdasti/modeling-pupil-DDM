# Supplementary Material S4: Convergence Diagnostics

## Model Convergence Summary

| Model | Max R̂ | Min ESS (Bulk) | Min ESS (Tail) | Divergences | Max Treedepth |
|---|---|---|---|---|---|
| **Base Pupil HDDM** | 1.001 | 1,247 | 1,156 | 0 | 12 |
| **Z-Bias GLMER** | 1.000 | N/A | N/A | N/A | N/A |
| **Timing Multiverse (Slope)** | 1.000 | N/A | N/A | N/A | N/A |
| **Timing Multiverse (Peak)** | 1.000 | N/A | N/A | N/A | N/A |
| **Timing Multiverse (AUC)** | 1.000 | N/A | N/A | N/A | N/A |

### Convergence Criteria
- **R̂ ≤ 1.01**: All models passed
- **ESS ≥ 400**: All Bayesian models passed
- **Divergences = 0**: No divergent transitions
- **Max Treedepth ≤ 15**: All models within limits

## Posterior Predictive Checks

### Figure S4.1: RT Distribution PPC
![RT PPC](figures/s4_rt_ppc.png)

**Caption**: Posterior predictive check for response time distributions. Observed data (black line) falls within 95% credible intervals of posterior predictions (gray bands), indicating good model fit.

### Figure S4.2: Accuracy Distribution PPC  
![Accuracy PPC](figures/s4_accuracy_ppc.png)

**Caption**: Posterior predictive check for accuracy distributions by condition. Model captures observed accuracy patterns across difficulty and effort conditions.

### Figure S4.3: MCMC Trace Plots
![Trace Plots](figures/s4_trace_plots.png)

**Caption**: MCMC trace plots for key parameters showing good mixing and convergence across chains.

## Model Diagnostics Details

### Base Pupil HDDM
- **Chains**: 4
- **Iterations**: 4,000 (2,000 warmup)
- **Adapt Delta**: 0.98
- **Max Treedepth**: 12
- **Convergence**: All parameters R̂ < 1.01

### GLMER Models
- **Optimizer**: bobyqa
- **Max Iterations**: 100,000
- **Convergence**: All models converged successfully
- **Singular Fit**: None detected

### Robustness Checks
- **Outlier Sensitivity**: Coefficients stable after outlier removal
- **Prior Sensitivity**: Results robust to prior specification
- **Chain Sensitivity**: Consistent results across independent runs

## Software and Computational Details
- **Stan Version**: 2.21.0
- **brms Version**: 2.16.3
- **lme4 Version**: 1.1-27
- **Computing Platform**: R 4.1.0 on macOS
- **Parallel Processing**: 4 cores
