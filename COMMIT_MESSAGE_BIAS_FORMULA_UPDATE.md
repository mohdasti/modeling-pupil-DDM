# Commit Message: Update Bias Formula Based on Expert Guidance

## Summary

Update primary DDM model to remove `difficulty_level` from bias formula based on expert methodological guidance. Bias should only vary by pre-trial known factors (task, effort), not by difficulty which is unknown pre-trial.

## Changes

### Model Specification Updates

1. **Primary Model Script** (`04_computational_modeling/drift_diffusion/fit_primary_vza.R`):
   - Changed bias formula from: `bias ~ difficulty_level + task + (1|subject_id)`
   - Changed bias formula to: `bias ~ task + effort_condition + (1|subject_id)`
   - Added comments explaining rationale (trials are randomized, participants can't adjust bias based on unknown difficulty)

### Expert Guidance Documentation

2. **Expert Guidance Summary** (`EXPERT_GUIDANCE_BIAS_AND_CONTRASTS.md`):
   - Comprehensive summary of expert recommendations
   - Key findings:
     - Standard trials are NOT zero-drift (they have negative drift representing evidence for "Same")
     - Bias should NOT vary by difficulty_level because trials are randomized
     - Primary contrast should focus on Easy vs. Hard for difficulty effects
   - Implementation status tracking

### Model Comparison Tools

3. **Model Comparison Script** (`scripts/02_statistical_analysis/compare_bias_formulas_loo.R`):
   - New script to compare old vs. new model specifications using LOO cross-validation
   - Will determine if removing difficulty from bias formula improves or worsens fit

### Prompt for Expert Consultation

4. **Expert Consultation Prompt** (`PROMPT_FOR_LLM_BIAS_ESTIMATION_AND_CONTRASTS_QUESTION.md`):
   - Comprehensive prompt created to seek expert guidance on bias estimation and contrast selection
   - Includes full experimental design, current approach, and specific questions

## Rationale

Based on expert guidance:
- Trials are **randomized/interleaved** - participants don't know if next trial will be Easy or Hard
- Bias is a **pre-stimulus setting** - participants cannot adjust starting point based on unknown difficulty
- Including `difficulty_level` in bias formula likely captures noise or "leakage" from drift rate
- Bias should only vary by factors known pre-trial: Task (if blocked) and Effort (if cued)

## Impact

- Model specification now reflects correct causal structure (only known factors affect bias)
- Will need to refit primary model with new specification
- Will need to compare models using LOO to ensure new specification doesn't worsen fit
- Parameter extraction and contrasts will need to be regenerated after refitting

## Next Steps

1. Refit primary model with updated bias specification
2. Compare old vs. new models using LOO
3. Update parameter extraction scripts if needed
4. Update documentation/manuscript with new understanding of Standard trials and bias

