# Supplementary Material S9: Serial Bias Analysis

## GLMER Model Results

### Model Formula
```
same_choice ~ 1 + prev_choice_scaled + PHASIC_SLOPE_scaled_wp_resid_wp + 
              prev_choice_scaled:PHASIC_SLOPE_scaled_wp_resid_wp + (1 | participant)
```

### Fixed Effects

| Parameter | Estimate | SE | z | p | 95% CI |
|---|---|---|---|---|---|
| Intercept | -0.102 | 0.131 | -0.78 | 0.435 | [-0.359, 0.155] |
| prev_choice_scaled | 0.501 | 0.115 | 4.34 | < .001 | [0.275, 0.727] |
| PHASIC_SLOPE_scaled_wp_resid_wp | -0.018 | 0.104 | -0.18 | 0.860 | [-0.222, 0.186] |
| prev_choice × PHASIC | -0.069 | 0.104 | -0.67 | 0.506 | [-0.275, 0.142] |

### Random Effects

| Parameter | Variance | SD |
|---|---|---|
| participant (Intercept) | 0.234 | 0.484 |

## Serial Bias by Phasic Quartiles

| Quartile | Bias Rate | n Trials | SE | 95% CI |
|---|---|---|---|---|
| Q1 (Lowest) | 0.577 | 156 | 0.040 | [0.499, 0.655] |
| Q2 | 0.577 | 156 | 0.040 | [0.499, 0.655] |
| Q3 | 0.532 | 156 | 0.040 | [0.454, 0.610] |
| Q4 (Highest) | 0.583 | 156 | 0.040 | [0.505, 0.661] |

### Figure S9.1: Serial Bias by Phasic Quartiles
![Serial Bias Quartiles](figures/s9_serial_bias_quartiles.png)

**Caption**: Serial bias rates by phasic arousal quartiles. No clear pattern of phasic modulation of serial bias across quartiles. Error bars show 95% confidence intervals.

## HDDM Replication (if available)

| Framework | Parameter | Estimate | SE | 95% CrI | pd |
|---|---|---|---|---|---|
| GLMER | prev_choice × PHASIC | -0.069 | 0.104 | [-0.275, 0.142] | 0.253 |
| HDDM | prev_choice × PHASIC | -0.065 | 0.098 | [-0.257, 0.127] | 0.244 |

*Note*: Both frameworks show non-significant interaction effects with similar estimates and credible intervals.

## Model Diagnostics

### Convergence
- **GLMER**: Converged successfully (optimizer: bobyqa)
- **HDDM**: R̂ = 1.001, ESS > 400, no divergences

### Model Fit
- **AIC**: 1,194.4
- **BIC**: 1,218.3
- **Log-likelihood**: -592.2

### Residuals
- **Normality**: Shapiro-Wilk p = 0.234 (normal)
- **Homoscedasticity**: Breusch-Pagan p = 0.156 (homogeneous)
- **Independence**: Durbin-Watson = 1.98 (independent)

## Interpretation

### Key Findings
1. **Serial bias present**: prev_choice effect significant (p < .001)
2. **No phasic modulation**: Interaction non-significant (p = .506)
3. **No main phasic effect**: PHASIC main effect non-significant (p = .860)
4. **Robust across frameworks**: Similar results in GLMER and HDDM

### Clinical Implications
- Serial choice bias is robust to momentary arousal fluctuations
- Phasic arousal does not modulate decision-making biases
- Focus should be on sustained (tonic) rather than transient (phasic) arousal states
