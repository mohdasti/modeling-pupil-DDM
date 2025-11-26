# Commit Message: Fix bias interpretation and validation logic

## Major Changes

### 1. Fixed Critical Bias Interpretation Issue
- **Root cause:** Tight drift constraint (`normal(0, 0.03)`) prevented model from fitting Standard trials correctly
- **Solution:** Relaxed drift prior to `normal(0, 2)` to allow negative drift (evidence for "Same")
- **Result:** Model now estimates negative drift (v = -1.404) correctly explaining 89% "Same" responses

### 2. Fixed Validation Logic
- **Problem:** Validation compared bias directly to data proportions (only valid when drift = 0)
- **Solution:** Implemented analytical solution using Wiener process formula to compute predicted proportions from v + a + z
- **Result:** Validation now correctly accounts for drift effects, showing model predictions match data

### 3. Updated Data Preparation
- Created separate scripts for DDM-only and DDM-pupil data preparation
- Ensured response-side coding (`dec_upper`) is correctly implemented
- Added comprehensive validation checks using `validate_ddm_data()`

### 4. Updated Model Fitting Scripts
- Standard-only bias model: Fixed drift prior, added analytical validation
- Primary model: Uses `dec_upper`, includes validation
- All scripts use correct response-side coding

### 5. Comprehensive Validation System
- `R/validate_experimental_design.R`: Validates experimental design constraints
- `R/validate_ddm_parameters.R`: Validates parameter estimates (now with analytical solution)
- Both integrated into model fitting pipeline

## Files Added
- Data preparation scripts: `prepare_ddm_only_data.R`, `prepare_ddm_pupil_data.R`
- Model fitting scripts: `fit_standard_bias_only.R`, `fit_primary_vza.R`
- Validation scripts: `validate_experimental_design.R`, `validate_ddm_parameters.R`
- Diagnostic scripts: Various bias investigation scripts
- Documentation: Multiple summary and guide documents

## Files Modified
- Updated data paths to new raw data location
- Updated column mappings for new data structure
- Fixed response-side coding implementation
- Updated validation logic throughout

## Key Insights
1. Standard trials can have negative drift (evidence FOR identity), not just zero drift
2. Validation must use analytical solution when drift is non-zero
3. Response-side coding was correct all along - issue was model specification

## Status
✅ Standard-only bias model: Converged successfully, validated correctly
⏳ Primary model: Ready to run with updated validation
⏳ Other models: Need systematic review and update

