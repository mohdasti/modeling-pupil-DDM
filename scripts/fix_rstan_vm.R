#!/usr/bin/env Rscript
# Rebuild rstan stack after R upgrade (fixes class_model_base / Rcpp loadModule errors).
# Run on GCP VM: Rscript scripts/fix_rstan_vm.R

repos <- "https://cloud.r-project.org"
pkgs_src <- c("Rcpp", "RcppEigen", "StanHeaders", "rstan")

for (p in c("rstan", "brms")) {
  if (p %in% rownames(installed.packages())) {
    try(remove.packages(p), silent = TRUE)
  }
}

install.packages(pkgs_src, repos = repos, type = "source")

suppressPackageStartupMessages(library(rstan))
cat("rstan", as.character(packageVersion("rstan")), "loaded OK\n")

if (!requireNamespace("brms", quietly = TRUE)) {
  install.packages("brms", repos = repos)
}
suppressPackageStartupMessages(library(brms))
cat("brms", as.character(packageVersion("brms")), "loaded OK\n")
