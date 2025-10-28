# Files to Attach to LLM for APA Manuscript Drafting

## Primary Document (Required)

### 1. FINAL_SCIENTIFIC_REPORT.md
**Location:** This file in the same directory
**Purpose:** Contains all statistical results, methods, and findings
**Why essential:** This is the complete analysis report with all numbers

## Additional Supporting Files (Optional but Helpful)

### 2. PROMPT_FOR_APA_MANUSCRIPT.md
**Location:** This file in the same directory  
**Purpose:** Detailed prompt with instructions for the LLM
**Why helpful:** Provides context and specific guidelines

### 3. Repository Information
**Link:** https://github.com/mohdasti/modeling-pupil-DDM  
**Branch:** working-pipeline-oct2024
**Purpose:** Shows analysis scripts and methods
**Note:** Mention this link in your LLM prompt for reference

## Figures (If Available)

The LLM can describe figures based on these files if you want to include figure descriptions:

### Key Figures from output/figures/:
- `rt_sanity_check_difficulty.png` - Shows RT distributions by difficulty
- `ppc/Model6_Pupillometry_density.png` - Model validation plot
- `condition_effects_forest_plot.png` - Effect sizes (if exists)

### Tables from output/tables/:
- `attrition_table.csv` - Data retention metrics
- From `output/results/pupil_features_summary.csv` - Summary statistics

## What to Include with the Prompt

When you send this to the LLM, provide:

1. **Copy of PROMPT_FOR_APA_MANUSCRIPT.md** (the detailed prompt)
2. **Copy of FINAL_SCIENTIFIC_REPORT.md** (all the results)
3. **Mention the GitHub repo link** in your message to the LLM
4. **Any additional context** about the study's theoretical background

## Suggested LLM Prompt Opening

Start your message to the LLM with something like:

```
I need you to draft a complete APA-formatted research manuscript for a study I've conducted. 
Below I'm providing:

1. A detailed prompt with all instructions and guidelines (PROMPT_FOR_APA_MANUSCRIPT.md)
2. The complete analysis report with all statistical results (FINAL_SCIENTIFIC_REPORT.md)
3. Repository link: https://github.com/mohdasti/modeling-pupil-DDM (branch: working-pipeline-oct2024)

The study examines how pupillometry-measured arousal relates to decision-making using drift 
diffusion models. All analyses are complete - I just need a publication-ready manuscript 
written.

Please follow the detailed prompt I'm providing carefully. All statistics and results 
should be accurate based on what's in the report.
```

Then attach/upload:
- PROMPT_FOR_APA_MANUSCRIPT.md
- FINAL_SCIENTIFIC_REPORT.md

## Order of Information Flow

1. **Read the prompt first** (PROMPT_FOR_APA_MANUSCRIPT.md)
2. **Read the results report** (FINAL_SCIENTIFIC_REPORT.md)  
3. **Create manuscript outline**
4. **Draft each section** following APA guidelines
5. **Include all provided statistics accurately**
6. **Format tables and figure descriptions**

## Key Points for the LLM

- Use EXACT statistics from FINAL_SCIENTIFIC_REPORT.md
- Follow APA 7th edition formatting
- Report Bayesian results properly (posterior means, 95% CI, Rhat, ESS)
- Be conservative about trend-level effects
- Include sufficient methodological detail for replication

---

**Summary:** Attach PROMPT_FOR_APA_MANUSCRIPT.md + FINAL_SCIENTIFIC_REPORT.md + mention GitHub repo link. That should be sufficient for the LLM to draft a complete APA manuscript.

