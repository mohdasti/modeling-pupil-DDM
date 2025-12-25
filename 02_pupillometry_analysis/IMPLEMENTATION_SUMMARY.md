# Implementation Summary: Dissertation Inclusion Decision System

## ✅ Completed Implementations

### 1. Subject Inclusion Decision Matrix
- **Location**: Section "Dissertation Inclusion Decisions (Ch2 / Ch3)"
- **Features**:
  - PASS/FAIL status for each analysis (C2 Primary, C2 Secondary, C2 Effort, C3 Behavior, C3 Pupil)
  - Fail reason codes for each analysis
  - CSV exports to `quality_control/output/inclusion/`
- **Files Created**:
  - `C2_primary_subject_task.csv`
  - `C2_secondary_subject_task.csv`
  - `C3_behavior_subject.csv`
  - `C3_pupil_subject.csv`

### 2. Tertile Feasibility Diagnostics
- **Location**: Section "Tertile Feasibility Diagnostics (Chapter 2 Primary)"
- **Features**:
  - Checks intensity coverage within each Cognitive AUC tertile
  - Heatmap showing tertile × intensity coverage for worst cases
  - Automated flags for `FAIL_TERTILE_INTENSITY_COVERAGE`

### 3. Missingness Model (MNAR Risk Check)
- **Location**: Section "Missingness Model: Is Missingness Condition-Linked?"
- **Features**:
  - Logistic regression: `pass_gatec ~ effort + difficulty + task`
  - Odds ratios and confidence intervals
  - Predicted probability plots by condition
  - Warnings for effort-linked missingness

### 4. DDM-Ready QC Section
- **Location**: Section "DDM-Ready QC (Chapter 3 Alignment)"
- **Features**:
  - RT distribution plots (overall and by effort)
  - Subject-level RT boxplots for worst cases
  - DDM-ready trial counts per subject × task
  - Flags for extreme RT medians

### 5. Sensitivity Analysis Panel
- **Location**: Section "Sensitivity Analysis Panel"
- **Features**:
  - Heatmap: gate threshold × quality cutoff → subject count
  - Line plots: threshold → retained trials (Tier1-2 vs Tier1-3)
  - Summary table across all parameter combinations
  - Recommended default parameters based on stability

## 📋 Remaining Actionable Cursor Prompts

### Prompt 1: Add Subject Report Cards (Visualization Enhancement)

```text
CURSOR PROMPT — Add "Subject Report Cards" visualization

In generate_pupil_data_report.qmd, add a new section after "Subject Overview (Pre-Filter)":

1) Create a function that generates a mini-panel per subject showing:
- GateC retention curve (threshold vs retained trials)
- Effort asymmetry bar chart (Low vs High effort missingness)
- Last_valid_time distribution histogram

2) Display report cards for:
- Subjects failing C2-primary (show why they fail)
- Subjects with effort asymmetry flags
- Random sample of passing subjects (for comparison)

3) Use patchwork or grid.arrange to create 2×2 or 3×3 grids of report cards.

This provides instant visual diagnosis of problematic subjects.
```

### Prompt 2: Add Effort × Difficulty Heatmap by Subject

```text
CURSOR PROMPT — Add "Subject × Condition Heatmap"

In generate_pupil_data_report.qmd, add after "Condition Balance" section:

1) Create a heatmap:
- Rows: subject_id
- Columns: interaction(task, effort_condition, difficulty_level)
- Fill: GateC Tier1-2 retained trials at threshold 0.80

2) Order rows by total retained trials (ascending) to surface problem subjects first.

3) Add color scale with clear breaks (0, 5, 10, 20+ trials).

4) Optionally: create separate heatmaps for ADT and VDT if too many subjects.

This instantly shows which subjects are unusable for which condition cells.
```

### Prompt 3: Add Trial Flow/Funnel Plot

```text
CURSOR PROMPT — Add "Trial Flow Funnel" visualization

In generate_pupil_data_report.qmd, add after "Filter Funnel / Loss Reasons Dashboard":

1) Create a funnel plot per task showing:
- Stage 1: Total trials (prefilter)
- Stage 2: Gate A passed (baseline + prestim)
- Stage 3: Gate C passed (cognitive AUC)
- Stage 4: Gate C + Tier1-2 (quality filter)
- Stage 5: Eligible for C2-primary (≥45 trials + tertile coverage)

2) Use geom_col or geom_bar with position="stack" or "dodge".

3) Add percentage labels on each bar.

4) Facet by task (ADT/VDT).

This shows the complete filtering pipeline and where trials are lost.
```

### Prompt 4: Enhance Response-Locked Availability (Already Started)

```text
CURSOR PROMPT — Enhance "Response-Locked Availability" section

The response-locked availability curve is already implemented. Add:

1) Summary statistics table:
- For each task × effort: median last_valid_time, % trials reaching response onset, % reaching 7.7s

2) Flag subjects where <50% of trials have valid pupil at response onset (critical for DDM with pupil predictors).

3) Add this flag to the inclusion matrix as a C3_pupil fail reason if applicable.

This provides quantitative justification for Gate C requirements.
```

### Prompt 5: Add Power Analysis Estimates (Optional)

```text
CURSOR PROMPT — Add "Power Analysis Estimates" section (optional enhancement)

In generate_pupil_data_report.qmd, add a new section:

1) For each analysis (C2-primary, C2-secondary, C3-pupil):
- Compute expected effect sizes detectable with current sample sizes
- Use simple power formulas or simulation-based estimates
- Report minimum detectable effect (MDE) for key contrasts

2) Compare to expected effect sizes from literature or pilot data.

3) Flag analyses that may be underpowered.

This helps justify sample size decisions to reviewers.
```

### Prompt 6: Add Cross-Validation Checks

```text
CURSOR PROMPT — Add "Cross-Validation: Pupil vs Behavioral Quality" section

In generate_pupil_data_report.qmd, add:

1) Correlate pupil quality metrics with behavioral quality metrics:
- overall_quality vs accuracy
- Gate C pass rate vs RT variability
- Missingness rate vs behavioral missingness

2) Flag subjects with good pupil but poor behavioral data (or vice versa).

3) Create scatter plots showing these relationships.

This detects systematic quality issues that might affect both modalities.
```

### Prompt 7: Add Temporal Stability Checks

```text
CURSOR PROMPT — Add "Temporal Stability: Quality Across Runs/Trials" section

In generate_pupil_data_report.qmd, add:

1) For each subject × task:
- Plot overall_quality vs trial_index (with loess smooth)
- Plot last_valid_time vs trial_index
- Compute slope: lm(overall_quality ~ trial_index)

2) Flag subjects with strongly negative slopes (quality degradation).

3) Create a summary table: subjects with drift risk.

This identifies fatigue/calibration drift issues.
```

## 🎯 Priority Order for Remaining Items

1. **Subject Report Cards** (High impact, moderate effort)
2. **Effort × Difficulty Heatmap by Subject** (High impact, low effort)
3. **Trial Flow Funnel** (Medium impact, low effort)
4. **Enhance Response-Locked Availability** (Medium impact, low effort)
5. **Cross-Validation Checks** (Low impact, moderate effort)
6. **Temporal Stability Checks** (Low impact, moderate effort)
7. **Power Analysis** (Optional, high effort)

## 📝 Notes

- All major inclusion criteria are now implemented
- CSV exports are functional and will be written to `quality_control/output/inclusion/`
- The report now provides explicit PASS/FAIL decisions with reason codes
- Sensitivity analysis panel allows threshold robustness checks
- Missingness model provides MNAR risk assessment

## 🔧 Testing Checklist

After rendering, verify:
- [ ] Inclusion matrix displays correctly with PASS/FAIL columns
- [ ] CSV files are created in `quality_control/output/inclusion/`
- [ ] Tertile diagnostics show correct intensity coverage
- [ ] Missingness model runs without errors
- [ ] DDM-ready QC shows RT distributions
- [ ] Sensitivity analysis panel displays heatmaps and line plots
- [ ] All fail reason codes are populated correctly



