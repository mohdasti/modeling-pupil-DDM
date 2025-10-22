# Supplementary Material S7: Feature×Window Model Comparison

## AIC and Stacking Weights

| Feature | Window | AIC | AIC Weight | Stacking Weight | ΔAIC | Best Model |
|---|---|---|---|---|---|---|
| **slope** | 200-900 ms | 1,194.4 | **0.922** | **0.922** | 0.0 | slope_wp_resid |
| early | 200-700 ms | 1,202.0 | 0.021 | 0.021 | 7.6 | early_wp_resid |
| late | 700-1500 ms | 1,202.0 | 0.021 | 0.021 | 7.6 | late_wp_resid |
| AUC | 300-1200 ms | 1,202.1 | 0.020 | 0.020 | 7.7 | AUC_wp_resid |
| peak | 300-1200 ms | 1,202.5 | 0.016 | 0.016 | 8.1 | peak_wp_resid |

## Stacking Weights Bar Chart

### Figure S7.1: Model Selection Weights
![Stacking Weights](figures/s7_stacking_weights.png)

**Caption**: Bar chart showing AIC weights (equivalent to stacking weights) for phasic feature models. Slope feature (200-900 ms) dominates with 92.2% weight, while all alternative features show minimal support (≤2.1%).

## Model-Averaged Coefficients

| Parameter | Model-Averaged Estimate | Model-Averaged SE | 95% CI | Weighted p |
|---|---|---|---|---|
| **Phasic main effect** | -0.141 | 0.082 | [-0.302, 0.020] | 0.085 |
| **Serial bias interaction** | -0.069 | 0.104 | [-0.275, 0.142] | 0.506 |

## Timing Window Analysis

### Early Window (200-700 ms)
- **AIC Weight**: 0.021
- **Interpretation**: Minimal support for early phasic effects
- **Coefficients**: Not estimable (model convergence issues)

### Late Window (700-1500 ms)  
- **AIC Weight**: 0.021
- **Interpretation**: Minimal support for late phasic effects
- **Coefficients**: Not estimable (model convergence issues)

### Peak Window (300-1200 ms)
- **AIC Weight**: 0.016
- **Main Effect**: β = 0.152, SE = 0.090, p = .090
- **Interaction**: β = 0.025, SE = 0.090, p = .784

### AUC Window (300-1200 ms)
- **AIC Weight**: 0.020
- **Main Effect**: β = 0.170, SE = 0.090, p = .059
- **Interaction**: β = 0.006, SE = 0.090, p = .945

## Robustness Across Windows

| Window | Slope Estimate | Slope SE | Slope p | Interaction Estimate | Interaction SE | Interaction p |
|---|---|---|---|---|---|---|
| 200-900 ms | -0.141 | 0.082 | 0.085 | -0.069 | 0.104 | 0.506 |
| 300-1200 ms (peak) | 0.152 | 0.090 | 0.090 | 0.025 | 0.090 | 0.784 |
| 300-1200 ms (AUC) | 0.170 | 0.090 | 0.059 | 0.006 | 0.090 | 0.945 |

*Note*: Slope window shows negative main effect (exploratory), while peak/AUC windows show positive effects. All interaction effects non-significant across windows.
