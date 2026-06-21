#!/usr/bin/env Rscript
# Generate CONSORT-inspired participant / analytic-sample flow figure (Chapter 3 DDM).

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
})

if (basename(getwd()) == "scripts" && basename(dirname(getwd())) == "07_manuscript") {
  setwd(normalizePath(file.path(getwd(), "..", "..")))
}
repo_root <- normalizePath(".", mustWork = TRUE)
options(ch3.repo_root = repo_root)

source(file.path(repo_root, "R", "colors_manuscript.R"))
source(file.path(repo_root, "R", "participant_flow_helpers.R"))
source(file.path(repo_root, "R", "plot_participant_flow.R"))

figures_dir <- file.path(repo_root, "07_manuscript", "supplementary", "figures")
publish_fig_dir <- file.path(repo_root, "output", "figures")
dir.create(figures_dir, recursive = TRUE, showWarnings = TRUE)
dir.create(publish_fig_dir, recursive = TRUE, showWarnings = TRUE)

flow <- summarize_ch3_participant_flow(repo_root = repo_root)
cat("Participant flow summary:\n")
str(flow, max.level = 2)

p <- plot_ch3_participant_flow(flow, task_colors = task_colors)

out_png <- file.path(figures_dir, "s1_participant_flow.png")
out_pdf <- file.path(figures_dir, "s1_participant_flow.pdf")
pub_png <- file.path(publish_fig_dir, "s1_participant_flow.png")
pub_pdf <- file.path(publish_fig_dir, "s1_participant_flow.pdf")

ggplot2::ggsave(out_png, p, width = 8.5, height = 11.5, dpi = 300, bg = "white")
ggplot2::ggsave(out_pdf, p, width = 8.5, height = 11.5, bg = "white")
ggplot2::ggsave(pub_png, p, width = 8.5, height = 11.5, dpi = 300, bg = "white")
ggplot2::ggsave(pub_pdf, p, width = 8.5, height = 11.5, bg = "white")

cat("Saved:", out_png, "\n")
cat("Saved:", out_pdf, "\n")
cat("Saved:", pub_png, "\n")
cat("Saved:", pub_pdf, "\n")
