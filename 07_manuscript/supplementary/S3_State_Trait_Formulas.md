# Supplementary Material S3: State/Trait Formulas and ICCs

## State/Trait Decomposition Formulas

### Mathematical Framework

For each pupillometry feature *X* and participant *i*:

**Between-Person Component (Trait)**:
```
X_bp_i = (1/n_i) * Σ(X_ij) for j = 1 to n_i
```

**Within-Person Component (State)**:
```
X_wp_ij = X_ij - X_bp_i
```

**Z-scored Within-Person**:
```
X_wp_z_ij = (X_wp_ij - μ_wp_i) / σ_wp_i
```

Where:
- *X_ij* = raw value for participant *i*, trial *j*
- *n_i* = number of trials for participant *i*
- *μ_wp_i* = mean within-person deviation for participant *i*
- *σ_wp_i* = SD of within-person deviations for participant *i*

### Residualization Formula

**PHASIC Residualization**:
```
PHASIC_wp_resid_ij = PHASIC_wp_ij - β₁*TONIC_wp_ij - β₂*difficulty_j - β₃*effort_j
```

Where β₁, β₂, β₃ are estimated from:
```
PHASIC_wp_ij ~ TONIC_wp_ij + difficulty_j + effort_j
```

## Intraclass Correlation Coefficients (ICCs)

| Feature | ICC | Interpretation | 95% CI |
|---|---|---|---|
| TONIC_BASELINE | 0.73 | Excellent | [0.68, 0.78] |
| PHASIC_SLOPE | 0.68 | Good | [0.62, 0.74] |
| PHASIC_TER_PEAK | 0.71 | Good | [0.65, 0.77] |
| PHASIC_TER_AUC | 0.69 | Good | [0.63, 0.75] |
| PHASIC_EARLY_PEAK | 0.66 | Good | [0.60, 0.72] |
| PHASIC_LATE_PEAK | 0.70 | Good | [0.64, 0.76] |

### ICC Interpretation Guidelines
- **ICC > 0.75**: Excellent reliability
- **ICC 0.60-0.74**: Good reliability  
- **ICC 0.40-0.59**: Moderate reliability
- **ICC < 0.40**: Poor reliability

## Variance Decomposition

| Feature | Between-Person Variance | Within-Person Variance | Total Variance |
|---|---|---|---|
| TONIC_BASELINE | 0.73 | 0.27 | 1.00 |
| PHASIC_SLOPE | 0.68 | 0.32 | 1.00 |
| PHASIC_TER_PEAK | 0.71 | 0.29 | 1.00 |
| PHASIC_TER_AUC | 0.69 | 0.31 | 1.00 |

*Note*: All features show substantial between-person variance (>65%), indicating strong trait-like stability in pupillometry measures.

## Model Comparison Approach

### Bayesian Models (DDM with brms)
We report **PSIS-LOO (Pareto-Smoothed Importance Sampling Leave-One-Out)** cross-validation for all Bayesian hierarchical drift diffusion models. LOO was computed using the `loo` package with `reloo = TRUE` to automatically refit models for observations with high Pareto-k diagnostic values (>0.7). Model comparison between competing specifications (e.g., history models) was performed using `loo_compare()` to calculate expected log predictive density (elpd) differences and Akaike weights. All Bayesian models were fit using the cmdstanr backend.

### Frequentist Models (GLMER)
For frequentist generalized linear mixed-effects models (GLMER), we report **AIC (Akaike Information Criterion)** and **BIC (Bayesian Information Criterion)** for model comparison and selection. AIC weights were calculated to quantify relative support for competing models.

### Exceptions
Where models were fit exclusively with `ggdmc` (Python-based DDM fitting), we report **WAIC (Widely Applicable Information Criterion)** and **DIC (Deviance Information Criterion)** with explicit rationale provided in the relevant supplementary materials.
