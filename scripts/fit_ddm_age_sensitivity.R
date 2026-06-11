#!/usr/bin/env Rscript
# =========================================================================
# DDM AGE SENSITIVITY ANALYSIS
# =========================================================================
# Adds age_centered (mean-centered) as a predictor for drift and boundary,
# with Age × Effort interactions. Same priors/chains/convergence as primary.
# Output: ddm_age_model.rds
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(tidyr)
})

# Project root (match ddm_refit_gcp.R: infer from script path when on GCP)
PROJECT_ROOT <- Sys.getenv("DDM_GCP_PROJECT_ROOT", unset = "")
if (!is.character(PROJECT_ROOT) || length(PROJECT_ROOT) != 1 || !nzchar(trimws(PROJECT_ROOT))) {
  PROJECT_ROOT <- ""
}
if (PROJECT_ROOT == "" || !dir.exists(PROJECT_ROOT)) {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  farg <- grep("^--file=", cmd_args, value = TRUE)
  if (length(farg) > 0) {
    script_dir <- dirname(normalizePath(sub("^--file=", "", farg[1]), mustWork = FALSE))
    PROJECT_ROOT <- normalizePath(file.path(script_dir, ".."), mustWork = FALSE)
  } else if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    proj <- tryCatch(rstudioapi::getActiveProject(), error = function(e) NULL)
    PROJECT_ROOT <- if (is.character(proj) && nzchar(proj)) proj else ""
  } else {
    PROJECT_ROOT <- ""
  }
  if (PROJECT_ROOT == "" || !dir.exists(PROJECT_ROOT)) {
    PROJECT_ROOT <- getwd()
  }
}
if (nzchar(PROJECT_ROOT) && dir.exists(PROJECT_ROOT)) {
  setwd(PROJECT_ROOT)
  message("[GCP] Set working directory to: ", getwd())
}

# Search for project root: current dir, parents, and ~/Feb2026 (common GCP path)
find_project_root <- function() {
  cwd <- getwd()
  candidates <- c(
    cwd,
    dirname(cwd),
    normalizePath(file.path(cwd, "..", ".."), mustWork = FALSE),
    path.expand("~/Feb2026"),
    file.path(cwd, "Feb2026")
  )
  for (cand in unique(candidates)) {
    if (!nzchar(cand) || !dir.exists(cand)) next
    test_path <- file.path(cand, "data", "ddm_ready_data_unthresholded.csv")
    if (file.exists(test_path)) {
      setwd(cand)
      message("[GCP] Found data in: ", cand, " - set as project root")
      return(invisible(NULL))
    }
  }
}
find_project_root()

# =========================================================================
# CONFIGURATION
# =========================================================================

CHOSEN_THRESHOLD <- 0.20
PROBE_ONSET_OFFSET <- 0.35  # rt_cue + 0.35 = rt_probe_onset
N_CHAINS <- 8
N_ITER <- 2000
N_WARMUP <- 1000
ADAPT_DELTA <- 0.95
MAX_TREEDEPTH <- 12
OUTPUT_FILE <- "output/ddm_refits/ddm_age_model.rds"

# Input paths (relative to project root, or current dir if in data/)
DDM_DATA_PATHS <- c(
  "data/ddm_ready_data_unthresholded.csv",
  "ddm_ready_data_unthresholded.csv",
  "output/rt_threshold_analysis/ddm_ready_data_unthresholded.csv",
  "data/analysis_ready/bap_ddm_only_ready.csv",
  "data/analysis_ready/BAP_analysis_ready_DDM_READY.csv",
  "data/ddm_ready_data.csv"
)
AGE_DATA_PATHS <- c(
  "data/analysis_ready/BAP_analysis_ready_BEHAVIORAL_full.csv",
  "data/BAP_analysis_ready_BEHAVIORAL_full.csv",
  "BAP_analysis_ready_BEHAVIORAL_full.csv",
  "data/analysis_ready/BAP_analysis_ready_BEHAVIORAL.csv"
)

# =========================================================================
# LOAD AND PREPARE DATA
# =========================================================================

cat("Loading DDM-ready data...\n")
cat("  Working directory:", getwd(), "\n")
ddm_path <- NULL
for (p in DDM_DATA_PATHS) {
  if (file.exists(p)) {
    ddm_path <- p
    break
  }
}
if (is.null(ddm_path)) {
  cat("  Tried paths:\n")
  for (p in DDM_DATA_PATHS) cat("    -", p, "\n")
  stop(
    "No DDM data file found. Upload one of these to GCP:\n",
    "  - data/ddm_ready_data_unthresholded.csv (from build_ddm_ready_data_unthresholded.R)\n",
    "  - data/analysis_ready/bap_ddm_only_ready.csv\n",
    "Or set DDM_GCP_PROJECT_ROOT to your project root and ensure data/ exists."
  )
}

df_raw <- read_csv(ddm_path, show_col_types = FALSE)
cat("  Loaded", nrow(df_raw), "trials from", ddm_path, "\n")

# Standardize to common format (match ddm_refit_gcp.R)
if ("rt_probe_onset_locked" %in% names(df_raw)) {
  df_raw$rt_probe_onset <- df_raw$rt_probe_onset_locked
} else if ("rt" %in% names(df_raw)) {
  df_raw$rt_probe_onset <- df_raw$rt + PROBE_ONSET_OFFSET
} else {
  stop("Need rt or rt_probe_onset_locked in data")
}

if ("rt_cue_locked" %in% names(df_raw)) {
  df_raw$rt_cue <- df_raw$rt_cue_locked
} else if ("rt" %in% names(df_raw)) {
  df_raw$rt_cue <- df_raw$rt
} else {
  stop("Need rt or rt_cue_locked in data")
}

df_raw$subject_id <- as.character(df_raw$subject_id)
df_raw$task <- ifelse(tolower(substr(as.character(df_raw$task), 1, 1)) %in% c("a", "u"), "ADT", "VDT")
df_raw$task <- factor(df_raw$task, levels = c("ADT", "VDT"))

# Effort: map Low/High, Low_5_MVC/High_40_MVC -> low/high
eff_char <- tolower(as.character(df_raw$effort_condition))
df_raw$effort_condition <- factor(
  ifelse(grepl("high|40", eff_char), "high", "low"),
  levels = c("low", "high")
)

# Difficulty
if ("difficulty_level" %in% names(df_raw)) {
  diff_char <- tolower(as.character(df_raw$difficulty_level))
  df_raw$difficulty_3 <- factor(
    case_when(
      grepl("standard|0", diff_char) ~ "Standard",
      grepl("easy|3|4", diff_char) ~ "Easy",
      grepl("hard|1|2", diff_char) ~ "Hard",
      TRUE ~ "Standard"
    ),
    levels = c("Standard", "Hard", "Easy")
  )
} else {
  stop("difficulty_level required")
}

# Choice (1 = different/upper boundary)
if ("choice_binary" %in% names(df_raw)) {
  df_raw$choice_binary <- as.integer(df_raw$choice_binary)
} else if ("resp_is_diff" %in% names(df_raw)) {
  df_raw$choice_binary <- as.integer(df_raw$resp_is_diff)
} else {
  stop("choice_binary or resp_is_diff required in DDM data")
}

# Load age and merge
cat("Loading age data...\n")
age_df <- NULL
for (p in AGE_DATA_PATHS) {
  if (file.exists(p)) {
    adf <- read_csv(p, show_col_types = FALSE)
    if ("age" %in% names(adf) && "subject_id" %in% names(adf)) {
      age_df <- adf %>% distinct(subject_id, .keep_all = TRUE) %>%
        select(subject_id, age) %>%
        mutate(subject_id = as.character(subject_id), age = as.numeric(age)) %>%
        filter(!is.na(age))
      cat("  Loaded age for", nrow(age_df), "subjects from", p, "\n")
      break
    }
  }
}
if (is.null(age_df) || nrow(age_df) == 0) {
  stop("No age data found. Ensure BAP_analysis_ready_BEHAVIORAL_full.csv has subject_id and age.")
}

# Mean-center age
age_mean <- mean(age_df$age, na.rm = TRUE)
age_df$age_centered <- age_df$age - age_mean
cat("  Age: mean =", round(age_mean, 1), ", centered range [",
    round(min(age_df$age_centered), 1), ",", round(max(age_df$age_centered), 1), "]\n")

# Merge age into DDM data
ddm_data <- df_raw %>%
  select(subject_id, task, effort_condition, difficulty_3, rt_cue, rt_probe_onset, choice_binary) %>%
  left_join(age_df %>% select(subject_id, age_centered), by = "subject_id")

# Drop subjects without age
n_before <- nrow(ddm_data)
ddm_data <- ddm_data %>% filter(!is.na(age_centered))
n_dropped <- n_before - nrow(ddm_data)
if (n_dropped > 0) cat("  Dropped", n_dropped, "trials (missing age)\n")

# Apply RT threshold (probe-onset-locked, 0.20 s)
ddm_data <- ddm_data %>%
  filter(rt_cue >= CHOSEN_THRESHOLD, rt_cue <= 3.0) %>%
  filter(rt_probe_onset >= CHOSEN_THRESHOLD)

ddm_data$rt <- ddm_data$rt_probe_onset  # brms expects 'rt'
cat("  Final N:", nrow(ddm_data), "trials,", length(unique(ddm_data$subject_id)), "subjects\n\n")

# =========================================================================
# MODEL SPECIFICATION
# =========================================================================

# Drift: difficulty + effort + age_centered + effort:age_centered
# Boundary: difficulty + effort + age_centered + effort:age_centered (no RE, match primary)
# Bias: task + effort (unchanged)
# NDT: intercept only
formula_age <- bf(
  rt | dec(choice_binary) ~ 1 + effort_condition + difficulty_3 + age_centered +
    effort_condition:age_centered + (1 | subject_id),
  bs ~ 1 + effort_condition + difficulty_3 + age_centered + effort_condition:age_centered,
  ndt ~ 1,
  bias ~ task + effort_condition + (1 | subject_id)
)

# Priors: match primary; Age main Normal(0, 0.5), Age×Effort Normal(0, 0.6)
min_rt <- min(ddm_data$rt, na.rm = TRUE)
ndt_ub_val <- as.numeric(log(max(min_rt - 0.01, 0.05)))
cat("  NDT upper bound (log scale):", round(ndt_ub_val, 4), "\n")

priors_age <- c(
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(log(1.3), 0.25), class = "Intercept", dpar = "bs"),
  eval(substitute(
    prior(normal(log(0.35), 0.15), class = "Intercept", dpar = "ndt",
          lb = log(0.02), ub = NDT_UB),
    list(NDT_UB = ndt_ub_val)
  )),
  prior(normal(0, 1.5), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.5), class = "b"),
  prior(normal(0, 0.5), class = "b", dpar = "bs"),
  prior(normal(0, 0.5), class = "b", dpar = "bias"),
  # Age×Effort interaction: Normal(0, 0.6); coef name may vary by brms version
  prior(normal(0, 0.6), class = "b", coef = "effort_conditionhigh:age_centered"),
  prior(normal(0, 0.6), class = "b", dpar = "bs", coef = "effort_conditionhigh:age_centered"),
  prior(exponential(1), class = "sd"),
  prior(exponential(2), class = "sd", dpar = "bias")
)

# =========================================================================
# FIT MODEL
# =========================================================================

cat("Fitting age sensitivity model...\n")
cat("  Formula: drift ~ difficulty + effort + age + effort:age\n")
cat("  Chains:", N_CHAINS, ", iter:", N_ITER, ", adapt_delta:", ADAPT_DELTA, "\n\n")

# Safe init: probe-onset-locked NDT ~0.30s, bs ~1.3 (match primary model)
# Critical: NDT must be < min(RT); Intercept_ndt=log(0.30) gives ndt=0.30s
safe_init_age <- function(chain_id = 1) {
  list(
    Intercept = 0,
    Intercept_bs = log(1.3),
    Intercept_ndt = log(min(0.30, min(ddm_data$rt, na.rm = TRUE) * 0.9)),
    Intercept_bias = 0,
    sd_subject_id__Intercept = 0.1,
    sd_subject_id__bias_Intercept = 0.1
  )
}

fit_age <- brm(
  formula = formula_age,
  data = ddm_data,
  family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
  prior = priors_age,
  chains = N_CHAINS,
  iter = N_ITER,
  warmup = N_WARMUP,
  cores = N_CHAINS,
  init = safe_init_age,
  control = list(adapt_delta = ADAPT_DELTA, max_treedepth = MAX_TREEDEPTH),
  backend = "cmdstanr",
  save_pars = save_pars(all = TRUE)
)

# =========================================================================
# SAVE AND REPORT
# =========================================================================

dir.create(dirname(OUTPUT_FILE), recursive = TRUE, showWarnings = FALSE)
saveRDS(fit_age, OUTPUT_FILE)
cat("Saved:", OUTPUT_FILE, "\n\n")

# Summary
cat("=== MODEL SUMMARY ===\n")
print(summary(fit_age))

# Convergence check
rhat_max <- max(rhat(fit_age), na.rm = TRUE)
cat("\n=== CONVERGENCE ===\n")
cat("  max Rhat:", round(rhat_max, 4), if (rhat_max < 1.01) "(OK)" else "(WARNING: > 1.01)\n")

# Age and Age×Effort coefficients
fixef_age <- fixef(fit_age, summary = TRUE)
age_terms <- grep("age_centered|age_centered:effort|effort.*age", rownames(fixef_age), 
                  value = TRUE, ignore.case = TRUE)
if (length(age_terms) > 0) {
  cat("\n=== AGE COEFFICIENTS ===\n")
  print(fixef_age[age_terms, , drop = FALSE])
}

# Posterior contrasts: Age × Effort on drift
draws <- as_draws_df(fit_age)
age_effort_col <- grep("effort.*age_centered|age_centered.*effort", names(draws), value = TRUE)
age_effort_col <- age_effort_col[!grepl("^bs_", age_effort_col)][1]  # drift only (not bs)
if (!is.na(age_effort_col) && age_effort_col %in% names(draws)) {
  cat("\n=== AGE × EFFORT ON DRIFT (posterior) ===\n")
  cat("  Mean:", round(mean(draws[[age_effort_col]]), 4), "\n")
  cat("  95% CrI: [", round(quantile(draws[[age_effort_col]], 0.025), 4), ",",
      round(quantile(draws[[age_effort_col]], 0.975), 4), "]\n")
  cat("  P(>0):", round(mean(draws[[age_effort_col]] > 0), 3), "\n")
}

cat("\nDone.\n")
