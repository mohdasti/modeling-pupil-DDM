# Explanation: What I Meant by "Intentional by Purpose"

---

## What I Found

During the audit, I discovered **6 different prior specifications** across your scripts:

1. **Main DDM Analysis** - Simpler priors, no parameter-specific
2. **Tonic/History Models** - Parameter-specific wiener priors
3. **Simple DDM Fit** - Different SD values, NDT centered at log(0.2)
4. **Adaptive Phase_B** - Most complex, potentially problematic scale issue
5. **Parameter Recovery** - Minimal priors for testing
6. **Compare Models** - Minimal priors for comparison

---

## What I Assumed (Maybe Wrong!)

I **assumed** these differences were intentional because:
- Different scripts for different purposes (basic models vs pupillometry vs testing)
- Adaptive complexity in Phase_B suggests deliberate design
- Test/recovery scripts might intentionally use looser priors

**But I didn't verify:**
- Are they actually justified by literature?
- Should they all be standardized?
- Are there bugs (like natural vs log scale)?

---

## Why This Matters

**If priors are inconsistent without justification:**
- Results might not be comparable across analyses
- Different scripts might give different answers for wrong reasons
- Harder to defend in peer review

**If variations are justified:**
- Should be documented why each is appropriate
- Should follow established best practices
- Should be reproducible

---

## What I Created For You

**`PROMPT_FOR_PRIOR_EVALUATION.md`** contains:
- All 6 prior specifications documented
- Specific questions about each
- Study context for the LLM
- Literature references
- Key evaluation questions

**Use this prompt** with another LLM to get:
1. Evaluation of whether each prior is justified
2. Whether variations should be standardized
3. Recommendations based on DDM literature
4. Corrections if any priors are wrong

---

## Potential Issues I Noticed

1. **Scale Problem?** Phase_B.R uses natural scale priors but wiener uses log link
2. **Missing Priors?** Most scripts don't explicitly specify drift rate priors
3. **Inconsistent SDs?** Different SD values (0.3, 0.5, 1.0, 1.5) without clear rationale
4. **Exponential Rates?** Some use exponential(1), some exponential(2)

---

**Bottom line:** I found the variations and assumed they were intentional, but you're right to verify this with literature! The prompt will help you get a proper evaluation.














