# Manuscript Update Summary: Bias Formula Constraint

## Date: November 27, 2025

## Changes Made

### 1. Model Specification Section (Primary Model)

**Location**: `reports/chap3_ddm_results.qmd`, around line 652

**Change**: Added explicit explanation of why bias does not vary by difficulty:

```markdown
**Critical constraint on bias**: Starting-point bias ($z$) was allowed to vary 
by Task and Effort (which are known to the participant pre-trial) but was 
constrained to be constant across Difficulty levels, as trial difficulty was 
randomized and thus unknown at the onset of the decision process. This 
specification reflects the causal structure of the experimental design: 
participants cannot adjust their starting point based on an unknown future 
event (trial difficulty). Task differences in bias (if tasks were blocked) and 
effort differences (if effort was cued) are valid pre-stimulus settings, 
whereas difficulty-dependent bias would imply participants could anticipate 
trial difficulty, which contradicts the randomized design.
```

### 2. Removed Outdated Model Description

**Location**: `reports/chap3_ddm_results.qmd`, around line 676

**Change**: Removed outdated description of old bias formula that included difficulty level. This was a leftover from an earlier model specification.

**Old text** (removed):
```markdown
- **Bias (z)**: `bias ~ difficulty_level + task + (1 | subject_id)`
```

**New text**: Simple note that the primary model uses the methodologically sound bias specification.

---

## Rationale

Based on expert methodological guidance:

1. **Causal structure**: Trials are randomized/interleaved, so participants cannot know difficulty pre-trial
2. **Bias as pre-stimulus setting**: Starting-point bias must be set before trial onset
3. **Theoretical validity**: Allowing bias to vary by difficulty would imply participants can anticipate trial difficulty, contradicting randomization

---

## Verification Checklist

- [x] Methods section updated with bias constraint explanation
- [x] Outdated model description removed
- [ ] All tables/figures regenerated after model refit (Nov 27, 04:53)
- [ ] No other references to old bias formula remain in manuscript
- [ ] Results section aligns with updated bias specification

---

## Next Steps

1. **Verify output files**: Check timestamps of CSV/PNG files in `output/publish/` and `output/figures/`
2. **Re-run if needed**: If files predate Nov 27, 04:53, regenerate using:
   - `scripts/02_statistical_analysis/extract_comprehensive_parameters.R`
   - `scripts/02_statistical_analysis/create_ddm_visualizations.R`
3. **Final review**: Ensure Results section correctly interprets bias as constant across difficulty

---

## Key Scientific Message

**Bias does not vary by difficulty** - this is a feature, not a limitation. It reflects the correct causal structure of the experimental design and ensures the model respects the physical reality that participants cannot anticipate trial difficulty.

