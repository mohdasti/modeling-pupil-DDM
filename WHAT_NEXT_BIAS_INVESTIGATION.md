# What's Next: Critical Bias Interpretation Issue

**Date:** 2025-11-25  
**Model Status:** ✅ Converged successfully  
**Issue Status:** ⚠️ **CRITICAL** - Bias interpretation contradicts data

---

## ✅ Good News

1. **Model converged perfectly:**
   - Rhat = 1.0007 (excellent convergence)
   - ESS = 4,270+ (excellent sampling)
   - No divergent transitions
   - Runtime: 69.5 minutes

2. **Other parameters look reasonable:**
   - Drift v = -0.036 ≈ 0 ✓
   - Boundary a = 2.38 (reasonable) ✓
   - NDT = 0.225s (< min RT) ✓

---

## 🚨 CRITICAL PROBLEM

### The Contradiction

- **Your data:** 89.1% "Same" responses (only 10.9% "Different")
- **Model estimate:** Bias z = 0.569 (> 0.5, meaning bias toward "Different")

**This is mathematically impossible!**

### Why This Can't Be Right

In a Standard-only model with drift ≈ 0:
- The starting point (bias z) directly determines response probabilities
- If z = 0.569, the model predicts ~56.9% upper boundary ("Different") responses
- But your data shows only 10.9% "Different" responses

**This means either:**
1. The coding is reversed (dec_upper interpretation is wrong)
2. The boundary definitions are reversed in brms
3. There's a fundamental misunderstanding of how brms interprets `dec()`

---

## 🔍 What Needs Investigation

### Question 1: How does brms interpret `dec()`?

In `rt | dec(dec_upper)`, when:
- `dec_upper = 1`, does this mean hitting the **upper** boundary?
- `dec_upper = 0`, does this mean hitting the **lower** boundary?

**Check:** Look at brms documentation or test with simulation

### Question 2: What does bias z = 0.569 mean?

- Does it mean starting 56.9% of the way from lower to upper boundary?
- If so, should predict ~56.9% upper boundary hits
- But data shows only 10.9% upper boundary hits

**This suggests either:**
- Coding is backwards, OR
- Interpretation is wrong

### Question 3: Is the boundary assignment correct?

You coded:
- `dec_upper = 1` → "Different" = Upper boundary
- `dec_upper = 0` → "Same" = Lower boundary

**But maybe brms expects:**
- `dec_upper = 1` → Actually means "Same"?
- Or maybe boundaries are reversed?

---

## 📋 Immediate Actions

### Step 1: Check brms Documentation

Look up how `dec()` function works in brms wiener models:
- What does the decision variable represent?
- How are boundaries mapped?
- Is there a default convention?

### Step 2: Create Test Simulation

**Quick test script:**
```r
library(rtdists)
library(brms)

# Simulate data with known bias (z = 0.1, expecting 90% "Same")
set.seed(123)
n <- 1000
a <- 2.0  # boundary separation
z <- 0.1  # starting point (10% from lower, 90% from upper)
v <- 0.0  # no drift (Standard trials)
ndt <- 0.2

# Simulate Wiener process
sim_data <- rwiener(n, alpha=a, tau=ndt, beta=z, delta=v)

# Check proportion upper boundary
prop_upper <- mean(sim_data$resp == "upper")  # Should be ~0.1

# Code for brms
sim_df <- data.frame(
  rt = sim_data$q,
  dec_upper = as.integer(sim_data$resp == "upper"),  # 1 = upper
  subject_id = rep(1, n)
)

# Fit model
fit_test <- brm(
  rt | dec(dec_upper) ~ 1,
  bs ~ 1,
  ndt ~ 1,
  bias ~ 1,
  data = sim_df,
  family = wiener(link_bs="log", link_ndt="log", link_bias="logit"),
  chains = 2, iter = 1000, warmup = 500  # Quick test
)

# Extract bias
draws <- as_draws_df(fit_test)
bias_est <- mean(plogis(draws$b_bias_Intercept))

# Check: Does it recover z = 0.1?
# If bias_est ≈ 0.1, then coding is correct
# If bias_est ≈ 0.9, then boundaries are reversed
```

### Step 3: Check Your Actual Data

```r
# Load your data
data <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv")

# Check Standard trials
std <- data %>% filter(difficulty_level == "Standard")

# What proportion have dec_upper = 1?
prop_diff <- mean(std$dec_upper, na.rm=TRUE)  # Should be 0.109

# What are the actual response labels?
table(std$dec_upper, std$response_label, useNA="always")

# Verify: dec_upper=1 should correspond to "different"
```

---

## 🎯 Possible Solutions

### Option A: Coding is Reversed

**If boundaries are reversed, fix by:**
```r
# In data preparation script:
dec_upper = case_when(
  resp_is_diff == TRUE  ~ 0L,  # Flip: Different = Lower
  resp_is_diff == FALSE ~ 1L   # Flip: Same = Upper
)
```

Then re-fit model and verify bias ≈ 0.11

### Option B: Interpretation is Wrong

**If brms interprets differently, adjust expectations:**
- Maybe z = 0.569 means starting close to "Same" boundary?
- Check brms documentation for exact interpretation

---

## ⚠️ DO NOT PROCEED

**Do NOT run the Primary model until this is resolved!**

If the bias interpretation is wrong:
- All bias estimates will be backwards
- All interpretations will be wrong
- Manuscript results will be incorrect

---

## 📊 Next Steps Priority

1. **IMMEDIATE:** Run test simulation to verify brms boundary interpretation
2. **THEN:** Check if coding needs to be flipped
3. **THEN:** Fix data preparation script if needed
4. **THEN:** Re-fit Standard-only model
5. **THEN:** Verify bias matches data
6. **FINALLY:** Proceed with Primary model

---

## 💡 Quick Test You Can Run Now

```r
# Quick diagnostic
library(brms)
library(posterior)
library(readr)

# Load fitted model
fit <- readRDS("output/models/standard_bias_only.rds")

# Load data
data <- read_csv("data/analysis_ready/bap_ddm_only_ready.csv")
std <- data %>% filter(difficulty_level == "Standard")

# Check what model predicts
draws <- as_draws_df(fit)
bias_samples <- plogis(draws$b_bias_Intercept)

# Model thinks starting point is:
mean(bias_samples)  # 0.569

# But data shows:
mean(std$dec_upper)  # 0.109 (proportion "Different")

# This mismatch suggests coding is reversed
```

---

**Priority: Resolve this BEFORE running Primary model!**

