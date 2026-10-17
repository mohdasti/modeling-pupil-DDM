# Phase 1 inventory (Part 1.1)

Recorded before any chapter edits. Branch: `ch3-qmd-revision` (from `ch3-r8-finalize` at `7c00aa5`).

## Versions

| Item | Version |
|---|---|
| Quarto | 1.9.38 |
| R | 4.6.1 (2026-06-24) |
| rmarkdown | 2.31 |
| knitr | 1.51 |
| gt | 1.3.0 (loaded by the July qmd) |
| kableExtra | 1.4.0 (used for APA tables in the July qmd) |
| flextable | not installed |

The July chapter table path is `knitr::kable` + `kableExtra`, not flextable.

## Bibliography, CSL, reference docx

- Bibliography: `references.bib`, resolved next to the qmd as `reports/references.bib` (111 entries).
- CSL: `apa-7th-edition.csl`, resolved as `reports/apa-7th-edition.csl`.
- Reference docx: not set in the July YAML. No `reference-doc` key.

Fig/tbl prefixes are not customized. Quarto defaults apply (`Figure`, `Table`). Custom crossref types:

| key | kind | latex-env | reference-prefix | space-before-numbering | caption-location |
|---|---|---|---|---|---|
| suppfig | float | suppfig | Figure S | false | (default) |
| supptbl | float | supptbl | Table S | false | top |

## July YAML (full)

```yaml
---
title: "Physical Effort Reduces Evidence Accumulation Quality in Older Adults: A Hierarchical Diffusion Decision Model Analysis"
author: "Mohammad Dastgheib"
bibliography: references.bib
csl: apa-7th-edition.csl
prefer-html: true
always_allow_html: true
params:
  run_dir: "output/ddm_refits/runs/20260226_092110"
format:
  html:
    toc: true
    toc-depth: 3
    number-sections: true
    embed-resources: true
  pdf:
    toc: false
    toc-depth: 3
    number-sections: true
    pdf-engine: xelatex  # ensures Unicode symbols render correctly
    documentclass: article
    geometry:
      - margin=1in
    fontsize: 11pt
    linestretch: 1.5
    fig-pos: "htbp"  # QC fix: Changed from "H" to "htbp" to allow flexible float placement and reduce blank pages
    include-in-header:
      text: |
        % XeLaTeX (pdf-engine: xelatex): Unicode supported natively; avoid fontenc/inputenc
        \usepackage{pdflscape}
        \usepackage{caption}
        \usepackage{adjustbox}
        \usepackage{longtable}
        \usepackage{amsmath}
        \usepackage{amssymb}
        \usepackage{placeins}
  docx:
    toc: true
    number-sections: true
    prefer-html: false
    fig-format: png
    dpi: 300

crossref:
  custom:
    - kind: float
      key: suppfig
      latex-env: suppfig
      reference-prefix: "Figure S"
      space-before-numbering: false
    - kind: float
      key: supptbl
      latex-env: supptbl
      reference-prefix: "Table S"
      space-before-numbering: false
      caption-location: top

execute:
  echo: false
  warning: false
  message: false
---
```

## Files confirmed to load

Run directory: `output/ddm_refits/runs/final_20261016/`.

- `tables/final/inline_values.rds`: loaded, 121 names, 120 unique. `n_pupil_matched_trials` is stored twice (indices 12 and 66); both values are 12630.
- 26 `tables/final/*.csv` files: each `read.csv` succeeded.
- 15 `figures/final/*.png` files: each has a PNG signature and non-zero size.

Lani's commented draft was not in the repo or `reports/`. Used the only file with that name: `/Users/mohdasti/Downloads/chap3_July1st.docx`. Comment elements in `word/comments.xml`: 79 (ids 0–78).
