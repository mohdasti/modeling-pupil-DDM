# Literature Review Prompt: Pupillometry Quality Thresholds and Sensitivity Analysis

## Research Context

I am conducting a dual-task pupillometry study examining how physical effort (handgrip force manipulation) and cognitive demands (perceptual discrimination) interact in older adults. The study uses a paradigm where participants:
1. Maintain handgrip force (Low: 5% MVC or High: 40% MVC) for 3 seconds
2. Perform an auditory or visual discrimination task (detecting intensity differences)
3. Provide behavioral responses (Same/Different choice + confidence rating)

Pupil diameter is recorded at 250 Hz throughout each trial, which includes:
- Baseline period (ITI, -3.0s to 0s relative to squeeze onset)
- Squeeze period (0s to 3.0s)
- Stimulus presentation (target onset at 4.35s)
- Response period (4.7s to 7.7s)

## Research Questions

I need to justify quality thresholds for two dissertation chapters:

1. **Chapter 2: Psychometric-Pupil Coupling**
   - Tests how trial-wise pupil-indexed arousal (Cognitive AUC) modulates psychometric sensitivity
   - Currently using: 60% validity threshold (baseline_quality ≥ 0.60 AND cog_quality ≥ 0.60)
   - Rationale: Requires high-quality data for reliable trial-wise relationships

2. **Chapter 3: Drift Diffusion Model (DDM) with Pupil Predictors**
   - Tests how pupil-indexed arousal influences decision-making processes
   - Currently using: 50% validity threshold (baseline_quality ≥ 0.50 AND cog_quality ≥ 0.50) + RT filter
   - Rationale: Prioritizes sample size for DDM while maintaining minimum quality standards

## Information Needed

Please provide a comprehensive literature review addressing the following:

### 1. Standard Quality Thresholds in Pupillometry

- What validity thresholds (percentage of valid samples) are commonly used in pupillometry research?
- Is there a "standard" or widely accepted threshold (e.g., 80%, 70%, 60%, 50%)?
- How do thresholds vary by:
  - Analysis type (trial-wise vs. subject-level, continuous vs. discrete windows)
  - Research domain (cognitive load, effort, emotion, decision-making)
  - Population (young adults, older adults, clinical populations)
  - Task type (passive viewing, active tasks, dual-task paradigms)

### 2. Prior Work on Similar Paradigms

Please identify and summarize studies that:
- Used pupillometry in dual-task or effort manipulation paradigms
- Examined pupil responses during physical effort or motor tasks
- Studied cognitive load or decision-making with pupillometry
- Combined pupillometry with psychometric function analyses
- Used pupillometry as a predictor in computational models (e.g., DDM, drift-diffusion models)

For each relevant study, please provide:
- Citation (author, year, journal)
- Quality thresholds used (if reported)
- Justification for threshold selection (if provided)
- Sample size and retention rates
- Whether sensitivity analyses were conducted

### 3. Sensitivity Analysis Practices

- How do pupillometry researchers typically conduct sensitivity analyses for quality thresholds?
- What criteria are used to select thresholds (retention rates, subject dropout, metric stability)?
- Are there published guidelines or recommendations for threshold selection?
- Examples of studies that explicitly justified their threshold choices through sensitivity analyses

### 4. Threshold Selection Justifications

- What methodological considerations justify stricter thresholds (e.g., 60-80%)?
- What considerations justify more lenient thresholds (e.g., 40-50%)?
- How do researchers balance data quality vs. sample size?
- Are there established criteria for minimum acceptable validity (e.g., minimum number of valid samples per window)?

### 5. Specific Examples

Please provide specific examples of:
- Studies using thresholds around 50-60% and their justifications
- Studies using thresholds around 70-80% and their justifications
- Studies that conducted threshold sensitivity analyses
- Studies in older adult populations (if available)
- Studies using AUC (area under the curve) metrics similar to our approach

### 6. Methodological Considerations

- How do window definitions (baseline, cognitive, overall) affect threshold selection?
- Are there differences in threshold requirements for:
  - Baseline correction windows
  - Task-evoked response windows
  - Full-trial analyses vs. event-locked analyses
- How do sampling rates (e.g., 250 Hz vs. lower rates) affect threshold considerations?

## Expected Output Format

Please organize your response as:

1. **Executive Summary**: Brief overview of common practices and key findings
2. **Standard Thresholds**: Summary of typical thresholds used across pupillometry literature
3. **Relevant Studies**: Detailed summaries of studies most similar to our paradigm
4. **Sensitivity Analysis Practices**: How researchers justify threshold selections
5. **Recommendations**: Based on the literature, what thresholds would be appropriate for our analyses
6. **Citations**: Complete reference list of all cited studies

## Additional Context

Our current data shows:
- At 50% threshold: ~51% retention (ADT) and ~59% retention (VDT)
- At 60% threshold: ~45% retention (ADT) and ~54% retention (VDT)
- At 70% threshold: ~37% retention (ADT) and ~47% retention (VDT)

We need to justify:
- Why 60% is appropriate for Chapter 2 (psychometric coupling)
- Why 50% is appropriate for Chapter 3 (DDM with pupil predictors)
- Whether sensitivity analyses at other thresholds are necessary/standard practice

## Search Strategy Suggestions

Please search for:
- Keywords: "pupillometry quality threshold", "pupil data validity", "pupil quality control", "pupil data exclusion criteria"
- Keywords: "pupillometry sensitivity analysis", "pupil threshold selection", "pupil data quality criteria"
- Keywords: "pupillometry dual-task", "pupil effort", "pupil cognitive load", "pupil decision-making"
- Keywords: "pupil AUC", "pupil area under curve", "pupil psychometric", "pupil drift diffusion"
- Methodological papers: "pupillometry preprocessing", "pupil data quality", "pupil artifact correction"

Please prioritize:
1. Recent publications (last 10 years)
2. High-impact journals (Nature, Science, PNAS, Journal of Neuroscience, Psychophysiology, etc.)
3. Methodological papers or reviews
4. Studies with similar paradigms or populations

Thank you for your comprehensive review!

