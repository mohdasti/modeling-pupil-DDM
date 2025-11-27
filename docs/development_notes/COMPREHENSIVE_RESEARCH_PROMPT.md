# Comprehensive Research Prompt: DDM Analysis Issues

## Context: Response-Signal Drift Diffusion Model (DDM) Analysis

I am conducting a Bayesian DDM analysis using `brms` in R, fitting Wiener process models to response-signal task data. The task measures reaction times (RTs) from a "response screen" onset (not stimulus onset), where participants respond to target detection after maintaining a grip force.

---

## DATA STRUCTURE

### Dataset
- **Total trials:** 17,374
- **Subjects:** 67
- **Tasks:** ADT (auditory) and VDT (visual) - 2 levels
- **RT filtering:** 0.2-3.0 seconds (200ms floor)

### Key Variables
1. **effort_condition:** 2 levels
   - `Low_5_MVC`: 8,837 trials (5% maximum voluntary contraction)
   - `High_MVC`: 8,537 trials (40% MVC)
   - Created from `gf_trPer` (Grip Force Trial Percent: 0.05 vs 0.4)

2. **difficulty_level:** 3 levels
   - `Standard` (Δ=0, zero-evidence trials)
   - `Hard` (low signal strength)
   - `Easy` (high signal strength)

3. **task:** 2 levels
   - `ADT` (auditory detection task)
   - `VDT` (visual detection task)

4. **Response coding:**
   - `decision`: 1 = correct, 0 = incorrect
   - `rt`: Reaction time in seconds (from response screen onset)

---

## MODEL SPECIFICATIONS

### Family: Wiener Process (DDM)
```r
family = wiener(
    link_bs = "log",      # Boundary separation on log scale
    link_ndt = "log",    # Non-decision time on log scale
    link_bias = "logit"  # Starting point bias on logit scale
)
```

### Model Formulas (example - Model3_Difficulty)
```r
rt | dec(decision) ~ difficulty_level + (1|subject_id)
bs ~ 1 + (1|subject_id)
ndt ~ 1 + (1|subject_id)
bias ~ 1 + (1|subject_id)
```

### Model List
1. **Model1_Baseline:** Intercept-only (baseline)
2. **Model2_Force:** `effort_condition + (1|subject_id)`
3. **Model3_Difficulty:** `difficulty_level + (1|subject_id)`
4. **Model4_Additive:** `effort_condition + difficulty_level + (1|subject_id)`
5. **Model5_Interaction:** `effort_condition * difficulty_level + (1|subject_id)`
6. **Model7_Task:** `task + (1|subject_id)`
7. **Model8_Task_Additive:** `task + difficulty_level + (1|subject_id)`
8. **Model9_Task_Intx:** `task * effort_condition + task * difficulty_level + (1|subject_id)`
9. **Model10_Param_v_bs:** Parameter-specific (drift rate varies by effort on boundary)

**Note:** All models have intercept-only formulas for `bs`, `ndt`, and `bias` (except Model10 where `bs` may have predictors).

---

## PRIOR SPECIFICATIONS

### Base Priors (for intercept-only models)
```r
base_priors <- c(
    # Drift rate (v) - identity link, intercept-only
    prior(normal(0, 1), class = "Intercept"),
    
    # Boundary separation (a/bs) - log link
    prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
    # Center: log(1.7) ≈ 1.7 on natural scale (for older adults)
    
    # Non-decision time (t0/ndt) - log link
    prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
    # Center: log(0.23) ≈ 0.23s on natural scale
    # Rationale: RTs measured from response screen, so ndt reflects motor output only
    # Prior mass ~95% ≈ 0.16-0.33s on natural scale
    
    # Starting point bias (z) - logit link
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    # Center: logit(0) = 0.5 on natural scale (no bias)
    
    # Random effects - subject-level variability (general)
    prior(student_t(3, 0, 0.5), class = "sd"),
    
    # Random effects - subject-level NDT variation (tighter)
    prior(student_t(3, 0, 0.3), class = "sd", dpar = "ndt")
)
```

### Prior Assignment Logic
- Models with predictors on drift rate: Add `prior(normal(0, 0.5), class = "b")`
- Models with predictors on bs/ndt/bias: Add corresponding `b` priors
- Most models are intercept-only for bs/ndt/bias, so no `b` priors added

**Key Prior Details:**
- **NDT prior center:** `log(0.23)` = -1.47 on log scale
- **NDT init:** `log(0.20)` = -1.61 on log scale (200ms, safe below RT floor)
- **Rationale for NDT:** Response-signal design means RTs start at "go" signal, so ndt reflects only motor execution, not stimulus encoding (hence lower than standard designs)

---

## INITIALIZATION

### Safe Initialization Function
```r
safe_init <- function() {
    list(
        Intercept = rnorm(1, 0, 0.5),           # Drift intercept
        bs_Intercept = log(runif(1, 1.0, 2.0)), # Boundary: 1-2 on natural scale
        ndt_Intercept = log(0.20),              # NDT: 200ms (safe below RT floor)
        bias_Intercept = rnorm(1, 0, 0.3)       # Bias: centered at 0
    )
}
```

### Control Parameters
```r
control = list(
    adapt_delta = 0.95,    # Higher adapt_delta for better sampling
    max_treedepth = 12     # Maximum tree depth for NUTS
)
```

### MCMC Settings
```r
chains = 4
iter = 2000
warmup = 1000
cores = 4
backend = "cmdstanr"
```

---

## CURRENT STATUS

### What's Working ✅
1. **Data preparation:** Complete, verified effort condition has 2 levels
2. **Factor level checks:** All passing (effort=2, difficulty=3, task=2)
3. **Prior specifications:** Updated for response-signal design
4. **Initialization:** NDT init set to log(0.20) = 200ms (safe below RT floor of 200ms)
5. **9 models completed** from earlier runs (before effort fix)

### Current Issues ❌

#### Issue 1: Initialization Failures / Chain Errors (CRITICAL)
**Symptom:** Chains fail during initialization with RT < NDT violations. **The critical issue is that NDT values are becoming EXTREMELY large** (hundreds to thousands of seconds), which suggests random effects initialization is problematic.

**Example errors:**
```
Chain 4   Error evaluating the log probability at the initial value.
Chain 4   Exception: wiener_lpdf: Random variable = 0.633311, but must be greater than nondecision time = 10167.4
Chain 4   Exception: wiener_lpdf: Random variable = 0.866433, but must be greater than nondecision time = 6160.96
Chain 4   Exception: wiener_lpdf: Random variable = 0.287444, but must be greater than nondecision time = 0.296596
```

**Key observations:**
- **NDT init is set to `log(0.20)` = -1.609** (200ms on natural scale) for intercept
- **But subject-level random effects are initialized near 0 on the log scale**, which means:
  - If RE init = 0: `exp(log(0.20) + 0) = 0.20s` ✓ OK
  - If RE init is large: `exp(log(0.20) + large_value)` = huge values ✗
- **The issue:** Subject-level NDT random effects can push total NDT way above RTs
- **Even small positive RE values** (e.g., +5 on log scale) → `exp(-1.609 + 5) = 23s`!

**What we've tried:**
- Set NDT intercept init to `log(0.20)` (200ms, below RT floor)
- Adjusted NDT prior center from `log(0.35)` to `log(0.23)`
- Reduced NDT prior spread from 0.25 to 0.20
- Added subject-level NDT RE prior: `student_t(3, 0, 0.3)`
- **But we haven't constrained RE initialization!**

**Questions:**
- How should we initialize subject-level NDT random effects to prevent extreme values?
- Should RE inits be explicitly set to 0 or very small values?
- Is there a way to bound or constrain RE initialization in brms?
- Should we use `init = 0` with explicit RE initialization?
- Are there brms options for constrained initialization of random effects?
- Should we initialize REs on the natural scale vs. link scale?

#### Issue 2: Model Completion Status Unclear
**Symptom:** Some models appear to start but status unclear:
- Log shows "Start sampling" but unclear if all models complete
- Need to verify which models are actually finishing successfully

**Questions:**
- How to diagnose if models are completing vs. hanging?
- What are best practices for monitoring long-running brms models?
- Should we adjust iteration counts or use different settings for problematic models?

#### Issue 3: Prior vs. Formula Mismatch (Potentially Resolved)
**Symptom:** Earlier errors about priors not matching model parameters:
```
The following priors do not correspond to any model parameter:
b_bs ~ normal(0, 0.2)
```

**What we fixed:**
- Only add `b` priors when formulas actually have predictors
- Intercept-only models get only intercept priors

**Questions:**
- Is this approach correct, or should we use different prior structure?
- Are there other prior-formula alignment issues we should check?

---

## SPECIFIC QUESTIONS FOR RESEARCH

### Question 1: NDT Initialization for Response-Signal Design
**Context:** RTs measured from response screen onset (not stimulus), so NDT should be lower than standard designs.

**Current approach:**
- Prior center: `log(0.23)` ≈ 230ms
- Init value: `log(0.20)` ≈ 200ms
- RT floor: 200ms (min RT in data: 243ms)

**Questions:**
- Is this initialization strategy appropriate for response-signal designs?
- Should NDT init be even lower (e.g., `log(0.15)` = 150ms)?
- How should we handle subject-level random effects in initialization?
- Are there specific initialization strategies for Wiener models in brms?

### Question 2: Handling Initialization Failures
**Context:** Some chains fail at initialization with RT < NDT violations.

**Questions:**
- What's the best strategy when initialization fails: retry, adjust init, or change model?
- Should we use `init = "random"` vs. custom init function?
- Are there brms-specific options for handling initialization failures?
- Should we filter data more aggressively (e.g., RT > 250ms) to give more headroom?

### Question 3: Model Complexity and Convergence
**Context:** Multiple models with varying complexity (baseline vs. interactions).

**Questions:**
- Are there known convergence issues with Wiener models in brms?
- Should we use different adapt_delta or max_treedepth for different models?
- How to diagnose if models are truly stuck vs. just slow?
- Should we use different settings for simpler vs. more complex models?

### Question 4: Response-Signal DDM Specifications
**Context:** Using standard DDM for response-signal task.

**Questions:**
- Are there any brms/Stan-specific considerations for response-signal DDMs?
- Should NDT prior structure differ from standard designs?
- Are there parameter bounds or constraints we should explicitly set?
- How does the "response screen" measurement affect prior specifications?

---

## ENVIRONMENT & VERSIONS

- **R version:** (not specified, but using recent brms)
- **brms version:** 2.22.0 (from logs)
- **Stan backend:** cmdstanr
- **Platform:** macOS (darwin)

---

## WHAT WE NEED

1. **Validation of prior specifications** for response-signal DDM:
   - Are NDT priors appropriate (log(0.23), spread 0.20)?
   - Are initialization values appropriate (log(0.20))?

2. **Strategies for handling initialization failures:**
   - Best practices for NDT initialization in brms Wiener models
   - How to handle subject-level variation in init

3. **Diagnosis of model completion:**
   - How to verify models are completing vs. hanging
   - Best monitoring practices for long-running models

4. **Any brms/Stan-specific considerations:**
   - Known issues or workarounds for Wiener models
   - Parameter bounds, constraints, or other specifications

---

## ADDITIONAL CONTEXT

- **Task:** Response-signal target detection with grip force maintenance
- **Population:** Older adults
- **Design:** Mixed effects (subjects, conditions, tasks)
- **Goal:** Estimate DDM parameters (drift, boundary, NDT, bias) and their relationships to effort and difficulty

---

## FILES AVAILABLE

If needed for reference:
- Model specification script: `scripts/02_statistical_analysis/02_ddm_analysis.R`
- Data file: `data/analysis_ready/bap_ddm_ready.csv`
- Log files: `ddm_analysis_fixed.log`

---

**Please provide:**
1. Recommendations for NDT initialization strategy
2. Best practices for handling initialization failures
3. Any known issues or solutions for Wiener models in brms
4. Validation of our prior specifications
5. Diagnostic strategies for model completion

Thank you!

