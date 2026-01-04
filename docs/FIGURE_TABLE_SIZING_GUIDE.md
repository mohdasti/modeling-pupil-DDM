# Figure and Table Sizing Guide for PDF Output

## Overview

This guide provides a systematic approach to ensure all figures and tables fit properly within PDF page boundaries and that captions don't overlap with page numbers.

## Analysis Results

**Run the analysis script:**
```bash
Rscript scripts/analyze_figure_table_sizing.R
```

**Current Status:**
- **Total items:** 55 (29 figures, 26 tables)
- **Figures needing resizing:** 15
- **Figures with long captions:** 26
- **PDF figures needing manual check:** 14

**Detailed results:** `output/diagnostics/figure_table_sizing_analysis.csv`

## PDF Page Constraints

- **Page size:** Letter (8.5" × 11")
- **Margins:** 1 inch on all sides
- **Text width:** 6.5 inches
- **Text height:** 9.0 inches
- **Max figure width (portrait):** 6.5 inches
- **Recommended figure width:** 5.5-6.0 inches (leaves margin)
- **Max caption lines before wrapping issues:** ~3 lines

## Figure Generation Guidelines

### Standard Dimensions for PDF

When creating figures in R/ggplot2, use these dimensions:

```r
# For standard portrait figures
ggsave("figure_name.pdf", 
       plot = p, 
       width = 6.5,    # inches (max page width)
       height = 4.0,   # inches (adjust based on aspect ratio)
       units = "in",
       dpi = 300)

# For PNG figures (if needed)
ggsave("figure_name.png",
       plot = p,
       width = 6.5,
       height = 4.0,
       units = "in",
       dpi = 300)
```

### Aspect Ratio Guidelines

- **Standard plots:** 6.5" × 4.0" (aspect ratio ~1.6:1)
- **Square plots:** 5.5" × 5.5"
- **Wide plots (landscape):** Consider landscape orientation or split into panels
- **Tall plots:** Max height ~8.0" (leaves room for caption)

### Landscape Orientation

For very wide figures (aspect ratio > 1.5), consider:

1. **Landscape page orientation** (add to QMD chunk):
   ```r
   #| fig-pos: "landscape"
   ```

2. **Or split into multiple panels** using `patchwork` or `cowplot`

## Figures Requiring Immediate Attention

Based on the analysis, these figures need resizing:

### High Priority (Too Wide)

1. **fig-trial-structure** (Trial_Structure.png)
   - Current: 25.51" × 27.68"
   - Recommended: 6.18" × 6.70"
   - **Action:** Resize in figure generation script

2. **fig-pupil-ddm-scatter-phasicW3-bs** (pupil_ddm_scatter_phasicW3_bs.png)
   - Current: 15.25" × 12.71"
   - Recommended: 6.18" × 5.15"
   - **Script:** `scripts/02_statistical_analysis/07_pupil_ddm_finalize.R` (line ~135)

3. **fig-pupil-ddm-scatter-phasicW1p3-v** (pupil_ddm_scatter_phasicW1p3_v.png)
   - Current: 15.25" × 12.71"
   - Recommended: 6.18" × 5.15"
   - **Script:** `scripts/02_statistical_analysis/07_pupil_ddm_finalize.R` (line ~135)

4. **fig-pupil-ddm-scatter-tonic-v** (pupil_ddm_scatter_tonic_v.png)
   - Current: 15.25" × 12.71"
   - Recommended: 6.18" × 5.15"
   - **Script:** `scripts/02_statistical_analysis/07_pupil_ddm_finalize.R` (line ~135)

5. **fig-pupil-ddm-robustness** (pupil_ddm_robustness.png)
   - Current: 25.42" × 12.71" (aspect ratio 2.0)
   - Recommended: 6.18" × 3.09" OR landscape orientation
   - **Action:** Consider landscape or split into two panels

6. **fig-bias-by-task** (plot2_bias_by_task.png)
   - Current: 20.34" × 15.25"
   - Recommended: 6.18" × 4.63"

7. **fig-parameter-correlation** (plot4_parameter_correlation.png)
   - Current: 20.34" × 15.25"
   - Recommended: 6.18" × 4.63"

8. **fig-drift-rate-difficulty** (plot1_drift_rate_by_difficulty.png)
   - Current: 25.42" × 15.25" (aspect ratio 1.67)
   - Recommended: 6.18" × 3.70" OR landscape orientation

9. **fig-pdiff-heatmap** (fig_pdiff_heatmap.png)
   - Current: 20.34" × 15.25"
   - Recommended: 6.18" × 4.63"

10. **fig-ppc-small-multiples** (fig_ppc_small_multiples.png)
    - Current: 20.34" × 11.44" (aspect ratio 1.78)
    - Recommended: 6.18" × 3.47" OR landscape orientation

11. **fig-sanity-rt-asymmetry** (sanity_check1_rt_asymmetry.png)
    - Current: 20.34" × 15.25"
    - Recommended: 6.18" × 4.63"

12. **fig-sanity-hard-drift** (sanity_check2_hard_drift.png)
    - Current: 20.34" × 15.25"
    - Recommended: 6.18" × 4.63"

13. **fig-sanity-subject-heterogeneity** (sanity_check3_subject_heterogeneity.png)
    - Current: 20.34" × 15.25"
    - Recommended: 6.18" × 4.63"

14. **fig-ppc-validation** (plot3_ppc_validation.png)
    - Current: 25.42" × 15.25" (aspect ratio 1.67)
    - Recommended: 6.18" × 3.70" OR landscape orientation

15. **fig-decision-landscape** (fig_decision_landscape_3d.png)
    - Current: 41.67" × 33.33"
    - Recommended: 6.18" × 4.94"

### PDF Figures (Need Manual Dimension Check)

These PDF figures need manual checking of dimensions:
- fig-ddm-process.pdf
- fig-ndt-prior-posterior.pdf
- fig-loo.pdf
- fig-fixed-effects-adt.pdf
- fig-fixed-effects-vdt.pdf
- fig-subject-parameter-distribution.pdf
- fig-integrated-condition-effects.pdf
- fig-brinley-plot.pdf
- fig-ppc-rt-overlay.pdf
- fig-qp.pdf
- fig-caf.pdf
- fig-ppc-heatmaps.pdf

**To check PDF dimensions:**
```bash
# Using ImageMagick (if installed)
identify -format "%wx%h" output/figures/fig_ddm_process.pdf

# Or use R
library(magick)
img <- image_read_pdf("output/figures/fig_ddm_process.pdf")
image_info(img)
```

## Caption Length Issues

**26 figures have long captions** (>3 estimated lines). Long captions can:
- Overlap with page numbers
- Cause layout issues
- Make figures appear cramped

### Recommendations for Long Captions:

1. **Shorten captions** where possible
2. **Split into caption + note:**
   ```r
   #| fig-cap: "Short main caption"
   #| fig-subcap: "Detailed description in methods section"
   ```

3. **Move detailed descriptions** to the main text
4. **Use footnotes** for additional details

### Figures with Very Long Captions (>10 lines):

- fig-ddm-process (13 lines)
- fig-trial-structure (15 lines)
- fig-tepr-timecourse (10 lines)
- fig-parameter-correlation (11 lines)
- fig-integrated-condition-effects (12 lines)
- fig-brinley-plot (13 lines)
- fig-drift-rate-difficulty (13 lines)
- fig-sanity-rt-asymmetry (11 lines)
- fig-sanity-subject-heterogeneity (10 lines)
- fig-ppc-validation (10 lines)

## Table Considerations

Tables are generated dynamically using `gt` package. For wide tables:

1. **Check column count** - tables with >6 columns may overflow
2. **Use `tab_options()`** to control table width:
   ```r
   gt_table %>%
     tab_options(table.width = pct(100))  # For HTML
   ```

3. **For PDF:** Consider:
   - Rotating to landscape
   - Splitting into multiple tables
   - Reducing font size
   - Using abbreviations

## Systematic Fix Workflow

### Step 1: Update Figure Generation Scripts

For each figure needing resize, update the `ggsave()` call:

**Example - Before:**
```r
ggsave("pupil_ddm_scatter_phasicW3_bs.png",
       plot = p, 
       width = 6, 
       height = 5, 
       dpi = 300)
```

**Example - After (for PDF):**
```r
ggsave("pupil_ddm_scatter_phasicW3_bs.png",
       plot = p,
       width = 6.18,   # Recommended width
       height = 5.15,  # Maintains aspect ratio
       units = "in",
       dpi = 300)
```

### Step 2: Regenerate Figures

After updating scripts, regenerate all figures:
```bash
# Run figure generation scripts
Rscript scripts/02_statistical_analysis/07_pupil_ddm_finalize.R
# ... other figure generation scripts
```

### Step 3: Verify Dimensions

Re-run the analysis script to verify:
```bash
Rscript scripts/analyze_figure_table_sizing.R
```

### Step 4: Test PDF Rendering

Render the PDF and check:
- All figures fit within page boundaries
- Captions don't overlap page numbers
- Tables don't overflow

## Quick Reference: Recommended Dimensions

| Figure Type | Width (in) | Height (in) | Aspect Ratio |
|------------|------------|-------------|--------------|
| Standard plot | 6.5 | 4.0 | 1.6:1 |
| Square plot | 5.5 | 5.5 | 1:1 |
| Wide plot | 6.5 | 3.5-4.0 | 1.6-1.9:1 |
| Tall plot | 5.0-6.0 | 7.0-8.0 | 0.7-0.9:1 |
| Landscape | 9.0 | 6.5 | 1.4:1 (rotated) |

## Landscape Orientation Setup

For figures that are too wide even at 6.5", use landscape:

1. **In QMD chunk:**
   ```r
   #| fig-pos: "landscape"
   ```

2. **Or in YAML for specific sections:**
   ```yaml
   pdf:
     fig-pos: "landscape"  # For entire document
   ```

3. **Generate landscape figure:**
   ```r
   ggsave("wide_figure.pdf",
          plot = p,
          width = 9.0,   # Landscape width
          height = 6.5,  # Landscape height
          units = "in")
   ```

## Next Steps

1. ✅ Analysis complete - review `output/diagnostics/figure_table_sizing_analysis.csv`
2. ⏳ Update figure generation scripts with recommended dimensions
3. ⏳ Regenerate all figures
4. ⏳ Re-run analysis to verify
5. ⏳ Test PDF rendering
6. ⏳ Address caption length issues (shorten or restructure)
7. ⏳ Check table widths manually

## Script Locations

Key figure generation scripts to update:
- `scripts/02_statistical_analysis/07_pupil_ddm_finalize.R` - Scatter plots
- `scripts/02_statistical_analysis/06_pupil_ddm_integration.R` - Integration plots
- `scripts/02_statistical_analysis/create_ddm_visualizations.R` - DDM visualizations
- `scripts/R/fig_ddm_process.R` - DDM process diagram
- Other visualization scripts in `scripts/` directory

