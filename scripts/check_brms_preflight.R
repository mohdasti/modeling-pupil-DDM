#!/usr/bin/env Rscript
# Verify brms / cmdstanr / rstan load before long GCP jobs.
# Usage: Rscript scripts/check_brms_preflight.R

ok <- TRUE
msg <- character()

tryCatch({
  suppressPackageStartupMessages(library(cmdstanr))
  cp <- cmdstanr::cmdstan_path()
  if (!dir.exists(cp)) stop("cmdstan_path() missing: ", cp)
  msg <- c(msg, paste("cmdstanr OK:", cp))
}, error = function(e) {
  ok <<- FALSE
  msg <<- c(msg, paste("cmdstanr FAIL:", conditionMessage(e)))
})

tryCatch({
  suppressPackageStartupMessages(library(rstan))
  msg <- c(msg, paste("rstan OK:", as.character(packageVersion("rstan"))))
}, error = function(e) {
  ok <<- FALSE
  msg <<- c(msg, paste("rstan FAIL:", conditionMessage(e)))
  msg <<- c(msg, paste(
    "Fix (on VM): Rscript scripts/fix_rstan_vm.R",
    "Or: remove.packages('rstan'); install.packages(c('Rcpp','RcppEigen','StanHeaders','rstan'), repos='https://cloud.r-project.org')"
  ))
})

tryCatch({
  suppressPackageStartupMessages(library(brms))
  msg <- c(msg, paste("brms OK:", as.character(packageVersion("brms"))))
}, error = function(e) {
  ok <<- FALSE
  msg <<- c(msg, paste("brms FAIL:", conditionMessage(e)))
})

cat(paste(msg, collapse = "\n"), "\n")
if (!ok) quit(save = "no", status = 1)
