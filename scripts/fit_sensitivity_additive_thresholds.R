#!/usr/bin/env Rscript
# Fit additive DDM (probe-onset-locked) at RT cutoffs 0.15 / 0.20 / 0.25 s.
# Skips thresholds where additive__probe_onset_locked__thr*.rds already exists.
#
# Usage:
#   DDM_RUN_ID=20260226_092110 Rscript scripts/fit_sensitivity_additive_thresholds.R
#
# Requires unthresholded trial data (data/ddm_ready_data_unthresholded.csv on VM/Mac).
# After fitting, runs export_h1_h2_by_rt_cutoff.R.

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(readr)
  library(here)
  library(tibble)
})

RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
THRESHOLDS <- as.numeric(strsplit(Sys.getenv("DDM_THRESHOLDS", "0.15,0.20,0.25"), ",")[[1]])
PROBE_ONSET_TO_PROMPT_SEC <- 0.35
ROOT <- here::here()
RUN_DIR <- file.path(ROOT, "output", "ddm_refits", "runs", RUN_ID)
MODELS_DIR <- file.path(RUN_DIR, "models")
LOG_DIR <- file.path(RUN_DIR, "logs")
dir.create(MODELS_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

LOG_FILE <- file.path(LOG_DIR, "fit_sensitivity_additive.log")
log_msg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = LOG_FILE, append = TRUE)
}

input_candidates <- c(
  Sys.getenv("DDM_INPUT_FILE", ""),
  "data/ddm_ready_data_unthresholded.csv",
  "output/rt_threshold_analysis/ddm_ready_data_unthresholded.csv",
  "data/ddm_ready_data.csv"
)
input_candidates <- input_candidates[nzchar(input_candidates) & file.exists(input_candidates)]
if (length(input_candidates) == 0) {
  stop("No unthresholded DDM input CSV found. Set DDM_INPUT_FILE.")
}
input_file <- input_candidates[1]
log_msg("Input:", input_file)

raw <- read_csv(input_file, show_col_types = FALSE)

standardize_ddm_input <- function(df) {
  out <- df
  if ("rt_cue_locked" %in% names(out)) {
    out$rt_cue <- as.numeric(out$rt_cue_locked)
  } else if (!"rt_cue" %in% names(out) && "rt" %in% names(out)) {
    out$rt_cue <- as.numeric(out$rt)
  }
  if ("rt_probe_onset_locked" %in% names(out)) {
    out$rt_probe_onset <- as.numeric(out$rt_probe_onset_locked)
  } else if (!"rt_probe_onset" %in% names(out) && "rt_cue" %in% names(out)) {
    out$rt_probe_onset <- out$rt_cue + PROBE_ONSET_TO_PROMPT_SEC
  }
  if (!"choice_binary" %in% names(out) && "resp_is_diff" %in% names(out)) {
    out$choice_binary <- as.integer(out$resp_is_diff)
  }
  if (!"difficulty_3" %in% names(out) && "difficulty_level" %in% names(out)) {
    if (is.numeric(out$difficulty_level)) {
      out$difficulty_3 <- case_when(
        out$difficulty_level == 0 ~ "Standard",
        out$difficulty_level %in% c(1, 2) ~ "Hard",
        out$difficulty_level %in% c(3, 4) ~ "Easy",
        TRUE ~ "Standard"
      )
    } else {
      dl <- as.character(out$difficulty_level)
      out$difficulty_3 <- case_when(
        grepl("standard|baseline|0", dl, ignore.case = TRUE) ~ "Standard",
        grepl("easy|3|4", dl, ignore.case = TRUE) ~ "Easy",
        grepl("hard|1|2", dl, ignore.case = TRUE) ~ "Hard",
        TRUE ~ "Standard"
      )
    }
  }
  if ("task" %in% names(out)) {
    tk <- tolower(as.character(out$task))
    out$task <- case_when(
      grepl("^a|aud", tk) ~ "ADT",
      grepl("^v|vis", tk) ~ "VDT",
      tk %in% c("adt", "vdt") ~ toupper(tk),
      TRUE ~ NA_character_
    )
  }
  if ("effort_condition" %in% names(out)) {
    ec <- tolower(as.character(out$effort_condition))
    out$effort_condition <- case_when(
      grepl("low|5_mvc|0\\.05", ec) ~ "low",
      grepl("high|40_mvc|0\\.4", ec) ~ "high",
      ec %in% c("low", "high") ~ ec,
      TRUE ~ NA_character_
    )
  }
  out
}

raw <- standardize_ddm_input(raw)
need <- c("rt_cue", "choice_binary", "difficulty_3", "task", "effort_condition", "subject_id")
miss <- setdiff(need, names(raw))
if (length(miss)) stop("Missing columns: ", paste(miss, collapse = ", "))

if (!"rt_probe_onset" %in% names(raw)) {
  raw$rt_probe_onset <- raw$rt_cue + PROBE_ONSET_TO_PROMPT_SEC
}

prep_threshold_data <- function(thr) {
  raw %>%
    filter(!is.na(rt_cue), rt_cue > 0, rt_cue <= 3.0, rt_cue >= thr) %>%
    mutate(
      rt_model = rt_probe_onset,
      subject_id = as.character(subject_id),
      choice_binary = as.integer(choice_binary),
      difficulty_3 = factor(difficulty_3, levels = c("Standard", "Hard", "Easy")),
      task = factor(task, levels = c("ADT", "VDT")),
      effort_condition = factor(effort_condition, levels = c("low", "high"))
    ) %>%
    filter(!is.na(rt_model), rt_model > 0, !is.na(task), !is.na(effort_condition))
}

formula_additive <- bf(
  rt | dec(choice_binary) ~ 1 + effort_condition + difficulty_3 + (1 | subject_id),
  bs ~ 1 + effort_condition + difficulty_3 + (1 | subject_id),
  ndt ~ 1,
  bias ~ task + effort_condition + (1 | subject_id)
)

safe_init <- function(chain_id = 1) {
  list(
    Intercept = 0,
    Intercept_bs = log(1.3),
    Intercept_ndt = log(0.30),
    Intercept_bias = 0,
    sd_subject_id__Intercept = 0.1,
    sd_subject_id__bs_Intercept = 0.1,
    sd_subject_id__bias_Intercept = 0.1
  )
}

fit_threshold <- function(thr) {
  thr_tag <- formatC(thr, format = "f", digits = 2)
  out_path <- file.path(MODELS_DIR, paste0("additive__probe_onset_locked__thr", thr_tag, ".rds"))
  if (file.exists(out_path) && Sys.getenv("PUPIL_REFIT", "on_change") != "always") {
    log_msg("Skip existing:", basename(out_path))
    return(invisible(out_path))
  }

  dat <- prep_threshold_data(thr)
  min_rt <- min(dat$rt_model, na.rm = TRUE)
  ndt_ub_val <- as.numeric(min_rt - 0.01)
  if (!is.finite(ndt_ub_val) || ndt_ub_val <= 0.05) {
    stop("Invalid ndt upper bound at threshold ", thr, ": ", ndt_ub_val)
  }
  ndt_ub <- as.numeric(log(ndt_ub_val))
  log_msg("Fit threshold=", thr, " N=", nrow(dat), " min_rt=", round(min_rt, 4))

  priors <- c(
    prior(normal(0, 1), class = "Intercept"),
    prior(normal(0, 0.5), class = "b"),
    prior(normal(log(1.3), 0.25), class = "Intercept", dpar = "bs", lb = log(0.3), ub = log(5)),
    prior(normal(0, 0.20), class = "b", dpar = "bs"),
    eval(substitute(
      prior(normal(log(0.35), 0.15), class = "Intercept", dpar = "ndt", lb = log(0.02), ub = UB_VAL),
      list(UB_VAL = ndt_ub)
    )),
    prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
    prior(normal(0, 0.5), class = "b", dpar = "bias"),
    prior(exponential(5), class = "sd"),
    prior(exponential(10), class = "sd", dpar = "bs"),
    prior(exponential(5), class = "sd", dpar = "bias")
  )

  fit <- brm(
    formula = formula_additive,
    data = dat %>% mutate(rt = rt_model),
    family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
    prior = priors,
    chains = 4L,
    iter = 2000L,
    warmup = 1000L,
    cores = 4L,
    init = safe_init,
    control = list(adapt_delta = 0.95, max_treedepth = 12L),
    backend = "cmdstanr",
    file = out_path,
    file_refit = Sys.getenv("PUPIL_REFIT", "on_change"),
    refresh = 100,
    silent = 0
  )
  log_msg("Done threshold=", thr, " max Rhat=", round(max(rhat(fit), na.rm = TRUE), 4))
  invisible(out_path)
}

for (thr in THRESHOLDS) {
  fit_threshold(thr)
}

log_msg("Exporting H1/H2 contrast table ...")
source(file.path(ROOT, "scripts", "export_h1_h2_by_rt_cutoff.R"), local = FALSE)
log_msg("All done.")
