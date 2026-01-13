# Chapter 3: Confound Mitigation for DDM-Pupil Coupling

**Last Updated**: January 2026  
**Status**: Recommendations for Chapter 3  
**Context**: Chapter 3 uses different windows than Chapter 2, but faces same confound issues

---

## Chapter 3 Window Context

**Primary Window (W3.0)**:
- **Time Range**: 4.65s to 7.65s (target+0.3s to target+3.3s)
- **Duration**: 3.0s
- **Rationale**: Captures full TEPR peak (max peak at ~7.30s)

**Sensitivity Window (W1.3)**:
- **Time Range**: 4.65s to 5.65s (target+0.3s to target+1.3s)
- **Duration**: 1.0s
- **Rationale**: Early window with minimal post-response contamination

**Same Confound Issues as Chapter 2**:
- Response screen appears at 4.70s (only 350ms after target at 4.35s)
- Button press overlaps with W3.0 for many trials (median RT ~0.6-0.7s → press at ~5.3-5.4s)
- W1.3 extends 0.95s into response period (ends at 5.65s)

---

## Confound Mitigation Recommendations for Chapter 3

### 1. Motor Buffer for W3.0 Window

**Approach**: Truncate W3.0 window 150ms before button press (same as Chapter 2).

**Implementation**:
- **Original W3.0 end**: 7.65s (target + 3.3s)
- **Motor-buffered end**: `min(7.65s, t_resp - 0.15s)`
- **Flag**: `cog_win_w3_truncated_by_motor` (computed if needed)

**Status**: ⚠️ Window definition can be computed; Full AUC computation requires re-processing flat files

**Recommendation**: 
- Use existing `cog_auc_w3` with RT as covariate for primary analyses
- Add motor-buffered W3.0 as sensitivity analysis when AUC computed

### 2. W1.3 Window is Already Conservative

**Current W1.3**: 4.65s to 5.65s (ends 0.95s into response period)

**Assessment**: 
- ✅ **Minimal post-response contamination**: Only 0.95s into response window
- ✅ **Ends before most button presses**: Median RT ~0.6-0.7s → press at ~5.3-5.4s, window ends at 5.65s
- ✅ **Already serves as sensitivity check**: Addresses post-response contamination concerns

**Recommendation**: Keep W1.3 as-is; it already provides conservative estimate.

### 3. RT as Covariate (CRITICAL)

**Approach**: Include RT in all DDM-pupil coupling models.

**Rationale**: 
- W3.0 window extends into response period
- RT correlates with decision state and pupil dynamics
- Prevents RT from "pretending" to be pupil coupling

**Model Structure**:
```r
# DDM parameter ~ pupil + RT + condition + interactions
ddm_model <- brm(
  drift ~ cog_auc_w3 + rt + condition + (1|sub),
  data = ch3_ddm_ready
)
```

**Status**: ✅ RT available in data; 📝 Modeling recommendation for analyses

### 4. Sensitivity: Compare W3.0 vs W1.3

**Approach**: Show that results hold across both windows.

**Rationale**:
- If W3.0 and W1.3 show similar patterns → robust to post-response contamination
- If W3.0 shows stronger effects → may reflect post-response processes (acknowledge in interpretation)

**Implementation**:
```r
# Primary: W3.0 (full TEPR)
model_w3 <- brm(
  drift ~ cog_auc_w3 + rt + condition + (1|sub),
  data = ch3_ddm_ready
)

# Sensitivity: W1.3 (early window)
model_w1p3 <- brm(
  drift ~ cog_auc_w1p3 + rt + condition + (1|sub),
  data = ch3_ddm_ready
)

# Compare effect sizes and significance
```

**Status**: ✅ Both windows available in data; 📝 Analysis recommendation

### 5. Slow-RT Sensitivity Subset

**Approach**: Test on trials where button press happens after W3.0 window ends.

**Implementation**:
- **Flag**: `cog_win_w3_uncontaminated` = `t_resp > 7.65s + 0.15s = 7.80s`
- Use this subset to show results aren't driven by motor contamination

**Status**: ⚠️ Flag can be computed; 📝 Sensitivity analysis recommendation

---

## Recommended Analysis Strategy for Chapter 3

### Primary Analysis

1. **Use W3.0 window** (`cog_auc_w3`) as primary TEPR metric
2. **Include RT as covariate** in all models
3. **Interpret as**: "Post-target decision/response-period TEPR" (not pure pre-response predictor)
4. **Acknowledge**: W3.0 extends into response period; this is by design to capture full TEPR

### Sensitivity Analyses

1. **W1.3 window** (`cog_auc_w1p3`): Early window with minimal post-response contamination
2. **Mean dilation** (`cog_mean_w1p3`): Less dependent on missing samples
3. **Slow-RT subset**: Trials where motor can't contaminate W3.0
4. **Motor-buffered W3.0**: When AUC computed (future enhancement)

### Code Example

```r
# Primary: W3.0 with RT covariate
ch3_primary <- ch3_data %>%
  filter(
    ddm_ready == TRUE,
    !is.na(cog_auc_w3),
    !is.na(rt)
  )

model_primary <- brm(
  drift ~ cog_auc_w3 + rt + condition + cog_auc_w3:condition + (1|sub),
  data = ch3_primary
)

# Sensitivity: W1.3 (early window)
ch3_w1p3 <- ch3_data %>%
  filter(
    ddm_ready == TRUE,
    !is.na(cog_auc_w1p3),
    !is.na(rt)
  )

model_w1p3 <- brm(
  drift ~ cog_auc_w1p3 + rt + condition + cog_auc_w1p3:condition + (1|sub),
  data = ch3_w1p3
)

# Compare: Do both windows show similar patterns?
```

---

## Updates Needed for Chapter 3

### 1. Update `chap3_ddm_results.qmd`

**Add confound mitigation section:**
- Acknowledge temporal overlap with response screen and button press
- Describe RT as covariate approach
- Report W3.0 vs W1.3 comparison
- Note motor buffer truncation available for future analyses

### 2. Update Chapter 3 Documentation

**Create/update**:
- Window selection rationale (already exists: `data/pupil_processed/qc/ch3_extension_v3/ch3_decision_memo.md`)
- Add confound mitigation section
- Update interpretation guidelines

### 3. Consider Motor-Buffered W3.0 Computation

**When needed**: Create script to compute motor-buffered W3.0 AUC (truncated at `t_resp - 0.15s`)

**For now**: Use existing `cog_auc_w3` with RT covariate + W1.3 sensitivity

---

## Key Differences: Chapter 2 vs Chapter 3

| Aspect | Chapter 2 | Chapter 3 |
|--------|-----------|-----------|
| **Primary Window** | 4.85-6.05s (1.20s fixed) | 4.65-7.65s (3.0s, W3.0) |
| **Sensitivity Window** | Pre-response (decision-aligned) | W1.3 (4.65-5.65s, early) |
| **Window Rationale** | Stimulus-locked, RT-independent | Captures full TEPR peak |
| **Confound Mitigation** | Motor buffer + pre-response | RT covariate + W1.3 comparison |
| **Primary Metric** | `cog_mean` (mean dilation) | `cog_auc_w3` (full AUC) |

**Common Elements**:
- Both face response screen (4.70s) and button press confounds
- Both should include RT as covariate
- Both benefit from sensitivity analyses
- Motor buffer columns available in both datasets

---

## Next Steps for Chapter 3

1. ✅ **Motor buffer columns**: Already in `ch3_triallevel.csv`
2. 📝 **Update `chap3_ddm_results.qmd`**: Add confound mitigation section
3. 📝 **Modeling**: Include RT as covariate in all DDM-pupil models
4. 📝 **Sensitivity**: Compare W3.0 vs W1.3 results
5. 📝 **Documentation**: Update Chapter 3 window documentation with confound mitigation

---

## References

- **Mathôt (2022)**: Methods in cognitive pupillometry - RT/response confounds
- **de Gee et al. (2014)**: Decision-related pupil dilation
- **Urai et al. (2017)**: Post-choice pupil relates to decision uncertainty
- **Chapter 3 Decision Memo**: `data/pupil_processed/qc/ch3_extension_v3/ch3_decision_memo.md`

---

**Status**: Recommendations ready; Implementation pending in Chapter 3 analyses
