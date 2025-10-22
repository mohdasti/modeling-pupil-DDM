#!/usr/bin/env Rscript

# Thin wrapper: unified entrypoint delegates to canonical core runner
system2("Rscript", c("scripts/core/run_analysis.R", commandArgs(trailingOnly = TRUE)), stdout = "", stderr = "")
