# Expert Guidance Prompt: Publication-Readiness Assessment for Pupil Data

## Context and Goal

I am conducting a pupillometry study as part of a larger BAP (Brain and Pupil) project investigating the relationship between pupil-linked arousal, cognitive effort, and decision-making. I need expert guidance to create a comprehensive data quality and publication-readiness assessment report.

**Primary Goal**: Determine whether my pupil data is publication-worthy and identify any issues, limitations, or concerns that need to be addressed before publication.

**Secondary Goals**:
- Identify data quality issues and anomalies
- Assess statistical power and sample size adequacy
- Evaluate methodological rigor and consistency
- Provide recommendations for improvement
- Suggest appropriate analyses given data quality

## Research Context

**Study Design**:
- **Tasks**: ADT (Auditory Detection Task) and VDT (Visual Detection Task)
- **Conditions**: 
  - Effort: Low (5% MVC) vs High (40% MVC) handgrip force
  - Difficulty: Standard, Easy, Hard (based on stimulus level)
- **Primary Metrics**: 
  - Total AUC: Raw pupil from squeeze onset to response (captures full TEPR)
  - Cognitive AUC: Baseline-corrected pupil from 300ms post-target to response (isolates cognitive TEPR)
- **Method**: Zenon et al. (2014) AUC calculation using trapezoidal integration

**Data Pipeline**:
1. MATLAB preprocessing pipeline (baseline correction, quality metrics)
2. R feature extraction (AUC calculations, trial-level summaries)
3. Quality filtering: ≥80% valid data threshold
4. Analysis-ready files: Trial-level data with behavioral integration

## Files I Will Provide

When you respond, I will attach the following files for your review:

1. **`PUPIL_DATA_REPORT_PROMPT.md`**: Complete documentation of:
   - Directory structure and file organization
   - Data flow through pipeline stages
   - Processing methods (baseline correction, AUC calculation)
   - Quality thresholds and filtering criteria
   - Trial structure and timing
   - Difficulty/effort condition mapping

2. **`generate_pupil_data_report.qmd`**: Quarto report template that generates:
   - Data inventory (files per subject)
   - Subject-level statistics
   - Trial-level statistics
   - Quality control summaries
   - Feature extraction summaries
   - Basic visualizations

3. **`plot_pupil_waveforms.R`**: Script that generates publication-quality waveform plots showing:
   - Baseline-corrected pupil traces by condition
   - Event markers (trial onset, target onset, response)
   - Timeline bars (baseline, Total AUC, Cognitive AUC windows)
   - Condition-specific averages with confidence intervals

4. **Analysis-ready data files** (if available):
   - `data/analysis_ready/BAP_analysis_ready_PUPIL.csv`
   - `data/analysis_ready/BAP_analysis_ready_BEHAVIORAL.csv`

5. **Pipeline scripts** (if needed):
   - `02_pupillometry_analysis/feature_extraction/prepare_analysis_ready_data.R`
   - `02_pupillometry_analysis/quality_control/run_pupil_qc.R`

## What I Need From You

Please provide comprehensive guidance on the following aspects:

### 1. Data Quality Assessment

**A. Quality Metrics Evaluation**:
- Are the quality thresholds (80% valid data) appropriate for publication?
- What are acceptable ranges for quality metrics (baseline_quality, overall_quality)?
- Should quality metrics vary by condition or task? If so, how should this be handled?
- Are there any red flags in quality distributions that suggest systematic issues?

**B. Missing Data Patterns**:
- What patterns of missing data are concerning vs. acceptable?
- How should missing AUC values be handled (exclusion criteria, imputation considerations)?
- Are there systematic missing data patterns by subject, task, or condition that need investigation?

**C. Data Completeness**:
- What is the minimum acceptable number of trials per condition for publication?
- What is the minimum acceptable number of subjects for publication?
- How should I handle subjects with incomplete data (e.g., missing one task or condition)?

### 2. Statistical Power and Sample Size

**A. Power Analysis**:
- Given my sample size (N subjects, M trials per condition), what effect sizes can I reliably detect?
- Are there any conditions with insufficient power that should be excluded or noted as exploratory?
- What are appropriate effect size benchmarks for pupil AUC metrics in this type of study?

**B. Sample Size Adequacy**:
- Is my sample size adequate for the planned analyses (e.g., mixed-effects models, condition comparisons)?
- Should I report power analyses or sample size justifications?
- Are there any concerns about unequal sample sizes across conditions?

### 3. Methodological Rigor Assessment

**A. Baseline Correction**:
- Is the baseline correction method (500ms window, -0.5s to 0s) appropriate?
- Are there concerns about baseline stability or contamination?
- Should baseline quality be reported or used as a covariate?

**B. AUC Calculation**:
- Is the Zenon et al. (2014) method appropriate for this design?
- Are the time windows (Total AUC: 0s to response; Cognitive AUC: 4.65s to response) appropriate?
- Should the 300ms latency offset for Cognitive AUC be justified or varied?
- Are there concerns about trial-specific vs. fixed response windows?

**C. Quality Filtering**:
- Is the 80% valid data threshold too lenient or too strict?
- Should quality filtering be more stringent for certain analyses?
- Are there alternative quality metrics I should consider?

### 4. Sanity Checks and Issue Detection

**A. Data Distribution Checks**:
- What distributions should I check for AUC metrics (normality, outliers, skewness)?
- Are there expected ranges for pupil AUC values that I should verify?
- What outlier detection methods are appropriate for pupil data?

**B. Condition Effects**:
- Are the expected direction and magnitude of condition effects reasonable?
- Should I check for order effects, practice effects, or fatigue effects?
- Are there any unexpected patterns that suggest data quality issues?

**C. Cross-Validation Checks**:
- Should pupil metrics correlate with behavioral measures (RT, accuracy)? If so, what are expected correlations?
- Are there internal consistency checks I should perform?
- Should I verify that difficulty and effort manipulations are working as expected?

### 5. Publication Standards and Reporting

**A. Required Information**:
- What information must be included in a Methods section for pupillometry?
- What quality control information should be reported?
- What descriptive statistics are essential?
- Should I report quality metrics by condition/subject?

**B. Figure and Table Requirements**:
- What figures are essential for publication (waveforms, quality distributions, etc.)?
- What tables are required (subject characteristics, trial counts, quality metrics)?
- Are there standard formats or conventions for pupillometry figures?

**C. Limitations and Caveats**:
- What limitations should I acknowledge (sample size, missing data, quality thresholds)?
- Are there methodological limitations that need to be discussed?
- What would strengthen the manuscript?

### 6. Specific Research Questions

Please provide guidance tailored to these potential research questions:

**Question 1**: Does cognitive effort (High vs. Low grip force) modulate pupil-linked arousal during difficult vs. easy detection tasks?

**Question 2**: Does the relationship between effort and pupil response differ between auditory and visual modalities?

**Question 3**: Is Cognitive AUC (isolated cognitive TEPR) more sensitive to difficulty manipulations than Total AUC (full TEPR)?

For each question:
- Is the data quality sufficient to address this question?
- What analyses would be most appropriate?
- What are potential confounds or alternative explanations?
- What additional checks or controls are needed?

### 7. Report Enhancement Recommendations

**A. Additional Analyses to Include**:
- What additional quality checks should be added to the report?
- What exploratory analyses would help assess data quality?
- Are there diagnostic plots or statistics that would be valuable?

**B. Visualization Improvements**:
- What additional visualizations would strengthen the report?
- Are there specific plots that help detect issues (e.g., subject-level plots, trial-level diagnostics)?
- Should I create condition-specific quality plots?

**C. Automated Issue Detection**:
- What automated checks can I implement to flag potential issues?
- Are there statistical tests I should run to detect anomalies?
- What thresholds or criteria should trigger warnings?

### 8. Actionable Recommendations

Please provide:
- **Critical issues** that must be addressed before publication
- **Important concerns** that should be addressed if possible
- **Minor issues** that are acceptable but should be noted
- **Strengths** of the current data and methods
- **Priority order** for addressing any issues

## Output Format

Please structure your response as:

1. **Executive Summary**: Overall assessment (publication-ready, needs work, or not suitable)
2. **Critical Issues**: Must-fix items with specific recommendations
3. **Important Concerns**: Should-fix items with guidance
4. **Minor Issues**: Nice-to-fix items or notes
5. **Data Quality Assessment**: Detailed evaluation of quality metrics, missing data, completeness
6. **Statistical Power Assessment**: Power analysis and sample size adequacy
7. **Methodological Assessment**: Evaluation of methods with recommendations
8. **Sanity Checks**: Specific checks to perform with expected outcomes
9. **Publication Readiness**: What's needed for publication with specific research questions
10. **Report Enhancements**: Specific additions to improve the report
11. **Prioritized Action Plan**: Step-by-step recommendations in priority order

## Additional Context

- **Field**: Cognitive neuroscience / psychophysiology
- **Publication Target**: High-impact journals (e.g., Journal of Neuroscience, eLife, Nature Human Behaviour)
- **Standards**: APA 7th edition, open science practices preferred
- **Timeline**: Preparing for manuscript submission
- **Expertise Level**: I have experience with pupillometry but seek expert validation and guidance

## Questions for You

1. Based on typical pupillometry standards, what would make you confident that this data is publication-worthy?
2. What are the most common mistakes or oversights in pupillometry data quality assessment?
3. Are there specific red flags in pupil data that I should be especially vigilant about?
4. What would you want to see in a data quality report to feel confident about the data?
5. Are there any methodological concerns specific to effort manipulation + pupillometry that I should consider?

## Thank You

I appreciate your expert guidance. Please be thorough and specific in your recommendations. I'm particularly interested in:
- **Actionable steps** I can take immediately
- **Specific thresholds or criteria** I should use
- **Red flags** I should watch for
- **Best practices** from the pupillometry literature
- **Common pitfalls** to avoid

Thank you for helping me ensure my data meets publication standards!

---

**Note**: When I provide the files, please review them in detail and provide specific, actionable feedback. I'm looking for expert-level guidance that will help me produce publication-quality work.



