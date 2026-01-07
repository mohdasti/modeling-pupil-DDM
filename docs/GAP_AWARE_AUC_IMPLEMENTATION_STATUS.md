# Gap-Aware AUC Implementation Status

## Summary

We've implemented gap-aware AUC calculation with QC metrics to address concerns about sparse sampling and large missing segments distorting AUC estimates.

## What's Been Implemented

### 1. Gap-Aware AUC Function (`make_quick_share_v7.R`)

- ✅ Replaced `compute_auc()` with `compute_auc_with_qc()` that:
  - Detects gaps >250ms (configurable, following Kret & Sjak-Shie 2019)
  - Splits window into contiguous segments where `dt ≤ gap_max`
  - Computes AUC within each segment separately (doesn't bridge large gaps)
  - Returns QC metrics: `auc`, `n_valid`, `window_duration`, `prop_valid`, `max_gap_ms`, `n_segments`

- ✅ Backward-compatible wrapper `compute_auc()` still exists

### 2. QC Report Updates (`pupil_data_report_advisor.qmd`)

- ✅ Added "Gap-Aware AUC Quality Control Metrics" section with:
  - Diagnostic scatter plots (cog_mean vs quality, colored by max_gap_ms)
  - Gap distribution histograms
  - Window duration diagnostics
  - Retention rate analysis with gap-aware exclusions

- ✅ Updated interpretation framework to include gap-aware decision rules

### 3. Documentation Updates

- ✅ Updated `AUC_CALCULATION_METHOD.md` with gap-aware approach and literature citations

## What Still Needs to Be Done

### 1. Update AUC Calculations in `make_quick_share_v7.R`

The `process_flat_file_v7()` function (around lines 400-520) currently uses `compute_auc()` which only returns the AUC value. We need to:

1. **Update cognitive AUC calculation** (most critical):
   ```r
   # Current:
   cog_auc <- compute_auc(cog_time, cog_pupil_corrected)
   
   # Should be:
   cog_auc_result <- compute_auc_with_qc(cog_time, cog_pupil_corrected)
   cog_auc <- cog_auc_result$auc
   cog_auc_n_valid <- cog_auc_result$n_valid
   cog_window_duration <- cog_auc_result$window_duration
   cog_auc_prop_valid <- cog_auc_result$prop_valid
   cog_auc_max_gap_ms <- cog_auc_result$max_gap_ms
   cog_auc_n_segments <- cog_auc_result$n_segments
   ```

2. **Update other AUC calculations** (total_auc, cog_auc_w3, cog_auc_respwin, cog_auc_w1p3) similarly

3. **Add QC metrics to output tibble** (around line 502):
   ```r
   tibble(
     # ... existing columns ...
     cog_auc = cog_auc,
     cog_auc_n_valid = cog_auc_n_valid,
     cog_window_duration = cog_window_duration,
     cog_auc_prop_valid = cog_auc_prop_valid,
     cog_auc_max_gap_ms = cog_auc_max_gap_ms,
     cog_auc_n_segments = cog_auc_n_segments,
     # ... rest of columns ...
   )
   ```

### 2. Add QC Metrics to ch2/ch3 Output Files

Update the `select()` statements when creating `ch2_triallevel` and `ch3_triallevel` (around lines 1302-1363) to include the new QC metrics:

```r
ch2_triallevel <- merged_v4_with_flags %>%
  select(
    # ... existing columns ...
    # Add gap-aware QC metrics
    cog_auc_n_valid, cog_window_duration, cog_auc_prop_valid,
    cog_auc_max_gap_ms, cog_auc_n_segments,
    # ... rest of columns ...
  )
```

### 3. Add Versioning to Prevent Overwriting

Update file writes (lines 1329, 1371) to include versioning:

```r
# Current:
write_csv(ch2_triallevel, file.path(V7_ANALYSIS_READY, "ch2_triallevel.csv"))

# Should be:
# Check if old version exists and backup
old_file <- file.path(V7_ANALYSIS_READY, "ch2_triallevel.csv")
if (file.exists(old_file)) {
  backup_file <- file.path(V7_ANALYSIS_READY, 
                           paste0("ch2_triallevel_v", 
                                  format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"))
  file.copy(old_file, backup_file)
  cat("  ✓ Backed up old version to:", basename(backup_file), "\n")
}
write_csv(ch2_triallevel, old_file)
```

## Next Steps

1. **Update AUC calculations** in `process_flat_file_v7()` to use `compute_auc_with_qc()`
2. **Add QC metrics to output tibble**
3. **Update ch2/ch3 select statements** to include QC metrics
4. **Add versioning** to file writes
5. **Re-run pipeline** to generate new datasets with gap-aware metrics
6. **Re-render QC report** to see the new diagnostics

## Testing

After implementation:
- Verify that new CSV files have the QC metric columns
- Check that gap-aware metrics make sense (max_gap_ms should be ≤ window_duration * 1000)
- Confirm that old files are backed up (not overwritten)
- Re-render QC report and verify gap-aware diagnostics appear

## References

- Kret & Sjak-Shie (2019): Recommend not interpolating gaps >250ms
- Burg et al.: Show that large gaps can distort AUC even with acceptable %-valid
- Modern Pupillometry (Papesh & Goldinger, 2024): Best practices for preprocessing

