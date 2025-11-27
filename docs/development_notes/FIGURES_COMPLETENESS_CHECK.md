# Figures Completeness Check

## Bias Models Figures

### ✅ Complete Figures

1. **fig_bias_forest** - Bias (z) by task/effort
   - Status: ✅ COMPLETE (all 4 conditions after fix)
   - Shows: ADT-Low, ADT-High, VDT-Low, VDT-High
   - File: `R/fig_bias_forest.R`

2. **fig_v_standard_posterior** - Posterior of v(Standard) with prior overlay
   - Status: ✅ COMPLETE (single parameter, no conditions needed)
   - Shows: Posterior distribution of drift on Standard trials
   - File: `R/fig_v_standard_posterior.R`

3. **fig_ppc_small_multiples** - PPC best/median/worst cells
   - Status: ✅ COMPLETE (uses all 12 cells, selects best/median/worst)
   - Shows: Best, median, and worst cells by QP RMSE
   - File: `R/fig_ppc_small_multiples.R`

4. **fig_pdiff_heatmap** - Observed vs predicted p("different")
   - Status: ✅ COMPLETE (uses all cells from data)
   - Shows: All 12 cells (2 tasks × 2 effort × 3 difficulty)
   - File: `R/fig_pdiff_heatmap.R`

### Other Figures (Not Bias-Specific)

5. **fig_design_timeline** - Task design timeline
   - Status: ✅ COMPLETE (design schematic, no conditions)

6. **fig_loo** - LOO comparison
   - Status: ✅ COMPLETE (model comparison, no conditions)

7. **fig_fixed_effects** - Fixed effects forest plots
   - Status: ✅ COMPLETE (separate plots for ADT and VDT)

8. **fig_ppc_rt_overlay** - RT distribution overlays
   - Status: ✅ COMPLETE (all conditions)

9. **fig_qp** - Quantile-probability plots
   - Status: ✅ COMPLETE (all conditions)

10. **fig_caf** - Conditional accuracy function
    - Status: ✅ COMPLETE (all conditions)

11. **fig_ppc_heatmaps** - PPC residual heatmaps
    - Status: ✅ COMPLETE (all conditions)

12. **fig_ndt_prior_posterior** - NDT prior vs posterior
    - Status: ✅ COMPLETE (single parameter)

## Summary

**All bias-specific figures are now complete:**
- ✅ fig_bias_forest: Fixed to include all 4 conditions
- ✅ fig_v_standard_posterior: Complete (single parameter)
- ✅ fig_ppc_small_multiples: Complete (uses all 12 cells)
- ✅ fig_pdiff_heatmap: Complete (uses all 12 cells)

**No re-running of analyses needed** - the models already included all conditions. Only the reporting scripts needed fixes, which are now complete.
