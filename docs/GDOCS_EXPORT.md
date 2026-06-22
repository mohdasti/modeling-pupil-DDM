# Google Docs export (Chapter 3)

Quarto → DOCX → Google Docs often breaks **HTML tables**, **PDF figures**, and leaves hundreds of **Word bookmarks**. This pipeline fixes those before upload.

## One-command export

```bash
Rscript scripts/render_chap3_gdocs.R
```

**Output:** `reports/chap3_ddm_results_gdocs.docx`

## Upload to Google Docs (recommended)

1. Go to [Google Drive](https://drive.google.com).
2. **New → File upload** → select `chap3_ddm_results_gdocs.docx`.
3. Right-click the uploaded file → **Open with → Google Docs**.

Do **not** use **File → Open** inside an existing Google Doc to import the DOCX; Drive upload converts more reliably.

## What the pipeline changes

| Issue | Fix |
|-------|-----|
| Missing figures | DOCX embeds **PNG** only (no PDF); appendix setup no longer overrides figure helpers |
| Broken tables | `knitr::kable(format = "pipe")` + no HTML `kableExtra` styling in DOCX |
| `gt` tables | Rendered as simple pipe tables in DOCX |
| Bookmark clutter | Removed by `scripts/postprocess_docx_for_gdocs.py` (~400 anchors) |

## Optional: PyMuPDF for leftover PDF embeds

If any PDF figures remain after render, install PyMuPDF so the post-processor can rasterize them. On macOS, **sips** is used automatically when PyMuPDF is absent.

```bash
pip install pymupdf
```

## Manual steps

```bash
quarto render reports/chap3_ddm_results.qmd --to docx
python3 scripts/postprocess_docx_for_gdocs.py reports/chap3_ddm_results.docx \
  --output reports/chap3_ddm_results_gdocs.docx
```

## After import

- Spot-check **Appendix A2.1** participant flow figure and wide tables (trial counts, PPC gates).
- Equations and cross-reference links may simplify on import; update manually in GDocs if needed.
- For final journal submission, keep using **PDF** from Quarto as the authoritative layout.
