# Publication Readiness Checklist for Pupil Data

Use this checklist to systematically assess your pupil data before seeking expert guidance or submitting for publication.

## Pre-Assessment: Data Collection

- [ ] All subjects completed both tasks (ADT and VDT)
- [ ] All conditions are represented (Low/High effort × Standard/Easy/Hard difficulty)
- [ ] Minimum number of trials per condition (recommend: ≥20-30 trials)
- [ ] Data collection protocol was consistent across subjects
- [ ] Equipment calibration and validation documented

## Data Quality Assessment

### Quality Metrics
- [ ] Mean quality (baseline_quality, overall_quality) ≥ 0.80 across all trials
- [ ] Quality metrics reported by subject, task, and condition
- [ ] No systematic quality differences between conditions (would suggest artifacts)
- [ ] Quality distributions are reasonable (not bimodal, not heavily skewed)

### Missing Data
- [ ] Missing data patterns documented and reported
- [ ] Missing data is not systematic (e.g., not all missing from one condition)
- [ ] Missing data percentage is acceptable (<10-15% for key metrics)
- [ ] Missing data handling strategy is justified

### Data Completeness
- [ ] All subjects have data for both tasks (or exclusion is justified)
- [ ] All conditions have sufficient trials (≥20-30 per condition)
- [ ] No subjects with <5 runs per task (or exclusion is justified)
- [ ] Trial counts are balanced across conditions (or imbalance is addressed)

## Statistical Power

- [ ] Sample size is adequate for planned analyses
- [ ] Power analysis conducted (or sample size justification provided)
- [ ] Effect sizes are detectable given sample size
- [ ] No conditions with insufficient power (or noted as exploratory)

## Methodological Rigor

### Baseline Correction
- [ ] Baseline window is appropriate (-0.5s to 0s is standard)
- [ ] Baseline quality is acceptable (≥80% valid data)
- [ ] Baseline stability is verified (no drift, no artifacts)
- [ ] Baseline correction method is documented

### AUC Calculation
- [ ] AUC method is appropriate (Zenon et al. 2014 is standard)
- [ ] Time windows are justified (Total AUC: 0s to response; Cognitive AUC: 4.65s to response)
- [ ] 300ms latency offset for Cognitive AUC is justified
- [ ] Trapezoidal integration is implemented correctly

### Quality Filtering
- [ ] Quality threshold (80%) is appropriate and justified
- [ ] Quality filtering is consistent across conditions
- [ ] Excluded trials are documented and reported
- [ ] Alternative thresholds were considered

## Sanity Checks

### Data Distributions
- [ ] AUC values are within expected ranges (no extreme outliers)
- [ ] Distributions are reasonable (check normality, skewness)
- [ ] Outliers are identified and handled appropriately
- [ ] No obvious artifacts or data collection errors

### Condition Effects
- [ ] Expected direction of effects (e.g., High > Low effort)
- [ ] Effect magnitudes are reasonable
- [ ] No unexpected patterns suggesting issues
- [ ] Order effects, practice effects, fatigue effects checked

### Cross-Validation
- [ ] Pupil metrics correlate with behavioral measures (RT, accuracy) as expected
- [ ] Difficulty manipulation is working (Easy > Hard performance)
- [ ] Effort manipulation is working (High > Low effort effects)
- [ ] Internal consistency checks passed

## Reporting Requirements

### Methods Section
- [ ] Pupil recording setup described (equipment, sampling rate, calibration)
- [ ] Preprocessing steps documented (baseline correction, quality metrics)
- [ ] AUC calculation method described (with references)
- [ ] Quality filtering criteria specified
- [ ] Exclusion criteria documented

### Results Section
- [ ] Descriptive statistics for all key variables
- [ ] Quality metrics reported (mean, range, by condition)
- [ ] Trial counts by condition reported
- [ ] Missing data reported
- [ ] Effect sizes reported (not just p-values)

### Figures
- [ ] Waveform plots showing condition effects
- [ ] Quality distribution plots
- [ ] Appropriate error bars/confidence intervals
- [ ] Event markers and timeline bars clearly labeled

### Tables
- [ ] Subject characteristics table
- [ ] Trial counts by condition
- [ ] Quality metrics summary
- [ ] Descriptive statistics table

## Limitations and Caveats

- [ ] Sample size limitations acknowledged
- [ ] Missing data limitations discussed
- [ ] Quality threshold limitations noted
- [ ] Methodological limitations discussed
- [ ] Generalizability limitations considered

## Additional Considerations

### Open Science
- [ ] Data sharing plan (if applicable)
- [ ] Code availability
- [ ] Preregistration (if applicable)

### Ethical Considerations
- [ ] IRB approval obtained
- [ ] Informed consent obtained
- [ ] Data privacy protected

## Red Flags to Watch For

⚠️ **Critical Issues (Must Fix)**:
- Quality metrics < 0.70 consistently
- >20% missing data in key conditions
- Systematic missing data patterns
- Extreme outliers suggesting artifacts
- No effect of effort manipulation (suggests manipulation failure)
- Quality differs systematically between conditions

⚠️ **Important Concerns (Should Fix)**:
- Quality metrics 0.70-0.80 (borderline)
- 10-20% missing data
- Unbalanced trial counts across conditions
- Some subjects with very few trials
- Unexpected null effects (may indicate power issues)

⚠️ **Minor Issues (Note but Acceptable)**:
- Quality metrics 0.80-0.85 (good but not perfect)
- 5-10% missing data
- Slight imbalances in trial counts
- Some variability in quality across subjects

## Before Seeking Expert Guidance

Complete this checklist and note:
- ✅ Items that are satisfactory
- ⚠️ Items that need attention
- ❌ Items that are problematic

Then use the **EXPERT_GUIDANCE_PROMPT.md** or **QUICK_EXPERT_PROMPT.md** to seek specific guidance on flagged items.

## Priority Actions

Based on checklist results:

1. **Critical Issues**: Address immediately before any analysis
2. **Important Concerns**: Address before finalizing analyses
3. **Minor Issues**: Note in limitations but proceed
4. **Satisfactory Items**: Document for Methods section

---

**Remember**: Perfect data is rare. The goal is to:
- Identify and address critical issues
- Acknowledge and justify limitations
- Ensure transparency in reporting
- Make informed decisions about publication readiness



