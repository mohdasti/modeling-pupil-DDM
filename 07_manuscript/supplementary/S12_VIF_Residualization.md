# Supplementary Material S12: VIF and Residualization

## Variance Inflation Factor (VIF) Analysis

### VIF Results for PHASIC Features

| PHASIC Feature | TONIC VIF | Difficulty VIF | Effort VIF | Max VIF |
|---|---|---|---|---|
| PHASIC_SLOPE_scaled_wp_resid_wp | 1.005 | 1.003 | 1.007 | **1.007** |
| PHASIC_TER_PEAK_scaled_wp_resid_wp | 1.005 | 1.003 | 1.007 | **1.007** |
| PHASIC_TER_AUC_scaled_wp_resid_wp | 1.005 | 1.003 | 1.007 | **1.007** |
| PHASIC_EARLY_PEAK_scaled_orthogonal_wp | 1.005 | 1.003 | 1.007 | **1.007** |
| PHASIC_LATE_PEAK_scaled_orthogonal_wp | 1.005 | 1.003 | 1.007 | **1.007** |

### VIF Interpretation
- **VIF < 5**: No multicollinearity (all features pass)
- **VIF < 2**: Minimal multicollinearity (all features pass)
- **VIF ≈ 1**: No multicollinearity (all features pass)

## Pre/Post Residualization Comparison

| Parameter | Pre-Residualization | Post-Residualization | Δ Estimate | Δ SE | Relative Change |
|---|---|---|---|---|---|
| prev_choice_scaled | 0.4834 | 0.4834 | 0.0000 | 0.0000 | 0.0% |
| TONIC_BASELINE_scaled_wp | -0.1193 | -0.1193 | 0.0000 | 0.0000 | 0.0% |

### Stability Assessment
- **Stability Threshold**: < 10% change
- **All Parameters**: Stable (0.0% change)
- **Conclusion**: No residualization needed (VIF < 5)

## Residualization Details

### Formula Used
```
PHASIC_wp_resid = PHASIC_wp - β₁*TONIC_wp - β₂*difficulty - β₃*effort
```

### Residualization Results
| PHASIC Feature | R² | F | p | Residualization Effective |
|---|---|---|---|---|
| PHASIC_SLOPE_scaled_wp_resid_wp | 0.002 | 0.89 | 0.445 | No |
| PHASIC_TER_PEAK_scaled_wp_resid_wp | 0.003 | 1.12 | 0.342 | No |
| PHASIC_TER_AUC_scaled_wp_resid_wp | 0.002 | 0.78 | 0.501 | No |

*Note*: Low R² values indicate minimal shared variance between PHASIC features and TONIC + difficulty + effort.

## Orthogonalization Results

### Early vs Late Phasic Features
| Feature Pair | Correlation | Orthogonalization Effective |
|---|---|---|
| PHASIC_EARLY_PEAK vs PHASIC_LATE_PEAK | r = 0.02 | Yes |
| PHASIC_EARLY_AUC vs PHASIC_LATE_AUC | r = 0.01 | Yes |

### Orthogonalization Formula
```
PHASIC_EARLY_orthogonal = PHASIC_EARLY_wp - β*PHASIC_LATE_wp - controls
PHASIC_LATE_orthogonal = PHASIC_LATE_wp - β*PHASIC_EARLY_wp - controls
```

## Quality Assurance

### Multicollinearity Check
- **All VIF < 1.01**: Excellent
- **No residualization needed**: VIF < 5 threshold
- **Coefficients stable**: 0% change after residualization

### Processing Validation
- **State/trait decomposition**: Working effectively
- **Residualization**: Not needed (low VIF)
- **Orthogonalization**: Successful (r ≈ 0)

## Software Implementation
- **VIF Calculation**: `car::vif()`
- **Residualization**: Custom R functions
- **Orthogonalization**: `lm()` with residuals
- **Quality Checks**: Automated validation scripts
