# 🚀 START HERE: Simple Step-by-Step Guide

**You're right!** Running everything at once is too heavy. Run steps individually instead.

---

## ✅ Step 1: Prepare Data (Run this FIRST)

Open RStudio and run:

```r
source("01_data_preprocessing/r/prepare_ddm_only_data.R")
```

**Wait for it to finish** (~1-2 minutes). Check that it says "✓" at the end.

---

## ✅ Step 2: Verify Data (Quick Check)

```r
source("scripts/verify_ddm_data.R")
```

This just checks the file was created correctly. Very fast (~5 seconds).

---

## ✅ Step 3: Fit Standard-Only Bias Model (Optional but Recommended)

**This takes 30-60 minutes.** Start it and go do something else.

```r
source("04_computational_modeling/drift_diffusion/fit_standard_bias_only.R")
```

**Don't run the next step until this finishes!**

---

## ✅ Step 4: Fit Primary Model (Required)

**This also takes 30-60 minutes.** Start it and go do something else.

```r
source("04_computational_modeling/drift_diffusion/fit_primary_vza.R")
```

---

## 💡 That's It!

You don't need to run everything at once. Just run these steps one at a time:

1. ✅ Prepare data
2. ✅ Verify data  
3. ✅ Fit Standard bias model (optional)
4. ✅ Fit Primary model

Everything else (visualization, statistics, etc.) can wait until after models are fit.

---

## 📋 Full Details

See `RUN_PIPELINE_STEPS.md` for more details on what each step does.

---

**Start with Step 1 now!** 🎯















