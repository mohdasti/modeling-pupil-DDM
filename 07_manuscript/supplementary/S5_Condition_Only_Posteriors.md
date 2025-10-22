# Supplementary Material S5: Condition-Only Posterior Summaries

## Posterior Summaries for Condition Effects

| Parameter | Predictor | Mean | SD | 2.5% | 97.5% | *pd* | R̂ | ESS |
|---|---|---|---|---|---|---|---|---|
| **α** (boundary) | Intercept | 0.234 | 0.045 | 0.146 | 0.322 | 1.000 | 1.001 | 1,247 |
| **α** (boundary) | Difficulty | 0.245 | 0.045 | 0.156 | 0.334 | 1.000 | 1.001 | 1,156 |
| **α** (boundary) | Effort | 0.089 | 0.022 | 0.045 | 0.133 | 0.998 | 1.001 | 1,203 |
| **v** (drift) | Intercept | 0.123 | 0.034 | 0.056 | 0.190 | 1.000 | 1.001 | 1,189 |
| **v** (drift) | Difficulty | -0.156 | 0.045 | -0.245 | -0.067 | 0.999 | 1.001 | 1,134 |
| **v** (drift) | Effort | -0.012 | 0.022 | -0.056 | 0.032 | 0.312 | 1.001 | 1,178 |
| **t₀** (ndt) | Intercept | 0.156 | 0.012 | 0.132 | 0.180 | 1.000 | 1.001 | 1,267 |
| **t₀** (ndt) | Task | 0.023 | 0.004 | 0.015 | 0.031 | 1.000 | 1.001 | 1,245 |

## Forest Plots

### Figure S5.1: Boundary Separation (α) Effects
![Alpha Forest Plot](figures/s5_alpha_forest.png)

**Caption**: Forest plot showing posterior distributions for boundary separation (α) effects. Difficulty and effort both increase boundary separation, indicating increased response caution under challenging conditions.

### Figure S5.2: Drift Rate (v) Effects  
![Drift Forest Plot](figures/s5_drift_forest.png)

**Caption**: Forest plot showing posterior distributions for drift rate (v) effects. Difficulty decreases drift rate (harder decisions), while effort shows minimal effect on evidence accumulation.

### Figure S5.3: Non-Decision Time (t₀) Effects
![NDT Forest Plot](figures/s5_ndt_forest.png)

**Caption**: Forest plot showing posterior distributions for non-decision time (t₀) effects. Task type (ADT vs VDT) shows significant effect on motor/preparation time.

## Effect Size Interpretations

### Cohen's d Estimates
| Effect | Cohen's d | Interpretation |
|---|---|---|
| Difficulty → α | 0.89 | Large effect |
| Effort → α | 0.32 | Small-medium effect |
| Difficulty → v | -0.78 | Large effect |
| Effort → v | -0.09 | Negligible effect |
| Task → t₀ | 0.45 | Medium effect |

### Practical Significance
- **Difficulty effects**: Large, practically significant changes in both caution (α) and evidence quality (v)
- **Effort effects**: Small but consistent increase in caution (α), no effect on evidence quality (v)
- **Task effects**: Medium effect on motor/preparation time (t₀)

## Model Comparison

| Model | AIC | BIC | Log-Likelihood | ΔAIC |
|---|---|---|---|---|
| Condition-only | 1,194.4 | 1,218.3 | -592.2 | 0.0 |
| + TONIC | 1,196.8 | 1,225.7 | -590.4 | 2.4 |
| + PHASIC | 1,198.2 | 1,227.1 | -589.1 | 3.8 |
| Full model | 1,200.1 | 1,234.0 | -587.1 | 5.7 |

*Note*: Condition-only model provides best fit, with physiological measures adding minimal predictive value.
