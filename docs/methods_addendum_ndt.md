# Methods Addendum: Non-Decision Time (NDT) Modeling Decision

**Response-Signal Paradigm and Timing Constraints**

In the response-signal detection task, participants are instructed to respond as soon as they detect a signal, rather than waiting for a fixed presentation duration. This paradigm creates a tight coupling between stimulus presentation and response initiation, which has important implications for modeling non-decision time (NDT; *t*₀).

**NDT at Population Level: Rationale**

We chose to model NDT as a population-level parameter (no subject-level random effects) rather than including subject-specific NDT terms. This decision was based on three considerations:

1. **Response-Signal Timing Constraints**: In the response-signal paradigm, the time from stimulus onset to response execution is constrained by the imperative to respond immediately upon detection. This temporal constraint reduces between-subject variability in NDT compared to paradigms with fixed presentation durations or self-paced responding.

2. **Parameter Identifiability**: NDT is inherently difficult to estimate separately from decision time, particularly in models with complex hierarchical structures. Including subject-level random effects for NDT can lead to parameter non-identifiability or convergence issues, especially when NDT values approach the lower bound of observed RTs.

3. **Model Parsimony**: Given the tight timing constraints in the response-signal paradigm, between-subject variance in NDT is expected to be minimal. A population-level parameter provides sufficient flexibility while maintaining model parsimony and stability.

**Initialization Safeguards**

To ensure stable model fitting and prevent invalid parameter estimates, we implemented explicit initialization constraints for NDT:

- **NDT initialization**: `log(0.20)` (200 ms on natural scale)
- **Rationale**: This value is safely below the RT floor (250 ms) used in data filtering, ensuring that NDT < min(RT) for all trials—a critical constraint for the Wiener diffusion model.

The initialization function uses:
```r
Intercept_ndt = log(0.20)  # 200ms, safely below 250ms RT floor
```

This safeguard prevents the sampler from exploring invalid regions of parameter space where NDT ≥ RT, which would violate the model's assumptions.

**Prior Specification**

NDT was assigned a weakly informative prior on the log scale:
- **Prior**: `normal(log(0.23), 0.20)`
- **Natural scale**: The prior is centered at 230 ms (exp(log(0.23))), which is consistent with typical NDT values in response-signal paradigms (typically 150–300 ms).
- **Prior width**: The standard deviation of 0.20 on the log scale allows for reasonable variation (~20% on natural scale) while constraining implausible values.

**Validation**

The population-level NDT specification was validated through:
1. **Convergence diagnostics**: All models showed acceptable convergence (R̂ < 1.05) with this specification.
2. **Posterior predictive checks**: Model-predicted RT distributions aligned with observed data, indicating that the population-level NDT adequately captures the data-generating process.
3. **Sensitivity analysis**: Models with subject-level NDT random effects (when tested) showed convergence issues or minimal improvement in predictive performance, supporting the population-level specification.

**Conclusion**

The decision to model NDT at the population level reflects the temporal constraints of the response-signal paradigm, parameter identifiability considerations, and model stability. The explicit initialization safeguards and weakly informative prior ensure robust estimation while preventing invalid parameter configurations.







