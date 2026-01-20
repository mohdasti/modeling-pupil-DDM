# PDF Inspection Prompt for ChatGPT

Copy and paste this prompt into ChatGPT along with the PDF file to get a systematic inspection report.

---

## Prompt: Systematic PDF Inspection for Dissertation Chapter 3

You are inspecting a PDF document (a dissertation chapter on drift-diffusion modeling) for quality control. Please perform a **systematic, comprehensive inspection** following the structure below. For each item, report: (1) Status (✓ Present / ✗ Missing / ⚠ Issue), (2) Location (page number), and (3) Specific details or recommendations.

### SECTION 1: TABLE INVENTORY AND VERIFICATION

**Task**: Verify that all referenced tables appear in the document and are properly formatted.

**Instructions**:
1. Extract all table references from the text (e.g., "Table 1", "@tbl-...", "see Table X").
2. For each table reference, check:
   - Does the actual table appear in the PDF?
   - Is it on the same page or within 1-2 pages of its first reference?
   - Is the table number correct and sequential?
   - Is the table caption complete and readable?
   - Does the table fit within page margins (not cut off or overflowing)?
   - For landscape tables: Is the orientation correct and readable?

**Report Format**:
```
Table X: [Table Name]
  Status: [✓/✗/⚠]
  Page: [page number]
  First Reference: [page number where first mentioned]
  Issues: [list any problems: missing, wrong page, overflow, formatting issues]
```

**Special Attention**:
- Table 5: Convergence & PPC Gate (Primary Model)
- Table 6: Sample Demographics
- Table 7: Trial Counts by Condition
- Table 19: Posterior Contrasts (Directional Probabilities) - should be in landscape
- Table 25: Subject-Wise Mid-Body PPC (30/50/70% quantiles; censored 2%) - should be in landscape

---

### SECTION 2: FIGURE INVENTORY AND VERIFICATION

**Task**: Verify that all referenced figures appear in the document and are properly formatted.

**Instructions**:
1. Extract all figure references from the text (e.g., "Figure 1", "@fig-...", "see Figure X", "Supplementary Figure X").
2. For each figure reference, check:
   - Does the actual figure appear in the PDF?
   - Is it on the same page or within 1-2 pages of its first reference?
   - Is the figure number correct and sequential?
   - Is the figure caption complete and readable?
   - Does the figure fit within page margins (not cut off)?
   - Is the figure resolution adequate (not pixelated or blurry)?
   - For landscape figures: Is the orientation correct?

**Report Format**:
```
Figure X: [Figure Name/Description]
  Status: [✓/✗/⚠]
  Page: [page number]
  First Reference: [page number where first mentioned]
  Issues: [list any problems: missing, wrong page, low resolution, formatting issues]
```

**Special Attention**:
- All DDM process/pipeline figures (fig-ddm-process, fig-ddm-pipeline)
- All pupil-DDM integration figures (fig-pupil-ddm-scatter-*)
- All LC integrity figures (fig-lc-integrity-*)
- All PPC/diagnostic figures (fig-ppc-*, fig-ch3app-*)
- All supplementary figures (S1-S6)

---

### SECTION 3: BLANK SPACE ANALYSIS

**Task**: Identify wasted blank space that could be optimized.

**Instructions**:
1. Scan each page for excessive blank space:
   - Large gaps between sections (>1 inch)
   - Tables/figures that could be moved up to fill space
   - Orphaned headings (heading at bottom of page with content on next page)
   - Widows/orphans (single lines isolated at top/bottom of pages)
   - Half-empty pages at end of sections
   - Large margins around tables/figures that could be reduced

2. For each instance, note:
   - Page number
   - Type of blank space (gap, orphan, half-page, etc.)
   - Estimated space wasted (e.g., "~2 inches", "half page")
   - Recommendation for correction

**Report Format**:
```
Page X:
  Issue Type: [Gap/Orphan/Widow/Half-page/Large margin]
  Location: [description, e.g., "Between Section 3.1 and 3.2"]
  Space Wasted: [estimate]
  Recommendation: [specific fix, e.g., "Move Table Y up to fill gap", "Reduce spacing before heading"]
```

---

### SECTION 4: CROSS-REFERENCE VERIFICATION

**Task**: Verify that all cross-references resolve correctly.

**Instructions**:
1. Find all cross-reference patterns:
   - "@tbl-..." references
   - "@fig-..." references
   - "@sec-..." references
   - "Table X" / "Figure X" text references
   - "see Table X" / "see Figure X" references

2. For each cross-reference:
   - Verify the target exists
   - Verify the number matches (e.g., if text says "Table 5", is it actually Table 5?)
   - Check for broken references (e.g., "Table 99" that doesn't exist)

**Report Format**:
```
Cross-Reference: [exact text, e.g., "@tbl-contrasts" or "see Table 19"]
  Page: [page number where reference appears]
  Target Status: [✓ Found / ✗ Missing / ⚠ Wrong Number]
  Target Location: [page number of target]
  Issues: [any problems]
```

---

### SECTION 5: LANDSCAPE ORIENTATION VERIFICATION

**Task**: Verify that wide tables are properly displayed in landscape orientation.

**Instructions**:
1. Identify all tables that should be in landscape (based on width or explicit mentions):
   - Table 19: Posterior Contrasts
   - Table 25: Subject-Wise Mid-Body PPC
   - Any other wide tables

2. For each landscape table:
   - Is it actually rotated to landscape?
   - Is the text readable (not sideways or upside down)?
   - Does it fit properly on the landscape page?
   - Is there a blank portrait page before/after it?

**Report Format**:
```
Table X: [Table Name]
  Expected Orientation: Landscape
  Actual Orientation: [Landscape/Portrait]
  Page: [page number]
  Issues: [rotation problems, readability, blank pages]
```

---

### SECTION 6: FORMATTING CONSISTENCY CHECK

**Task**: Check for formatting inconsistencies that affect readability.

**Instructions**:
1. Check consistency of:
   - Table formatting (font sizes, column widths, borders)
   - Figure sizing (are similar figures similar sizes?)
   - Caption formatting (consistent style, length, placement)
   - Section heading styles
   - Spacing between elements

2. Identify any formatting that looks unprofessional or inconsistent.

**Report Format**:
```
Issue: [description, e.g., "Inconsistent table font sizes"]
  Location: [pages/sections affected]
  Details: [specific examples]
  Recommendation: [how to fix]
```

---

### SECTION 7: MISSING CONTENT SUMMARY

**Task**: Create a prioritized list of all missing content.

**Instructions**:
1. Compile all missing items from Sections 1-2 into a single prioritized list.
2. Prioritize by:
   - Critical (referenced in main text but missing)
   - Important (referenced in supplementary sections)
   - Optional (mentioned but not critical)

**Report Format**:
```
CRITICAL MISSING ITEMS:
1. [Item name] - [Location where referenced] - [Impact]

IMPORTANT MISSING ITEMS:
1. [Item name] - [Location where referenced] - [Impact]

OPTIONAL MISSING ITEMS:
1. [Item name] - [Location where referenced] - [Impact]
```

---

### SECTION 8: OVERALL ASSESSMENT

**Task**: Provide an overall quality assessment.

**Instructions**:
1. Summarize:
   - Total tables expected vs. found
   - Total figures expected vs. found
   - Total pages with significant blank space issues
   - Total broken cross-references
   - Overall document quality score (1-10)

2. Provide top 5 priority fixes.

**Report Format**:
```
OVERALL STATISTICS:
- Tables: [X found] / [Y expected] ([Z%] complete)
- Figures: [X found] / [Y expected] ([Z%] complete)
- Blank Space Issues: [X] pages
- Broken References: [X]
- Quality Score: [X]/10

TOP 5 PRIORITY FIXES:
1. [Fix description] - [Why it's important]
2. [Fix description] - [Why it's important]
3. [Fix description] - [Why it's important]
4. [Fix description] - [Why it's important]
5. [Fix description] - [Why it's important]
```

---

## INSTRUCTIONS FOR USE

1. **Upload the PDF**: Attach `chap3_ddm_results.pdf` to ChatGPT.

2. **Copy the prompt**: Copy the entire prompt above (from "## Prompt: Systematic PDF Inspection..." to the end).

3. **Request analysis**: Paste the prompt and ask ChatGPT to perform the inspection.

4. **Review output**: ChatGPT should provide a structured report following the format above.

5. **Iterate**: If ChatGPT misses items, ask follow-up questions like:
   - "Can you check specifically for Table X on page Y?"
   - "Are there any figures referenced but not shown?"
   - "What pages have the most wasted blank space?"

---

## EXPECTED OUTPUT

ChatGPT should provide a comprehensive report with:
- ✓ Complete inventory of all tables and figures
- ✓ Identification of missing items
- ✓ Blank space analysis with specific recommendations
- ✓ Cross-reference verification
- ✓ Landscape orientation checks
- ✓ Prioritized action items

This report can then be used to systematically fix all issues in the Quarto document.
