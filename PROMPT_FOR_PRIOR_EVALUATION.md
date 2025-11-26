# Prompt for Prior Specification Evaluation

**Use this prompt with another LLM to evaluate your DDM prior specifications**

---

## PROMPT TO SEND:

I need you to evaluate the prior specifications for my hierarchical Bayesian drift diffusion model (DDM) analyses. Please assess whether my priors are justified by the literature and whether the variations across scripts are appropriate or problematic.

## STUDY CONTEXT

**Research Question:** How do pupillometry-measured arousal (tonic baseline and phasic evoked) modulate drift diffusion model parameters (drift rate v, boundary separation a/bs, non-decision time t₀/ndt, starting point bias z)?

**Sample:**
- N = 67 older adults (≥65 years)
- Two-choice change detection task (auditory and visual)
- Response-signal design: Standard stimulus (100ms) → ISI (500ms) → Target (100ms) → blank (250ms) → response screen (3000ms window)
- RT measured from response-screen onset (forced 350ms delay from target onset)
- RT filtering: 200ms to 3000ms (anticipations and timeouts excluded)

**Experimental Manipulations:**
- Difficulty: Easy (high signal), Hard (low signal), Standard (Δ=0, same trials)
- Effort: Low (5% MVC), High (40% MVC) handgrip force
- All factors within-subject

**Modeling Approach:**
- Using `brms` package with `wiener()` family for DDM likelihood
- Hierarchical structure: trial-level within subject-level random effects
- Link functions: `link_bs = "log"`, `link_ndt = "log"`, `link_bias = "logit"`
- Primary analyses: Effects of difficulty, effort, and pupillometry on DDM parameters

**Key References:**
- Ratcliff & McKoon (2008) - DDM theory and parameter ranges
- Ratcliff & Tuerlinckx (2002) - DDM parameter estimation and contaminants
- de Gee et al. (2020) - Pupil-linked arousal and decision bias
- Mækelæ et al. (2024) - Tonic arousal and boundary separation
- Aging DDM papers using similar paradigms

---

## MY CURRENT PRIOR SPECIFICATIONS

I have **6 different prior specifications** across my analysis scripts. Please evaluate each:

### PRIOR SET 1: Main DDM Analysis
**File:** `scripts/02_statistical_analysis/02_ddm_analysis.R`  
**Context:** Core behavioral models (effort, difficulty, interactions)

```r
common_priors <- c(
    prior(normal(0, 1.5), class = "Intercept"),
    prior(normal(0, 1), class = "b"),
    prior(exponential(1), class = "sd")
)
```

**Notes:**
- No parameter-specific priors (bs, ndt, bias)
- Uses exponential prior for random effects SD
- Intercept prior SD = 1.5
- Coefficient prior SD = 1.0

**Questions:**
1. Is `normal(0, 1.5)` for Intercept appropriate for drift rate on log scale?
2. Is `normal(0, 1)` for coefficients (b) reasonable for condition effects?
3. Should I have parameter-specific priors for bs, ndt, bias even if they're not in the formula?
4. Is `exponential(1)` appropriate for random effects SD?

---

### PRIOR SET 2: Tonic/History/Pupillometry Models
**Files:** `scripts/tonic_alpha_analysis.R`, `scripts/history_modeling.R`, `scripts/qc/lapse_sensitivity_check.R`  
**Context:** Models testing pupillometry effects and serial bias

```r
priors <- c(
  prior(normal(0, 0.5), class = "b"),
  prior(normal(0, 1), class = "sd"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "bias")
)
```

**Notes:**
- Parameter-specific priors for wiener family (bs, ndt, bias)
- All on log/logit scale (link_bs="log", link_ndt="log", link_bias="logit")
- Smaller SD (0.5) for coefficients vs Set 1
- Same SD (1.0) for random effects
- No explicit prior for drift rate Intercept

**Questions:**
1. Is `normal(0, 0.2)` appropriate for bs on log scale? (typical a ≈ 1-3, so log(a) ≈ 0-1)
2. Is `normal(0, 0.2)` appropriate for ndt on log scale? (typical t₀ ≈ 0.2-0.5s, so log(t₀) ≈ -1.6 to -0.7)
3. Is `normal(0, 0.2)` appropriate for bias on logit scale? (typical z ≈ 0.3-0.7, so logit(z) ≈ -0.85 to +0.85)
4. Why no explicit drift rate prior? Is default brms prior sufficient?
5. Should coefficient SD (0.5) be different from Set 1 (1.0)? Why?

---

### PRIOR SET 3: Simple DDM Fit
**File:** `scripts/modeling/fit_ddm_brms.R`  
**Context:** Basic DDM with difficulty and effort effects

```r
pri <- c(
  prior(normal(0, 0.3), class = "b"),
  prior(normal(0, 0.5), class = "sd"),
  prior(normal(log(0.2), 0.3), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "bias")
)
```

**Notes:**
- NDT prior centered at `log(0.2)` = -1.61 (on log scale)
- Different coefficient SD (0.3) vs Sets 1-2
- Different random effects SD (0.5) vs Sets 1-2
- Same bs/bias priors as Set 2

**Questions:**
1. Is centering NDT at `log(0.2)` = -1.61 justified? (0.2s is typical for aging samples)
2. Is `normal(log(0.2), 0.3)` appropriate spread? (covers ~0.1 to 0.4s on natural scale)
3. Why different SD values (0.3, 0.5) vs other sets?
4. Should all scripts use this same NDT prior?

---

### PRIOR SET 4: Adaptive Complexity (Phase_B)
**File:** `01_data_preprocessing/r/Phase_B.R`  
**Context:** Adaptive DDM builder that adjusts complexity by sample size

```r
priors <- c(
    prior(normal(0, 1), class = "Intercept"),  # For drift rate
    prior(normal(1, 0.5), class = "Intercept", dpar = "bs"),  # For boundary separation
    prior(normal(0.2, 0.08), class = "Intercept", dpar = "ndt", 
          lb = 0.01, ub = max_ndt),  # max_ndt = min(rt) - 0.01
    prior(normal(0, 0.5), class = "b"),
    prior(exponential(2), class = "sd")
)
```

**Notes:**
- bs prior on NATURAL scale: `normal(1, 0.5)` (not log scale!)
- ndt prior on NATURAL scale: `normal(0.2, 0.08)` with bounds
- Uses exponential(2) for SD (tighter than Sets 1-2)
- Adaptive bounds: ndt must be < min(rt) - 0.01

**Questions:**
1. **CRITICAL:** This uses natural scale for bs/ndt, but brms wiener uses log link! Is this wrong?
2. If using log link, should priors be `normal(log(1), 0.5)` for bs and `normal(log(0.2), 0.08)` for ndt?
3. Is the bound constraint `ub = max_ndt` appropriate? (prevents ndt > min RT)
4. Is `exponential(2)` tighter than `exponential(1)`? (rate=2 means mean=0.5, rate=1 means mean=1.0)
5. Should this adaptive approach be used everywhere, or only for small samples?

---

### PRIOR SET 5: Parameter Recovery/Testing
**File:** `scripts/modeling/parameter_recovery.R`  
**Context:** Simulation and recovery testing

```r
# Similar to Set 3 but with simulated data
```

**Questions:**
1. Are minimal priors acceptable for recovery studies?
2. Should recovery priors match production priors?

---

### PRIOR SET 6: Compare Models
**File:** `scripts/modeling/compare_models.R`  
**Context:** Model comparison scripts

```r
prior = c(
    prior(normal(0, 0.5), class = "b"), 
    prior(normal(0, 1), class = "sd")
)
```

**Questions:**
1. Is minimal prior specification acceptable for comparison studies?
2. Should comparison models use same priors as production?

---

## KEY QUESTIONS FOR EVALUATION

### General Questions:
1. **Consistency:** Should all my DDM models use the same prior specification, or are variations justified by analysis context?

2. **Scale Issues:** I'm using log/log/logit links. Are my priors specified on the correct scale?
   - bs: log link → priors should be on log scale?
   - ndt: log link → priors should be on log scale?
   - bias: logit link → priors should be on logit scale?
   - drift: what link/default? → what scale for priors?

3. **Literature Standards:** What do established DDM papers (Ratcliff, Wagenmakers, etc.) recommend for:
   - Drift rate (v) priors?
   - Boundary separation (a/bs) priors on log scale?
   - Non-decision time (t₀/ndt) priors on log scale?
   - Starting point bias (z) priors on logit scale?

4. **Aging Sample:** Does my older adult sample (≥65 years) require different priors than typical young adult studies?

5. **Response-Signal Design:** Does the 350ms forced delay affect what priors are appropriate for ndt?

6. **Random Effects:** What priors are standard for:
   - Subject-level random intercepts?
   - Subject-level random slopes?
   - Is exponential(1) vs exponential(2) a meaningful choice?

7. **Parameter-Specific Priors:** Should I ALWAYS specify priors for bs, ndt, bias when using wiener family, even if they're not in the formula (just intercept-only)?

---

## WHAT I NEED FROM YOU

Please provide:

1. **Evaluation of each prior set:**
   - Are they justified by DDM literature?
   - Are they on the correct scale (natural vs log/logit)?
   - Are the SD values reasonable?

2. **Consistency check:**
   - Should all sets be standardized?
   - If variations are justified, explain why for each case
   - If not justified, recommend a single standard specification

3. **Literature-based recommendations:**
   - What priors do you recommend based on:
     * Ratcliff & McKoon (2008)
     * Wagenmakers et al. DDM papers
     * Aging DDM studies
     * brms wiener family best practices
     * Hierarchical DDM with pupillometry

4. **Specific corrections:**
   - If any priors are wrong, provide corrected specifications
   - Explain the rationale for each correction

5. **Aging sample considerations:**
   - Do older adults require different priors?
   - Typical parameter ranges for aging DDM studies?

6. **Response-signal design considerations:**
   - How does the forced delay affect appropriate priors?

---

## ADDITIONAL CONTEXT

**My data characteristics:**
- Mean RT: ~1.0 sec (median ~0.9 sec)
- RT range: 0.2 to 3.0 sec (after filtering)
- Accuracy: varies by difficulty (Easy ~85%, Hard ~70%, Standard ~50% [chance])
- Tasks: Both auditory and visual discrimination

**My model convergence:**
- Using Rhat < 1.01 or 1.02 as criterion
- ESS > 400 typically
- adapt_delta varies: 0.9-0.99 depending on script
- max_treedepth: 10-15 depending on complexity

**Current issues I'm aware of:**
- Priors vary across scripts (might be problematic)
- Phase_B.R uses natural scale priors but wiener uses log link (potential bug?)
- No explicit drift rate priors in most scripts (relying on brms defaults)

---

Please provide a comprehensive evaluation with specific recommendations based on established DDM literature and brms/Stan best practices for hierarchical Bayesian DDM modeling.

---

**END OF PROMPT**
















