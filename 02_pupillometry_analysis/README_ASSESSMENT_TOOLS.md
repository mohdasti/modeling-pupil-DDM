# Pupil Data Assessment Tools - Quick Reference

## Overview

This directory contains a complete system for assessing publication-readiness of your pupil data. Use these tools to systematically evaluate data quality, identify issues, and get expert guidance.

## Files Created

### 📋 Assessment Tools

1. **`PUBLICATION_READINESS_CHECKLIST.md`**
   - Self-assessment checklist
   - Systematic evaluation of all aspects
   - Red flags and priority actions
   - **Use first** to identify issues

2. **`ASSESSMENT_GUIDE.md`**
   - Step-by-step process guide
   - How to use all tools together
   - Timeline estimates
   - **Read this** to understand the workflow

### 🤖 Expert Guidance Prompts

3. **`EXPERT_GUIDANCE_PROMPT.md`**
   - Comprehensive prompt for detailed expert review
   - Extensive questions covering all aspects
   - Best for thorough assessment before submission
   - **Use for** high-impact journals or comprehensive review

4. **`QUICK_EXPERT_PROMPT.md`**
   - Concise prompt for quick feedback
   - Copy-paste ready
   - Best for focused questions or iterative improvements
   - **Use for** quick checks or specific concerns

### 📊 Report Generation

5. **`generate_pupil_data_report.qmd`**
   - Quarto template for HTML report
   - Automated statistics and visualizations
   - Comprehensive data documentation
   - **Generate** after running pipeline

6. **`GENERATE_REPORT_README.md`**
   - Instructions for generating the report
   - Prerequisites and troubleshooting
   - **Read this** before generating report

### 📚 Documentation

7. **`PUPIL_DATA_REPORT_PROMPT.md`**
   - Complete methods documentation
   - Data flow and processing details
   - Reference for expert guidance
   - **Attach** when seeking expert help

## Quick Start Workflow

### 1. Self-Assessment (30-60 min)
```bash
# Open and complete:
PUBLICATION_READINESS_CHECKLIST.md
```

### 2. Generate Report (10 min)
```r
quarto::quarto_render("02_pupillometry_analysis/generate_pupil_data_report.qmd")
```

### 3. Review Report (30-60 min)
- Compare with checklist
- Identify specific issues
- Note concerns

### 4. Seek Expert Guidance (if needed)
- Use `QUICK_EXPERT_PROMPT.md` for quick feedback
- Use `EXPERT_GUIDANCE_PROMPT.md` for comprehensive review
- Attach relevant files

### 5. Implement Recommendations
- Address critical issues
- Improve data quality
- Update documentation

### 6. Final Assessment
- Re-run checklist
- Re-generate report
- Prepare for publication

## Which File Do I Need?

| I want to... | Use this file |
|--------------|---------------|
| Check my data systematically | `PUBLICATION_READINESS_CHECKLIST.md` |
| Understand the workflow | `ASSESSMENT_GUIDE.md` |
| Get quick expert feedback | `QUICK_EXPERT_PROMPT.md` |
| Get comprehensive expert review | `EXPERT_GUIDANCE_PROMPT.md` |
| Generate data report | `generate_pupil_data_report.qmd` |
| Learn how to generate report | `GENERATE_REPORT_README.md` |
| Reference methods details | `PUPIL_DATA_REPORT_PROMPT.md` |

## File Dependencies

```
ASSESSMENT_GUIDE.md (start here)
    ↓
PUBLICATION_READINESS_CHECKLIST.md (self-assessment)
    ↓
generate_pupil_data_report.qmd (generate report)
    ↓
[Review and identify issues]
    ↓
EXPERT_GUIDANCE_PROMPT.md or QUICK_EXPERT_PROMPT.md
    (attach PUPIL_DATA_REPORT_PROMPT.md + generated report)
```

## Key Questions These Tools Help Answer

✅ **Is my data quality sufficient?**
- Use: Checklist → Report → Expert Guidance

✅ **What issues need to be fixed?**
- Use: Checklist → Expert Guidance

✅ **Is my sample size adequate?**
- Use: Checklist → Expert Guidance (power analysis)

✅ **Are my methods appropriate?**
- Use: Checklist → Expert Guidance (methodological assessment)

✅ **What should I report?**
- Use: Checklist → Report → Expert Guidance (reporting requirements)

✅ **Is my data publication-ready?**
- Use: Complete workflow → Expert Guidance (final assessment)

## Tips

1. **Start with the checklist** - It's the foundation
2. **Generate the report** - Visualize your data
3. **Be honest** - Don't ignore issues
4. **Seek expert help** - When in doubt, ask
5. **Document everything** - For transparency

## Support

- **Methods questions**: See `PUPIL_DATA_REPORT_PROMPT.md`
- **Workflow questions**: See `ASSESSMENT_GUIDE.md`
- **Report generation**: See `GENERATE_REPORT_README.md`
- **Expert guidance**: Use the prompt files

---

**Remember**: These tools help you be thorough and transparent. The goal is not perfect data, but rigorous assessment and honest reporting.



