# Quick Expert Guidance Prompt (Copy-Paste Version)

## Instructions for Use

Copy this prompt and attach the files listed below when seeking expert guidance on your pupil data publication-readiness.

---

**I am preparing a pupillometry manuscript and need expert guidance to assess whether my data is publication-worthy. I'm particularly concerned about data quality, statistical power, methodological rigor, and identifying any issues that need to be addressed.**

**My Study:**
- ADT and VDT tasks with Low/High effort (5% vs 40% MVC grip force) and Standard/Easy/Hard difficulty
- Primary metrics: Total AUC and Cognitive AUC (Zenon et al. 2014 method)
- Quality threshold: ≥80% valid data
- Baseline correction: 500ms window (-0.5s to 0s)

**I need your expert assessment on:**

1. **Data Quality**: Are my quality thresholds appropriate? What patterns of missing data are concerning? What's the minimum acceptable data completeness?

2. **Statistical Power**: Is my sample size adequate? What effect sizes can I detect? Are there power concerns?

3. **Methodological Rigor**: Is my baseline correction and AUC calculation appropriate? Are there methodological concerns?

4. **Sanity Checks**: What specific checks should I perform? What are red flags to watch for? What distributions and patterns should I verify?

5. **Publication Readiness**: What's needed for publication? What limitations should I acknowledge? What additional information is required?

6. **Issue Detection**: What automated checks can detect problems? What would make you confident this data is publication-worthy?

**Please provide:**
- Overall assessment (publication-ready / needs work / not suitable)
- Critical issues that must be fixed
- Specific actionable recommendations
- Sanity checks to perform with expected outcomes
- Prioritized action plan

**Files Attached:**
- [List files you're attaching]

**Thank you for your expert guidance!**

---

## Files to Attach

When using this prompt, attach these files:

1. **`PUPIL_DATA_REPORT_PROMPT.md`** - Complete documentation of methods and pipeline
2. **`generate_pupil_data_report.qmd`** - Current report template
3. **`plot_pupil_waveforms.R`** - Waveform plotting script
4. **Analysis-ready data** (if available):
   - `data/analysis_ready/BAP_analysis_ready_PUPIL.csv`
   - `data/analysis_ready/BAP_analysis_ready_BEHAVIORAL.csv`
5. **Any QC reports or outputs** you've already generated

## Research Questions to Include

If you have specific research questions, add them:

**My research questions:**
1. [Your question 1]
2. [Your question 2]
3. [Your question 3]

**For each question, please assess:**
- Is data quality sufficient?
- What analyses are most appropriate?
- What are potential confounds?
- What additional checks are needed?



