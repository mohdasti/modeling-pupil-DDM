# Summaries for the r8 pupil export. Run on the VM from ~/Feb2026.
# Does not refit. P5 and P4 are compared with P0_base, not the full-sample P0.
# Rscript scripts/r8/E_extract_summaries.R

options(warn = 1, scipen = 999)
suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(readr)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
RUN <- Sys.getenv("PUPIL_RUN_DIR", unset = "output/ddm_refits/runs/r8_20261017_015218")
OUT <- file.path(RUN, "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

qsum <- function(x) {
  x <- x[is.finite(x)]
  data.frame(
    median = stats::median(x),
    q2.5 = as.numeric(stats::quantile(x, 0.025)),
    q97.5 = as.numeric(stats::quantile(x, 0.975)),
    p_lt0 = mean(x < 0),
    p_gt0 = mean(x > 0),
    stringsAsFactors = FALSE
  )
}

fit_path <- function(key) {
  file.path(RUN, "models", sprintf("%s__probe_onset_locked__thr0.20.rds", key))
}
loo_path <- function(key) file.path(RUN, "loo", sprintf("loo_%s.rds", key))

load_fit <- function(key) {
  path <- fit_path(key)
  if (!file.exists(path)) stop("Missing model: ", path)
  readRDS(path)
}
load_loo <- function(key) {
  path <- loo_path(key)
  if (!file.exists(path)) stop("Missing loo: ", path)
  readRDS(path)
}
coef_draws <- function(fit, term) {
  dr <- as.data.frame(as_draws_df(fit, variable = term, regex = FALSE))
  if (!term %in% names(dr)) stop("Term not in draws: ", term)
  dr[[term]]
}
delta_elpd <- function(a, b) {
  la <- load_loo(a)
  lb <- load_loo(b)
  da <- la$pointwise[, "elpd_loo"]
  db <- lb$pointwise[, "elpd_loo"]
  if (length(da) != length(db)) {
    stop("Pointwise length mismatch: ", a, " ", length(da), " vs ", b, " ", length(db))
  }
  d <- da - db
  data.frame(
    delta_elpd = sum(d),
    se_delta_elpd = stats::sd(d) * sqrt(length(d)),
    n_pointwise = length(d),
    stringsAsFactors = FALSE
  )
}

pairs <- data.frame(
  model = c("P1", "P2", "P2", "P3", "P4", "P5", "P3_rt", "P6", "P7", "P8"),
  baseline = c("P0", "P0", "P0", "P0", "P0_base", "P0_base", "P0_rt", "P0_lag", "P0_pre", "P0_grip"),
  term = c(
    "b_bias_tepr_c", "b_tepr_c", "b_tepr_c:stim_sign", "b_bs_tepr_c",
    "b_bias_base_c", "b_bs_base_c", "b_bs_tepr_c", "b_bs_lag_tepr_c",
    "b_bs_prechoice_c", "b_bs_grip_c"
  ),
  stringsAsFactors = FALSE
)

cache <- list()
get_fit <- function(key) {
  if (is.null(cache[[key]])) cache[[key]] <<- load_fit(key)
  cache[[key]]
}

rows <- vector("list", nrow(pairs))
for (i in seq_len(nrow(pairs))) {
  key <- pairs$model[i]
  base <- pairs$baseline[i]
  term <- pairs$term[i]
  message("slope ", key, " ", term, " vs ", base)
  fit <- get_fit(key)
  x <- coef_draws(fit, term)
  s <- qsum(x)
  on_boundary <- grepl("^b_bs_", term)
  pct <- if (on_boundary) qsum(100 * (exp(x) - 1)) else {
    data.frame(median = NA_real_, q2.5 = NA_real_, q97.5 = NA_real_,
               p_lt0 = NA_real_, p_gt0 = NA_real_, stringsAsFactors = FALSE)
  }
  dv <- delta_elpd(key, base)
  lo <- load_loo(key)
  rows[[i]] <- data.frame(
    model = key, baseline = base, term = term,
    median = s$median, q2.5 = s$q2.5, q97.5 = s$q97.5,
    p_lt0 = s$p_lt0, p_gt0 = s$p_gt0,
    pct_change_a_median = pct$median,
    pct_change_a_q2.5 = pct$q2.5,
    pct_change_a_q97.5 = pct$q97.5,
    delta_elpd = dv$delta_elpd, se_delta_elpd = dv$se_delta_elpd,
    n_pointwise = dv$n_pointwise,
    n_trials = nrow(fit$data),
    n_subjects = length(unique(fit$data$subject_id)),
    elpd_loo = lo$estimates["elpd_loo", "Estimate"],
    se_elpd_loo = lo$estimates["elpd_loo", "SE"],
    stringsAsFactors = FALSE
  )
  if (!identical(key, pairs$model[i + 1])) {
    cache[[key]] <- NULL
    gc(verbose = FALSE)
  }
}
slopes <- do.call(rbind, rows)
write_csv(slopes, file.path(OUT, "r8_slopes.csv"))

effort_terms <- c(
  "b_effort_conditionhigh", "b_effort_x_stim",
  "b_bs_effort_conditionhigh", "b_bias_effort_conditionhigh"
)
effort_rows <- list()
for (key in c("P0", "P0_base")) {
  message("effort ", key)
  fit <- load_fit(key)
  for (term in effort_terms) {
    x <- coef_draws(fit, term)
    s <- qsum(x)
    pct <- if (grepl("^b_bs_", term)) qsum(100 * (exp(x) - 1)) else {
      data.frame(median = NA_real_, q2.5 = NA_real_, q97.5 = NA_real_,
                 stringsAsFactors = FALSE)
    }
    effort_rows[[length(effort_rows) + 1]] <- data.frame(
      model = key, term = term,
      median = s$median, q2.5 = s$q2.5, q97.5 = s$q97.5,
      p_lt0 = s$p_lt0, p_gt0 = s$p_gt0,
      pct_change_a_median = pct$median,
      pct_change_a_q2.5 = pct$q2.5,
      pct_change_a_q97.5 = pct$q97.5,
      n_trials = nrow(fit$data),
      n_subjects = length(unique(fit$data$subject_id)),
      stringsAsFactors = FALSE
    )
  }
  rm(fit)
  gc(verbose = FALSE)
}
write_csv(do.call(rbind, effort_rows), file.path(OUT, "r8_effort_terms.csv"))
message("Wrote ", file.path(OUT, "r8_slopes.csv"))
message("Wrote ", file.path(OUT, "r8_effort_terms.csv"))
