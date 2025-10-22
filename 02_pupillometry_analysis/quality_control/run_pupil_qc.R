#!/usr/bin/env Rscript

# Wrapper: Pupillometry QC summary
# Uses logs and generates summary plots via scripts/create_rt_sanity_check_plot.R (example)

suppressWarnings(suppressMessages({
  source(file.path('scripts','create_rt_sanity_check_plot.R'))
}))
