# RT Filtering Citations Summary

## Files Created/Updated

1. **`reports/references.bib`** - BibTeX file with 4 key references
2. **`reports/chap3_ddm_results.qmd`** - Updated to:
   - Link to bibliography file (`bibliography: references.bib`)
   - Include citations in the filtering statement
   - Auto-generate references section

## Citations Added

### Primary Empirical Papers

1. **Ratcliff, Thapar, & McKoon (2004)** - `ratcliff2004aging`
   - Key finding: Non-decision time is 80-100ms longer in older adults
   - Direct justification for 250ms cutoff

2. **Ratcliff, Thapar, & McKoon (2001)** - `ratcliff2001aging`
   - Validates non-decision time slowing in perceptual tasks
   - Relevant for change detection paradigms

### Methodological/Physiological Papers

3. **Woods et al. (2015)** - `woods2015age`
   - Large sample demonstrating motor execution slowing with age
   - Physiological basis for cutoff

4. **Whelan (2008)** - `whelan2008effective`
   - Methodological review supporting population-adjusted cutoffs

## Usage in Report

The filtering statement now includes:

```markdown
**Filtering**: RTs < 0.250 s were excluded as anticipations. While a 150--200 ms cutoff is standard for young adult populations [@whelan2008effective], research consistently demonstrates that older adults exhibit significantly longer non-decision times ($T_{er}$), reflecting age-related slowing in stimulus encoding and motor execution. Specifically, drift diffusion modeling in aging populations estimates that $T_{er}$ is approximately 80--100 ms longer in older adults compared to their younger counterparts [@ratcliff2001aging; @ratcliff2004aging]. Consequently, a 250 ms threshold provides a conservative lower bound that adjusts for this physiological shift, ensuring that excluded trials represent genuine non-decisional reflexes rather than the leading edge of the valid decision distribution [@woods2015age]. The upper bound of 3.000 s reflects the maximum response window in the task design; no upper-bound filtering was applied post-experiment.
```

## Citation Format

Quarto will automatically:
- Format citations in the text (e.g., "Ratcliff et al., 2001, 2004")
- Generate a formatted References section at the end
- Use the citation style appropriate for the output format (HTML/PDF/DOCX)

## Next Steps

1. **Render the document** to verify citations appear correctly:
   ```bash
   quarto render reports/chap3_ddm_results.qmd
   ```

2. **Add LC Behavioral Report citation** when available (currently noted as "in preparation")

3. **Verify citation style** matches your target journal's requirements (may need to adjust BibTeX entries or add a CSL file)

## Citation Keys Used

- `ratcliff2004aging` - Ratcliff et al. (2004) Psychology and Aging
- `ratcliff2001aging` - Ratcliff et al. (2001) Psychology and Aging  
- `woods2015age` - Woods et al. (2015) Frontiers in Human Neuroscience
- `whelan2008effective` - Whelan (2008) The Psychological Record



