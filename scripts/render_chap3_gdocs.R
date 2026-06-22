#!/usr/bin/env Rscript
# Render Chapter 3 DOCX optimized for Google Docs upload.

if (basename(getwd()) == "scripts") {
  setwd("..")
}

flow_script <- "07_manuscript/scripts/plot_participant_flow.R"
if (file.exists(flow_script)) {
  message("Generating participant flow figure...")
  status <- system2("Rscript", flow_script)
  if (status != 0) {
    stop("Failed to generate participant flow figure via ", flow_script)
  }
}

message("Rendering DOCX...")
status <- system2("quarto", c("render", "reports/chap3_ddm_results.qmd", "--to", "docx"))
if (status != 0) {
  stop("quarto render failed")
}

docx_in <- "reports/chap3_ddm_results.docx"
docx_out <- "reports/chap3_ddm_results_gdocs.docx"
post_script <- "scripts/postprocess_docx_for_gdocs.py"

if (!file.exists(post_script)) {
  stop("Missing post-process script: ", post_script)
}

message("Post-processing for Google Docs...")
status <- system2("python3", c(post_script, docx_in, "--output", docx_out))
if (status != 0) {
  stop("postprocess_docx_for_gdocs.py failed")
}

message("Done.")
message("  Upload this file to Google Drive -> Open with Google Docs:")
message("  ", normalizePath(docx_out, mustWork = TRUE))
