# Prompt for Drafting APA-Formatted Research Manuscript

## Context and Task

I need you to draft a complete APA-style research manuscript based on a comprehensive analysis of pupillometry and decision-making data using drift diffusion modeling (DDM). The analysis has been completed, and I will provide you with the detailed results report and supporting materials.

## Your Task

Create a complete, publication-ready APA manuscript (7th edition) with the following sections:

1. **Title Page** with running head
2. **Abstract** (250 words max)
3. **Introduction** - Literature review and research questions
4. **Method** - Participants, materials, procedure, analysis
5. **Results** - All statistical findings with proper APA formatting
6. **Discussion** - Interpretation, limitations, future directions
7. **References** in APA format
8. **Figures and Tables** with captions

## Key Information About the Study

**Research Question:** How do pupillometric measures of arousal (tonic and phasic) relate to decision-making parameters in a drift diffusion model framework?

**Sample:**
- 34 participants with pupillometry data
- 20,024 behavioral trials (total)
- 719 high-quality pupil trials (after quality control)
- 81.2% trial retention rate

**Design:**
- Within-subjects 2×2 factorial design
- Difficulty manipulation: Easy vs. Hard stimulus discrimination
- Effort manipulation: Low force (5% MVC) vs. High force (40% MVC)
- Concurrent pupillometry measurements

**Analysis:** Hierarchical Bayesian drift diffusion modeling using `brms` in R

## Materials I Will Provide

I will attach the following files:

1. **FINAL_SCIENTIFIC_REPORT.md** - Complete analysis report with all results
2. **Additional supporting files** (if needed for technical details)

## Guidelines for the Manuscript

### Statistical Reporting (APA 7th Edition)

When reporting results, use APA 7th edition format:
- Bayesian models: Report posterior means, 95% credible intervals (CI), Rhat, ESS
- Effect sizes: Report unstandardized β coefficients with confidence/credible intervals
- Example: "The difficulty manipulation showed a strong negative effect on drift rate (β = -1.426, 95% CI [-1.462, -1.390])."

### Key Results to Include

**Main Effects:**
1. **Difficulty Effect:** β = -1.426, 95% CI [-1.462, -1.390], Rhat = 1.000, ESS = 3281
   - Very large negative effect on drift rate
   - Highly reliable effect

2. **Effort Effect:** β = 0.051, 95% CI [0.019, 0.082], Rhat = 1.003, ESS = 4288
   - Small positive effect on drift rate

3. **Tonic Arousal:** β = 0.090, 95% CI [-0.023, 0.200], Rhat = 1.000, ESS = 4432
   - Positive trend (trend-level effect)

4. **Effort Arousal:** β = -0.009, 95% CI [-0.093, 0.073], Rhat = 1.000, ESS = 7225
   - No significant effect

**Model Diagnostics:**
- All models converged successfully (Rhat < 1.01)
- Effective sample sizes > 150 for all parameters
- Posterior predictive checks confirm good model fit

**DDM Parameters:**
- Boundary separation (bs): 2.17, 95% CI [2.09, 2.24]
- Non-decision time (ndt): 0.12s, 95% CI [0.10, 0.13]
- Starting bias: 0.56, 95% CI [0.53, 0.58]

### Writing Style

1. **Be scientifically precise:** Use exact statistics from the report
2. **Be conservative:** Don't overstate conclusions, especially for trend-level effects
3. **APA formatting:** Follow APA 7th edition throughout
4. **Clarity:** Write for a scientific audience but ensure accessibility
5. **Completeness:** Include all necessary methodological detail
6. **Citation style:** When I mention specific citations, use proper APA format

### Specific Instructions for Each Section

**Introduction:**
- Start with broad context on decision-making
- Review relevant DDM literature
- Review pupillometry and arousal literature
- Clearly state research questions/hypotheses
- Cite relevant theoretical frameworks (about 30-40 citations expected)

**Method:**
- **Participants:** Note 34 with pupillometry, 69 total behavioral
- **Materials/Tasks:** Describe ADT and VDT tasks
- **Procedure:** Describe difficulty and effort manipulations
- **Pupillometry:** Describe measurement windows and preprocessing
- **Analysis:** Describe DDM framework, model specifications, convergence criteria
- Be detailed enough for replication

**Results:**
- Start with descriptive statistics
- Report model diagnostics (convergence)
- Report main effects (difficulty, effort)
- Report interaction effects
- Report pupillometry results
- Use clear subheadings
- Include tables for complex data
- Note when effects are "trend-level" or "approaching significance"

**Discussion:**
- Summarize key findings
- Relate to prior literature
- Discuss theoretical implications
- Address limitations (sample size, single paradigm)
- Suggest future directions
- Provide practical implications

### Technical Details to Include

**Statistical Software:**
- R version 4.x
- Key packages: `brms` (2.22.0), `cmdstanr`, `lme4`, `dplyr`, `ggplot2`, `bayesplot`
- Stan backend with cmdstanr

**Model Specifications:**
- Family: Wiener (drift diffusion likelihood)
- MCMC: 4 chains, 2000 iterations (1000 warmup)
- Convergence: Rhat < 1.01, ESS > 400
- Random effects: `(1 | subject_id)` for all parameters

**Quality Control:**
- RT filtering: 0.15-3.0 seconds
- Pupil QC: <40% blinks, >60% valid samples
- 81.2% final trial retention after QC

### Tone and Perspective

- **Author perspective:** "we conducted," "we found"
- **Confidence level:** Appropriate caution for trend-level effects
- **Scientific rigor:** Emphasize methodological strengths (convergence, PPC)
- **Transparency:** Discuss limitations openly

### Figures and Tables

Create descriptions for:
1. **Table 1:** Descriptive statistics (sample characteristics)
2. **Table 2:** DDM parameter estimates (boundary separation, non-decision time, etc.)
3. **Table 3:** Model results for difficulty and effort effects
4. **Table 4:** Pupillometry results (tonic and phasic arousal)
5. **Figure 1:** Conceptual model/framework
6. **Figure 2:** RT distributions by condition
7. **Figure 3:** DDM parameter estimates with credible intervals
8. **Figure 4:** Model validation plots (posterior predictive checks)

### Additional Context

**Repository:** https://github.com/mohdasti/modeling-pupil-DDM
- Branch: `working-pipeline-oct2024`
- Contains all analysis scripts and detailed results

**Key Theoretical Frameworks:**
- Drift diffusion models (Ratcliff, 1978; Wagenmakers et al., 2007)
- Arousal-performance relationships (Yerkes-Dodson law)
- Pupillometry in cognitive neuroscience (Laeng et al., 2012)

## Output Format

Please provide:

1. **Complete manuscript** in APA format (all sections)
2. **Separate list of figures** with detailed captions
3. **Separate list of tables** with detailed titles and notes
4. **Supplementary notes** for any methodological details that might need clarification

## Important Notes

- **Be scientifically accurate:** Only report what is in the provided materials
- **Don't invent results:** If something isn't in the report, don't include it
- **Be conservative:** For trend-level effects, use appropriate language ("trend," "approaching significance")
- **Cite appropriately:** When I provide citation information, use proper APA format
- **Length:** Target 4000-5000 words for the main text (excluding abstract, refs, tables)

## Final Instructions

After you draft the manuscript:
1. Let me review it for accuracy
2. I may ask for revisions
3. I will provide additional citations or context as needed
4. Once satisfied, I will use it for submission

Please start by creating an outline of the manuscript structure, then proceed to draft each section. Be thorough, accurate, and follow APA guidelines strictly.

---

**When ready, proceed with drafting the manuscript. I will provide additional materials or clarifications as needed.**

