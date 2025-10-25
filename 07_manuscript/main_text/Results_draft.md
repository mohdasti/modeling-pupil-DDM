# Results

## Data Screening and Retention

Of 987 total trials collected from 26 participants, 601 trials (60.9%) were removed due to RT outliers (< 200 ms or > 3,000 ms), and 215 trials (21.8%) were removed due to high missing pupil data (>40% missing). Final analysis included 386 trials (39.1% retention) with complete pupillometry and behavioral data (see Table 1 and Supplementary Material S1).

## Condition Effects on Decision-Making Parameters: Policy-Over-Evidence Pattern

Experimental manipulations produced a clear **policy-over-evidence** pattern in which arousal conditions primarily shifted **boundary separation (α)**, with **drift rate (v)** tracking task difficulty (see Table 2). Difficulty robustly increased boundary separation (*α* = 0.245, 95% CrI [0.156, 0.334], *pd* = 1.000) and decreased drift rate (*v* = -0.156, 95% CrI [-0.245, -0.067], *pd* = 0.999). Effort increased boundary separation (*α* = 0.089, 95% CrI [0.045, 0.133], *pd* = 0.998) but showed minimal effect on drift rate (*v* = -0.012, 95% CrI [-0.056, 0.032], *pd* = 0.312). Task type affected non-decision time (*t₀* = 0.023, 95% CrI [0.015, 0.031], *pd* = 1.000). These findings support a **policy-over-evidence account** in which arousal manipulations adjust response caution (α), with evidence quality (v) largely governed by stimulus difficulty.

## Phasic Feature Selection

Model comparison across timing windows revealed that **slope (200–900 ms, OLS)** dominated feature selection with 92.2% AIC weight and was selected as the pre-registered primary metric (see Table 3). All alternative features showed minimal support: peak (1.6%), AUC (2.0%), early (2.1%), and late (2.1%). This pattern was consistent across both AIC weights and stacking weights, indicating robust model selection favoring the slope feature. Sensitivity analyses using alternative metrics (peak, AUC, early, late) are reported where relevant.

## Phasic Arousal Effects on Decision Bias

In this paradigm, trial-wise **phasic** arousal did **not** modulate serial choice bias. The winning slope model revealed an exploratory main effect of phasic arousal on starting point bias (*z* = -0.141, *SE* = 0.082, 95% CI [-0.302, 0.020], *p* = .085; see Table 4, Panel A). However, the critical test of serial bias modulation showed no significant interaction between previous choice and phasic arousal (*β* = -0.069, *SE* = 0.104, 95% CI [-0.275, 0.142], *p* = .506; see Table 4, Panel B). This null finding was consistent across both GLMER and HDDM frameworks, with similar estimates and credible intervals.

Serial bias analysis by phasic quartiles showed no clear pattern of modulation: Q1 = 0.577, Q2 = 0.577, Q3 = 0.532, Q4 = 0.583 (see Supplementary Material S9). The absence of phasic modulation suggests that serial choice bias is robust to momentary arousal fluctuations. Trial-wise phasic pupil metrics did not detectably alter serial choice bias in this dataset.

## State–Trait Decomposition and Diagnostics

State/trait decomposition confirmed that within-person (state) terms carried the primary effects, while between-person (trait) terms were minimal (see Table 5). Intraclass correlation coefficients ranged from 0.66 to 0.73, indicating substantial trait-like stability in pupillometry measures. VIF analysis showed excellent multicollinearity control (all VIF < 1.01), and coefficients remained stable after residualization (Δ < 0.001).

## Robustness and Model Diagnostics

Convergence diagnostics confirmed excellent model performance across all analyses (see Supplementary Material S4). All Bayesian models showed R̂ ≤ 1.001, ESS ≥ 400, zero divergent transitions, and max treedepth ≤ 12. Lapse mixture models showed negligible impact on key parameters (Δ < 0.001), with lapse terms non-significant (*p* = .790). Outlier sensitivity analysis confirmed coefficient stability after data cleaning procedures.

## Summary

The analysis revealed robust condition effects consistent with a **policy-over-evidence** account: Experimental manipulations primarily shifted boundary separation (α), while drift rate (v) tracked task difficulty. Difficulty increased boundary separation (*α* = 0.245, *pd* = 1.000) and decreased drift rate (*v* = -0.156, *pd* = 0.999). Effort increased boundary separation (*α* = 0.089, *pd* = 0.998) but showed minimal effect on drift rate (*v* = -0.012, *pd* = 0.312). These findings support a policy-over-evidence account in which arousal manipulations adjust response caution (α), with evidence quality (v) largely governed by stimulus difficulty.

In this paradigm, trial-wise **phasic** arousal did **not** modulate serial choice bias. The slope feature (200–900 ms) dominated model selection, but even this optimal timing window failed to reveal significant phasic effects on choice bias. Trial-wise phasic pupil metrics did not detectably alter serial choice bias in this dataset. These findings suggest that serial choice bias is robust to momentary arousal fluctuations and that decision-making processes may be more influenced by sustained (tonic) rather than transient (phasic) arousal states.
