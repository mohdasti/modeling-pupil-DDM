suppressPackageStartupMessages({ library(quarto) })

# Ensure we're in project root
if (basename(getwd()) == "R") {
  setwd("..")
}

flow_script <- "07_manuscript/scripts/plot_participant_flow.R"
if (file.exists(flow_script)) {
  cat("Generating participant flow figure...\n")
  status <- system2("Rscript", flow_script)
  if (status != 0) {
    stop("Failed to generate participant flow figure via ", flow_script)
  }
}

quarto::quarto_render("reports/chap3_ddm_results.qmd", output_format = c("html","docx"))
cat("✓ Rendered: reports/chap3_ddm_results.html and .docx\n")

