# Decision Coding Analysis and Recommendations

## Critical Findings

### 1. Model is Using Accuracy Coding, Not Response-Side Coding

**Evidence:**
- Model file (`R/fit_primary_vza.R`) uses: `decision = iscorr` (1=correct, 0=incorrect)
- Data file used: `bap_ddm_ready.csv` (accuracy-coded)
- Standard trials show: 96% correct responses (iscorr=1)
- On Standard trials: "same" = correct, so 96% "same" responses

**Bias Results:**
- z = 0.567 (probability scale, > 0.5)
- This means bias toward **correct responses** (decision=1)

### 2. Manuscript Claims Response-Side Coding

**Manuscript says:**
- Upper boundary = "different"
- Lower boundary = "same"
- z > 0.5 = bias toward "different"

**This is incompatible with:**
- 96% "same" responses on Standard trials
- z = 0.567

### 3. Mathematical Contradiction

**If using response-side coding (as manuscript claims):**
- With 96% "same" responses (lower boundary), z **MUST** be < 0.5
- Expected z ≈ 0.04-0.10 (very close to lower boundary)
- Current z = 0.567 is **mathematically impossible**

**If using accuracy coding (as code actually does):**
- z = 0.567 means bias toward correct responses
- On Standard trials, "same" = correct
- This is **consistent** with 96% "same" responses
- No contradiction

## Resolution Options

### Option A: Update Manuscript to Match Code (Quick Fix)

**Pros:**
- No re-fitting needed
- Current results are internally consistent
- Faster to implement

**Cons:**
- Cannot properly test bias hypotheses (toward "same" vs "different")
- Accuracy coding doesn't allow disentangling response bias from discriminability
- Limits theoretical interpretation

**Required Changes:**
1. Remove claim about "response-side coding"
2. Clarify that bias is toward **correct responses**, not specific alternatives
3. Update interpretation: z > 0.5 = bias toward being correct
4. Acknowledge limitations of accuracy coding

### Option B: Re-fit Models with Response-Side Coding (Recommended)

**Pros:**
- Matches manuscript description
- Allows proper bias estimation (toward "same" vs "different")
- Enables testing of arousal effects on response bias
- Theoretically coherent

**Cons:**
- Requires re-fitting all models
- More time-consuming
- Need to verify results remain stable

**Required Changes:**
1. Use `bap_ddm_ready_with_upper.csv` (already created)
2. Update all model formulas to use `dec_upper` instead of `decision`
3. Re-fit all models
4. Expect z values to be < 0.5 (around 0.04-0.10)
5. Update bias interpretation in manuscript

## Recommendation

**I strongly recommend Option B** because:
1. Your manuscript explicitly describes response-side coding
2. You want to test hypotheses about arousal effects on response bias
3. Response-side coding is necessary for same/different tasks
4. The response-side coded file already exists
5. Your theoretical questions require disentangling response bias from accuracy

## Next Steps

1. **Verify current decision coding** in fitted models
2. **Choose resolution option** (A or B)
3. **If Option B:** Update model scripts and re-fit
4. **Update manuscript** to match actual implementation

