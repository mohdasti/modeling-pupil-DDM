# Implementation of Research-Based Fixes

## Fixes Applied ✅

### 1. Complete NDT Initialization
- ✅ Added `b_ndt_Intercept = log(0.20)` (already had)
- ✅ Added `sd_ndt_subject_id__Intercept = 0.05` (NEW - clamps RE SD)
- ✅ Added `z_ndt_subject_id = rep(0, n_subjects)` (NEW - zeros raw REs)

### 2. Tightened NDT SD Prior
- ✅ Changed from `student_t(3, 0, 0.3)` to `student_t(3, 0, 0.2)`

### 3. Added init_r
- ✅ Set `init_r = 0.02` for small jitter on unspecified parameters

### 4. Initialized Other RE Components
- ✅ Also initialized bs and bias REs safely (prevents other explosions)

## Key Insight
The critical issue was that `z_ndt_subject_id` (raw random effects) were being randomly initialized by Stan, causing extreme ndt values even when intercept was safe. Zeroing them at init prevents this.

## Next Steps
1. Test with a single model first
2. If still issues, consider raising RT floor to 225-250ms
3. If still issues, simplify by removing ndt RE first, then add back

