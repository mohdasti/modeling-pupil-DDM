suppressPackageStartupMessages({ library(quarto) })

# Ensure we're in project root
if (basename(getwd()) == "R") {
  setwd("..")
}

quarto::quarto_render("reports/chap3_ddm_results.qmd", output_format = c("html","docx"))
cat("✓ Rendered: reports/chap3_ddm_results.html and .docx\n")

