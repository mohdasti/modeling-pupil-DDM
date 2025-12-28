# Pipeline Error Fix: "Expected input to be finite"

**Date**: December 2025  
**Issue**: MATLAB pipeline failing with "ERROR: Expected input to be finite"  
**Root Cause**: NaN values from zero-to-NaN conversion being passed to `filtfilt()` function

---

## PROBLEM

After implementing the zero-to-NaN conversion fix, the pipeline started failing with:
```
ERROR: Expected input to be finite.
```

This occurs because:
1. Zeros are converted to NaN (line 362-366)
2. Trial data is extracted (line 414) - now contains NaN values
3. Butterworth filter is applied (line 469-477) - `filtfilt()` requires finite inputs
4. **FAILURE**: `filtfilt()` cannot process NaN values

---

## SOLUTION

Updated the filtering code to handle NaN values properly:

1. **Identify valid (finite) samples** before filtering
2. **Filter only valid samples** using `filtfilt()`
3. **Preserve NaN locations** in the filtered output
4. **Add error handling** in case filtering fails

### Code Changes

**File**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m` (lines 469-495)

**Before**:
```matlab
[b, a] = butter(8, cutoff_freq / (CONFIG.original_fs / 2), 'low');
trial_pupil_filtered = filtfilt(b, a, trial_pupil);  % FAILS if trial_pupil has NaN
```

**After**:
```matlab
valid_mask = isfinite(trial_pupil) & trial_valid > 0;

if sum(valid_mask) > 8  % Need enough valid samples
    [b, a] = butter(8, cutoff_freq / (CONFIG.original_fs / 2), 'low');
    trial_pupil_filtered = trial_pupil;  % Start with original (includes NaN)
    trial_pupil_valid = trial_pupil(valid_mask);
    if ~isempty(trial_pupil_valid) && length(trial_pupil_valid) > 8
        try
            trial_pupil_filtered(valid_mask) = filtfilt(b, a, trial_pupil_valid);
        catch
            trial_pupil_filtered = trial_pupil;  % Fallback if filtering fails
        end
    end
else
    trial_pupil_filtered = trial_pupil;  % Not enough valid samples
end
```

---

## VERIFICATION

After this fix, the pipeline should:
1. ✅ Convert zeros to NaN (as intended)
2. ✅ Filter only valid (finite) samples
3. ✅ Preserve NaN locations in filtered output
4. ✅ Handle cases with insufficient valid samples
5. ✅ Continue processing without errors

---

## NEXT STEPS

1. **Re-run the pipeline** with the fix applied
2. **Verify** that errors are resolved
3. **Check output** that zeros are converted to NaN
4. **Confirm** filtering still works correctly

---

**Status**: Fix applied, ready for re-testing









