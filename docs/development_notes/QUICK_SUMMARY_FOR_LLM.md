# Quick Summary for LLM - Bias Interpretation Issue

**TL;DR:** brms wiener model estimates bias z=0.569, but data shows 10.9% "Different" responses. This is a 46% mismatch - what's wrong?

## The Core Problem

**Model:** `rt | dec(dec_upper) ~ ...` where `dec_upper=1` means "Different"  
**Data:** 89.1% "Same", 10.9% "Different"  
**Model bias:** z = 0.569 (predicts ~57% "Different")  
**Reality:** Only 10.9% "Different"  

**Question:** How does brms interpret `dec()` and bias parameter `z`?

## Key Questions

1. In `rt | dec(dec_upper)`, does `dec_upper=1` mean upper or lower boundary?
2. Does bias z=0.569 predict 56.9% of responses hitting `dec()=1` boundary?
3. Could boundaries be reversed in our coding?
4. How should we verify correct interpretation?

## Files Available

- Model fitting script
- Diagnostic scripts showing the mismatch
- Parameter recovery script from codebase
- Summary documents

**Please help diagnose what's wrong!**

