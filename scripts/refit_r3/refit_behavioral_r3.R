#!/usr/bin/env Rscript
# R3 behavioral DDM refit: M0 difficulty-only, M1 additive, M2 interaction,
# M3 criterion/quality, plus cutoff sensitivity for the selected primary model.
#
# Reads the canonical run read-only and writes only to
#   output/ddm_refits/runs/r3_<timestamp>/{models,loo,tables,logs}
#
# Usage (from the project root):
#   Rscript scripts/refit_r3/refit_behavioral_r3.R
#
# Environment:
#   R3_RUN_ID        reuse an existing r3 run directory (resume); default r3_<timestamp>
#   R3_OUT_ROOT      parent of the run directory; default output/ddm_refits/runs
#   R3_STAGES        comma list of fit,loo,compare,sens,summary (default: all)
#   R3_CORES         cores available to Stan (default: detectCores())
#   R3_THREADS       within-chain threads (default: floor(R3_CORES / chains), 1 = off)
#   R3_LOO_CORES     cores for loo() (default: R3_CORES)
#   R3_RELOO         1 = reloo remaining Pareto-k > 0.7 points (default 1)
#   R3_RELOO_MAX     skip reloo for a model with more bad points than this (default 5)
#   R3_RHAT_MAX      convergence threshold for primary-model selection (default 1.01)
#   R3_ESS_MIN       bulk and tail ESS threshold for selection (default 400)
#   R3_SMOKE         1 = tiny subset and sampler, for pipeline testing only

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(posterior)
  library(loo)
  library(dplyr)
  library(readr)
  library(tibble)
})

options(warn = 1)

# ---- paths and configuration -----------------------------------------------

ROOT <- normalizePath(Sys.getenv("PROJECT_ROOT", getwd()), mustWork = TRUE)
setwd(ROOT)

CANON_RUN <- file.path("output", "ddm_refits", "runs", "20260226_092110")
CANON_RDS <- file.path(CANON_RUN, "models", "additive__probe_onset_locked__thr0.20.rds")
PKG_DIR <- file.path("scripts", "refit_r3")
BUNDLED_RDS <- file.path(PKG_DIR, "inputs", "additive__probe_onset_locked__thr0.20.rds")
SOURCE_CSV_CANDIDATES <- c(
  file.path(PKG_DIR, "inputs", "ddm_ready_data_unthresholded.csv"),
  file.path("data", "ddm_ready_data_unthresholded.csv")
)
MD5_FILE <- file.path(PKG_DIR, "inputs", "md5sums.txt")

SMOKE <- Sys.getenv("R3_SMOKE", "0") == "1"
OUT_ROOT <- Sys.getenv("R3_OUT_ROOT", file.path("output", "ddm_refits", "runs"))
RUN_ID <- Sys.getenv("R3_RUN_ID", "")
if (!nzchar(RUN_ID)) {
  RUN_ID <- paste0(if (SMOKE) "r3_smoke_" else "r3_", format(Sys.time(), "%Y%m%d_%H%M%S"))
}
RUN_DIR <- file.path(OUT_ROOT, RUN_ID)
if (!grepl("^r3_", RUN_ID) || RUN_ID == basename(CANON_RUN)) {
  stop("R3_RUN_ID must start with 'r3_' and must not be the canonical run.")
}
DIRS <- list(
  models = file.path(RUN_DIR, "models"),
  loo = file.path(RUN_DIR, "loo"),
  tables = file.path(RUN_DIR, "tables"),
  logs = file.path(RUN_DIR, "logs")
)
for (d in DIRS) dir.create(d, recursive = TRUE, showWarnings = FALSE)
writeLines(RUN_ID, file.path(OUT_ROOT, if (SMOKE) "r3_smoke_latest_run_id.txt" else "r3_latest_run_id.txt"))

STAGES <- strsplit(Sys.getenv("R3_STAGES", "fit,loo,compare,sens,summary"), ",")[[1]]
STAGES <- trimws(STAGES)

N_CORES <- as.integer(Sys.getenv("R3_CORES", as.character(parallel::detectCores())))
SAMPLER <- if (SMOKE) {
  list(chains = 2L, iter = 60L, warmup = 30L)
} else {
  list(chains = 8L, iter = 3000L, warmup = 1500L)
}
SAMPLER$adapt_delta <- 0.95
SAMPLER$max_treedepth <- 12L
SAMPLER$seed <- 2026L
CHAIN_CORES <- max(1L, min(SAMPLER$chains, N_CORES))
THREADS <- as.integer(Sys.getenv(
  "R3_THREADS",
  as.character(max(1L, N_CORES %/% SAMPLER$chains))
))
LOO_CORES <- as.integer(Sys.getenv("R3_LOO_CORES", as.character(N_CORES)))
DO_RELOO <- Sys.getenv("R3_RELOO", "1") == "1" && !SMOKE
RELOO_MAX <- as.integer(Sys.getenv("R3_RELOO_MAX", "5"))
RHAT_MAX <- as.numeric(Sys.getenv("R3_RHAT_MAX", "1.01"))
ESS_MIN <- as.numeric(Sys.getenv("R3_ESS_MIN", "400"))
options(mc.cores = LOO_CORES)

N_EXPECTED <- c("0.15" = 17981L, "0.20" = 17857L, "0.25" = 17720L)
PROBE_ONSET_OFFSET <- 0.35

LOG_FILE <- file.path(DIRS$logs, "r3_master.log")
STATUS_FILE <- file.path(DIRS$logs, "r3_status.txt")

log_msg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = LOG_FILE, append = TRUE)
}
status <- function(stage, msg) {
  line <- sprintf("%s | %-8s | %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), stage, msg)
  cat(line, "\n", file = STATUS_FILE, append = TRUE)
  log_msg(stage, "-", msg)
}

log_msg("==== R3 refit start ====")
log_msg("Project:", ROOT, "| run:", RUN_DIR, "| smoke:", SMOKE)
log_msg("Stages:", paste(STAGES, collapse = ","))
log_msg("Sampler: chains", SAMPLER$chains, "iter", SAMPLER$iter, "warmup", SAMPLER$warmup,
        "| chain cores", CHAIN_CORES, "| threads/chain", THREADS, "| loo cores", LOO_CORES)

# ---- helpers ---------------------------------------------------------------

table_path <- function(name) file.path(DIRS$tables, name)
write_tbl <- function(df, name) {
  readr::write_csv(df, table_path(name), na = "NA")
  invisible(df)
}
read_tbl <- function(name) {
  p <- table_path(name)
  if (!file.exists(p)) return(NULL)
  readr::read_csv(p, show_col_types = FALSE)
}

md5_expected <- function(fname) {
  if (!file.exists(MD5_FILE)) return(NA_character_)
  lines <- readLines(MD5_FILE, warn = FALSE)
  hit <- lines[grepl(paste0("\\s", fname, "$"), lines)]
  if (!length(hit)) return(NA_character_)
  strsplit(trimws(hit[[1]]), "\\s+")[[1]][[1]]
}

check_md5 <- function(path) {
  expected <- md5_expected(basename(path))
  actual <- unname(tools::md5sum(path))
  ok <- is.na(expected) || identical(actual, expected)
  log_msg("md5", basename(path), actual, if (is.na(expected)) "(no expected value)" else if (ok) "OK" else paste("EXPECTED", expected))
  if (!ok && Sys.getenv("R3_ALLOW_MD5_MISMATCH", "0") != "1") {
    stop("md5 mismatch for ", path, ". Set R3_ALLOW_MD5_MISMATCH=1 only if this is intentional.")
  }
  list(path = path, md5 = actual, expected = expected, ok = ok)
}

strip_terms <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  attr(df, "terms") <- NULL
  attr(df, "drop_unused_levels") <- NULL
  attr(df, "data_name") <- NULL
  df
}

add_design_cols <- function(df) {
  df$difficulty_3 <- factor(as.character(df$difficulty_3), levels = c("Standard", "Hard", "Easy"))
  df$effort_condition <- factor(tolower(as.character(df$effort_condition)), levels = c("low", "high"))
  df$task <- factor(as.character(df$task), levels = c("ADT", "VDT"))
  if ("subject_id" %in% names(df)) df$subject_id <- as.character(df$subject_id)
  if ("choice_binary" %in% names(df)) df$choice_binary <- as.integer(df$choice_binary)
  df$stim_sign <- ifelse(df$difficulty_3 %in% c("Hard", "Easy"), 1, -1)
  df$effort_x_stim <- as.numeric(df$effort_condition == "high") * df$stim_sign
  df
}

# Same mapping as scripts/fit_sensitivity_additive_thresholds.R.
standardize_source <- function(raw) {
  out <- raw
  out$rt_cue <- as.numeric(out$rt)
  out$rt_probe_onset <- if ("rt_probe_onset_locked" %in% names(out)) {
    as.numeric(out$rt_probe_onset_locked)
  } else {
    out$rt_cue + PROBE_ONSET_OFFSET
  }
  if (!"choice_binary" %in% names(out) && "resp_is_diff" %in% names(out)) {
    out$choice_binary <- as.integer(out$resp_is_diff)
  }
  dl <- as.character(out$difficulty_level)
  out$difficulty_3 <- case_when(
    grepl("standard|baseline|^0$", dl, ignore.case = TRUE) ~ "Standard",
    grepl("easy|^3$|^4$", dl, ignore.case = TRUE) ~ "Easy",
    grepl("hard|^1$|^2$", dl, ignore.case = TRUE) ~ "Hard",
    TRUE ~ NA_character_
  )
  tk <- tolower(as.character(out$task))
  out$task <- case_when(
    grepl("^a|aud", tk) ~ "ADT",
    grepl("^v|vis", tk) ~ "VDT",
    TRUE ~ NA_character_
  )
  ec <- tolower(as.character(out$effort_condition))
  out$effort_condition <- case_when(
    grepl("low|5_mvc|0\\.05", ec) ~ "low",
    grepl("high|40_mvc|0\\.4", ec) ~ "high",
    TRUE ~ NA_character_
  )
  out
}

# Cue-locked cutoff; the model RT is probe-onset-locked, as in the 0.20 pipeline.
build_cutoff_data <- function(src, thr) {
  src %>%
    filter(!is.na(rt_cue), rt_cue > 0, rt_cue <= 3.0, rt_cue >= thr) %>%
    filter(!is.na(rt_probe_onset), rt_probe_onset > 0, !is.na(task), !is.na(effort_condition)) %>%
    transmute(
      rt = rt_probe_onset,
      choice_binary = as.integer(choice_binary),
      effort_condition, difficulty_3, subject_id = as.character(subject_id), task
    ) %>%
    as.data.frame()
}

make_priors <- function(ndt_ub) {
  c(
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
}

FAMILY <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")
BIAS_F <- bias ~ task + effort_condition + (1 | subject_id)

FORMULAS <- list(
  M0 = bf(
    rt | dec(choice_binary) ~ difficulty_3 + (1 | subject_id),
    bs ~ difficulty_3 + (1 | subject_id),
    ndt ~ 1, BIAS_F
  ),
  M1 = bf(
    rt | dec(choice_binary) ~ difficulty_3 + effort_condition + (1 | subject_id),
    bs ~ difficulty_3 + effort_condition + (1 | subject_id),
    ndt ~ 1, BIAS_F
  ),
  M2 = bf(
    rt | dec(choice_binary) ~ difficulty_3 * effort_condition + (1 | subject_id),
    bs ~ difficulty_3 * effort_condition + (1 | subject_id),
    ndt ~ 1, BIAS_F
  ),
  # effort_x_stim = 1[high] * stim_sign. The literal effort_condition:stim_sign
  # term expands to low and high slopes whose sum is collinear with
  # Intercept + difficulty_3, so it is not identified.
  M3 = bf(
    rt | dec(choice_binary) ~ difficulty_3 + effort_condition + effort_x_stim + (1 | subject_id),
    bs ~ difficulty_3 + effort_condition + (1 | subject_id),
    ndt ~ 1, BIAS_F
  )
)
MODEL_LABELS <- c(
  M0 = "difficulty-only",
  M1 = "additive",
  M2 = "interaction",
  M3 = "criterion/quality"
)

ndt_bounds <- function(df) {
  ub_val <- min(df$rt) - 0.01
  if (!is.finite(ub_val) || ub_val <= 0.05) stop("Invalid ndt upper bound: ", ub_val)
  init_val <- if (log(0.50) < log(ub_val) - 0.005) 0.50 else 0.98 * ub_val
  list(ub_val = ub_val, ub = log(ub_val), init_val = init_val)
}

make_init <- function(formula, df, nb) {
  sdata <- brms::standata(formula, data = df, family = FAMILY, prior = make_priors(nb$ub))
  m_names <- grep("^M_[0-9]+$", names(sdata), value = TRUE)
  base <- list(
    Intercept = 0,
    Intercept_bs = log(2.2),
    Intercept_ndt = log(nb$init_val),
    Intercept_bias = 0
  )
  for (m in m_names) {
    k <- sub("^M_", "", m)
    base[[paste0("sd_", k)]] <- array(rep(0.1, sdata[[m]]), dim = sdata[[m]])
  }
  function(chain_id = 1) base
}

fit_one <- function(key, formula, df, out_file) {
  nb <- ndt_bounds(df)
  path <- file.path(DIRS$models, out_file)
  log_msg("Fit", key, "| N =", nrow(df), "| ndt ub =", round(nb$ub_val, 4),
          "| ndt init =", round(nb$init_val, 4), "|", basename(path))
  t0 <- Sys.time()
  fit <- brm(
    formula = formula,
    data = df,
    family = FAMILY,
    prior = make_priors(nb$ub),
    chains = SAMPLER$chains,
    iter = SAMPLER$iter,
    warmup = SAMPLER$warmup,
    cores = CHAIN_CORES,
    threads = if (THREADS > 1) threading(THREADS) else NULL,
    init = make_init(formula, df, nb),
    control = list(adapt_delta = SAMPLER$adapt_delta, max_treedepth = SAMPLER$max_treedepth),
    save_pars = save_pars(all = TRUE),
    backend = "cmdstanr",
    seed = SAMPLER$seed,
    file = path,
    file_refit = "on_change",
    refresh = if (SMOKE) 0 else 250,
    silent = if (SMOKE) 2 else 0
  )
  mins <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  list(fit = fit, path = path, minutes = mins, ndt = nb)
}

convergence_row <- function(fit, key, label, n_obs, minutes = NA_real_, ndt = NULL) {
  draws <- posterior::as_draws_array(fit)
  s <- posterior::summarise_draws(
    draws,
    rhat = posterior::rhat,
    ess_bulk = posterior::ess_bulk,
    ess_tail = posterior::ess_tail
  )
  b <- s[grepl("^b_", s$variable), , drop = FALSE]
  np <- brms::nuts_params(fit)
  div <- sum(np$Parameter == "divergent__" & np$Value > 0)
  tdh <- sum(np$Parameter == "treedepth__" & np$Value >= SAMPLER$max_treedepth)
  argmin <- function(df, col) df$variable[which.min(df[[col]])]
  tibble(
    model = key,
    label = label,
    n_obs = n_obs,
    chains = SAMPLER$chains,
    iter = SAMPLER$iter,
    warmup = SAMPLER$warmup,
    n_variables = nrow(s),
    max_rhat_all = max(s$rhat, na.rm = TRUE),
    max_rhat_all_var = s$variable[which.max(s$rhat)],
    min_bulk_ess_all = min(s$ess_bulk, na.rm = TRUE),
    min_bulk_ess_all_var = argmin(s, "ess_bulk"),
    min_tail_ess_all = min(s$ess_tail, na.rm = TRUE),
    min_tail_ess_all_var = argmin(s, "ess_tail"),
    n_b = nrow(b),
    max_rhat_b = max(b$rhat, na.rm = TRUE),
    min_bulk_ess_b = min(b$ess_bulk, na.rm = TRUE),
    min_bulk_ess_b_var = argmin(b, "ess_bulk"),
    min_tail_ess_b = min(b$ess_tail, na.rm = TRUE),
    min_tail_ess_b_var = argmin(b, "ess_tail"),
    divergences = div,
    treedepth_hits = tdh,
    ndt_ub = if (is.null(ndt)) NA_real_ else ndt$ub_val,
    ndt_init = if (is.null(ndt)) NA_real_ else ndt$init_val,
    fit_minutes = minutes
  )
}

passes_convergence <- function(row) {
  isTRUE(row$max_rhat_all <= RHAT_MAX) &&
    isTRUE(row$min_bulk_ess_all >= ESS_MIN) &&
    isTRUE(row$min_tail_ess_all >= ESS_MIN) &&
    isTRUE(row$divergences == 0)
}

fixef_tbl <- function(fit, key) {
  fx <- brms::fixef(fit)
  tibble(
    model = key, term = rownames(fx),
    Estimate = fx[, "Estimate"], Est.Error = fx[, "Est.Error"],
    Q2.5 = fx[, "Q2.5"], Q97.5 = fx[, "Q97.5"]
  )
}

summ_draws <- function(x) {
  c(
    median = stats::median(x),
    q2.5 = unname(stats::quantile(x, 0.025)),
    q97.5 = unname(stats::quantile(x, 0.975)),
    p_gt_0 = mean(x > 0)
  )
}

ndt_tbl <- function(fit, key) {
  x <- exp(posterior::as_draws_df(fit, variable = "Intercept_ndt")$Intercept_ndt)
  s <- summ_draws(x)
  tibble(model = key, parameter = "exp(Intercept_ndt)",
         median = s[["median"]], q2.5 = s[["q2.5"]], q97.5 = s[["q97.5"]])
}

effort_contrasts <- function(fit, key) {
  grid <- expand.grid(
    difficulty_3 = c("Standard", "Hard", "Easy"),
    effort_condition = c("low", "high"),
    stringsAsFactors = FALSE
  )
  grid$task <- "ADT"
  grid$rt <- 1
  grid$choice_binary <- 0L
  grid <- add_design_cols(grid)
  rows <- list()
  fx_names <- rownames(brms::fixef(fit))
  has_v_effort <- any(grepl("^effort_condition|^effort_x_stim", fx_names))
  has_bs_effort <- any(grepl("^bs_effort_condition", fx_names))

  lp_mu <- brms::posterior_linpred(fit, newdata = grid, re_formula = NA, dpar = "mu")
  lp_bs <- brms::posterior_linpred(fit, newdata = grid, re_formula = NA, dpar = "bs", transform = FALSE)
  for (dl in c("Standard", "Hard", "Easy")) {
    lo <- which(grid$difficulty_3 == dl & grid$effort_condition == "low")
    hi <- which(grid$difficulty_3 == dl & grid$effort_condition == "high")
    sgn <- grid$stim_sign[lo]
    if (has_v_effort) {
      dv <- lp_mu[, hi] - lp_mu[, lo]
      s <- summ_draws(dv)
      rows[[length(rows) + 1]] <- tibble(model = key, contrast = "drift v: high - low", difficulty_3 = dl,
                                         scale = "identity", !!!as.list(s))
      s <- summ_draws(sgn * dv)
      rows[[length(rows) + 1]] <- tibble(model = key, contrast = "drift toward correct boundary: stim_sign x (high - low)",
                                         difficulty_3 = dl, scale = "identity", !!!as.list(s))
    }
    if (has_bs_effort) {
      da <- lp_bs[, hi] - lp_bs[, lo]
      s <- summ_draws(da)
      rows[[length(rows) + 1]] <- tibble(model = key, contrast = "boundary a: log(high) - log(low)", difficulty_3 = dl,
                                         scale = "log", !!!as.list(s))
      s <- summ_draws(exp(da))
      rows[[length(rows) + 1]] <- tibble(model = key, contrast = "boundary a: high / low", difficulty_3 = dl,
                                         scale = "ratio", !!!as.list(s))
      rows[[length(rows)]]$p_gt_0 <- mean(exp(da) > 1)
    }
  }
  dr <- posterior::as_draws_df(fit)
  par_rows <- list(
    c("b_effort_conditionhigh", "drift: effort_conditionhigh (M3: criterion shift toward 'different')"),
    c("b_effort_x_stim", "drift: effort_x_stim = 1[high] x stim_sign (M3: evidence-quality change)"),
    c("b_bs_effort_conditionhigh", "boundary (log): bs_effort_conditionhigh"),
    c("b_bias_effort_conditionhigh", "bias (logit): bias_effort_conditionhigh")
  )
  for (pr in par_rows) {
    if (pr[[1]] %in% names(dr)) {
      s <- summ_draws(dr[[pr[[1]]]])
      rows[[length(rows) + 1]] <- tibble(model = key, contrast = pr[[2]], difficulty_3 = "all",
                                         scale = "link", !!!as.list(s))
    }
  }
  bind_rows(rows)
}

pareto_bins <- function(k) {
  k <- as.numeric(k)
  c(k_le_0.5 = sum(k <= 0.5, na.rm = TRUE),
    k_0.5_0.7 = sum(k > 0.5 & k <= 0.7, na.rm = TRUE),
    k_0.7_1 = sum(k > 0.7 & k <= 1, na.rm = TRUE),
    k_gt_1 = sum(k > 1, na.rm = TRUE))
}

strip_loo <- function(obj) {
  obj$psis_object <- NULL
  obj
}

# ---- data ------------------------------------------------------------------

status("data", "loading canonical 0.20 data")
# Prefer the packed copy. It is the 17,857-row 0.20 s fit. The same path
# already on the VM is a different object (18,097 unthresholded rows).
canon_path <- if (file.exists(BUNDLED_RDS)) BUNDLED_RDS else CANON_RDS
if (!file.exists(canon_path)) stop("Canonical additive rds not found at ", BUNDLED_RDS, " or ", CANON_RDS)
log_msg("0.20 data file:", canon_path)
canon_md5 <- check_md5(canon_path)
canon <- strip_terms(readRDS(canon_path)$data)
stopifnot(nrow(canon) == 17857L)
dat <- add_design_cols(canon)
stopifnot(
  nrow(dat) == 17857L,
  identical(dat$rt, as.numeric(canon$rt)),
  identical(dat$choice_binary, as.integer(canon$choice_binary)),
  !anyNA(dat$difficulty_3), !anyNA(dat$effort_condition), !anyNA(dat$task)
)
log_msg("Canonical data: N =", nrow(dat), "| subjects =", n_distinct(dat$subject_id),
        "| min rt =", min(dat$rt))

src_csv <- SOURCE_CSV_CANDIDATES[file.exists(SOURCE_CSV_CANDIDATES)][1]
if (is.na(src_csv)) stop("Source CSV not found: ", paste(SOURCE_CSV_CANDIDATES, collapse = ", "))
src_md5 <- check_md5(src_csv)
src <- standardize_source(readr::read_csv(src_csv, show_col_types = FALSE))

cutoff_data <- list()
cutoff_rows <- list()
for (thr in names(N_EXPECTED)) {
  d <- build_cutoff_data(src, as.numeric(thr))
  cutoff_data[[thr]] <- add_design_cols(d)
  same <- if (thr == "0.20") {
    identical(d$rt, dat$rt) && identical(d$choice_binary, dat$choice_binary) &&
      identical(d$subject_id, dat$subject_id) &&
      identical(as.character(d$difficulty_3), as.character(dat$difficulty_3)) &&
      identical(as.character(d$effort_condition), as.character(dat$effort_condition)) &&
      identical(as.character(d$task), as.character(dat$task))
  } else NA
  cutoff_rows[[thr]] <- tibble(
    cue_locked_cutoff_s = as.numeric(thr),
    n_rows = nrow(d),
    n_expected = N_EXPECTED[[thr]],
    n_matches = nrow(d) == N_EXPECTED[[thr]],
    min_rt_probe_onset = min(d$rt),
    ndt_upper_bound = min(d$rt) - 0.01,
    identical_to_canonical_0.20 = same
  )
}
cutoff_tbl <- bind_rows(cutoff_rows)
write_tbl(cutoff_tbl, "data_cutoffs.csv")
if (!all(cutoff_tbl$n_matches)) stop("Cutoff row counts differ from expected; see data_cutoffs.csv")
if (!isTRUE(cutoff_tbl$identical_to_canonical_0.20[cutoff_tbl$cue_locked_cutoff_s == 0.20])) {
  stop("Rebuilt 0.20 data is not identical to the canonical fit$data; the sensitivity data would not share the pipeline.")
}
cutoff_data[["0.20"]] <- NULL

if (SMOKE) {
  keep <- head(sort(unique(dat$subject_id)), 6)
  dat <- dat[dat$subject_id %in% keep, , drop = FALSE]
  for (thr in names(cutoff_data)) {
    cutoff_data[[thr]] <- cutoff_data[[thr]][cutoff_data[[thr]]$subject_id %in% keep, , drop = FALSE]
  }
  log_msg("SMOKE: subset to", length(keep), "subjects, N =", nrow(dat))
}

# Literal M3 term rank check, recorded for the summary.
X_lit <- model.matrix(~ difficulty_3 + effort_condition + effort_condition:stim_sign, data = dat)
X_fix <- model.matrix(~ difficulty_3 + effort_condition + effort_x_stim, data = dat)
ident_tbl <- tibble(
  design = c("literal: difficulty_3 + effort_condition + effort_condition:stim_sign",
             "used: difficulty_3 + effort_condition + effort_x_stim"),
  columns = c(paste(colnames(X_lit), collapse = "; "), paste(colnames(X_fix), collapse = "; ")),
  n_columns = c(ncol(X_lit), ncol(X_fix)),
  rank = c(qr(X_lit)$rank, qr(X_fix)$rank)
)
write_tbl(ident_tbl, "m3_identifiability.csv")

# ---- environment -----------------------------------------------------------

dpar_check <- function(dp) {
  res <- tryCatch({
    f2 <- bf(as.formula("rt | dec(choice_binary) ~ 1"), as.formula(paste(dp, "~ 1")))
    brms::stancode(f2, data = dat[seq_len(min(50, nrow(dat))), ], family = wiener())
    "accepted"
  }, error = function(e) paste("rejected:", gsub("\\s+", " ", conditionMessage(e))))
  tibble(dpar = dp, result = substr(res, 1, 160))
}
env_tbl <- tibble(
  item = c("R", "brms", "cmdstanr", "CmdStan", "posterior", "loo", "rstan (needed by moment matching)",
           "wiener dpars in this brms", "cores", "chains", "threads per chain", "loo cores",
           "canonical rds md5", "source csv", "source csv md5"),
  value = c(
    paste(R.version$major, R.version$minor, sep = "."),
    as.character(packageVersion("brms")),
    as.character(packageVersion("cmdstanr")),
    tryCatch(as.character(cmdstanr::cmdstan_version()), error = function(e) "unavailable"),
    as.character(packageVersion("posterior")),
    as.character(packageVersion("loo")),
    if (requireNamespace("rstan", quietly = TRUE)) as.character(packageVersion("rstan")) else "NOT INSTALLED",
    paste(wiener()$dpars, collapse = ", "),
    N_CORES, SAMPLER$chains, THREADS, LOO_CORES,
    canon_md5$md5, src_csv, src_md5$md5
  )
)
write_tbl(env_tbl, "environment.csv")
write_tbl(bind_rows(lapply(c("sv", "sw", "sndt", "sz", "st0"), dpar_check)), "wiener_dpar_check.csv")

# ---- stage: fit M0-M3 ------------------------------------------------------

fits <- list()
fit_info <- list()
model_file <- function(key) sprintf("%s__probe_onset_locked__thr0.20.rds", key)

load_or_fit <- function(key) {
  res <- fit_one(key, FORMULAS[[key]], dat, model_file(key))
  fits[[key]] <<- res$fit
  fit_info[[key]] <<- res
  stopifnot(nrow(res$fit$data) == nrow(dat))
  res
}

if ("fit" %in% STAGES || "loo" %in% STAGES || "compare" %in% STAGES || "sens" %in% STAGES) {
  for (key in names(FORMULAS)) {
    status("fit", paste("start", key))
    res <- tryCatch(load_or_fit(key), error = function(e) {
      status("fit", paste("FAILED", key, conditionMessage(e)))
      NULL
    })
    if (!is.null(res)) status("fit", sprintf("done %s in %.1f min", key, res$minutes))
  }
  conv <- bind_rows(lapply(names(fits), function(k) {
    convergence_row(fits[[k]], k, MODEL_LABELS[[k]], nrow(fits[[k]]$data),
                    fit_info[[k]]$minutes, fit_info[[k]]$ndt)
  }))
  write_tbl(conv, "convergence_models.csv")
  write_tbl(bind_rows(lapply(names(fits), function(k) fixef_tbl(fits[[k]], k))), "fixef_models.csv")
  write_tbl(bind_rows(lapply(names(fits), function(k) ndt_tbl(fits[[k]], k))), "ndt_models.csv")
  write_tbl(bind_rows(lapply(names(fits), function(k) effort_contrasts(fits[[k]], k))), "effort_contrasts_models.csv")
  status("fit", "tables written")
}

# ---- stage: LOO ------------------------------------------------------------

loo_path <- function(key) file.path(DIRS$loo, sprintf("loo_%s.rds", key))

run_loo <- function(key) {
  fit <- fits[[key]]
  path <- loo_path(key)
  if (file.exists(path)) {
    log_msg("LOO exists, reusing", path)
    return(NULL)
  }
  row <- list(model = key, mm_status = NA_character_, reloo_status = "not needed")
  t0 <- Sys.time()
  obj0 <- brms::loo(fit, cores = LOO_CORES)
  b0 <- pareto_bins(obj0$diagnostics$pareto_k)
  row$elpd_psis <- obj0$estimates["elpd_loo", "Estimate"]
  row$k_gt_0.7_psis <- b0[["k_0.7_1"]] + b0[["k_gt_1"]]
  obj <- obj0
  if (row$k_gt_0.7_psis > 0) {
    obj <- tryCatch({
      # Same result as loo(fit, moment_match = TRUE) without recomputing log_lik.
      out <- brms::loo_moment_match(fit, loo = obj0, k_threshold = 0.7, cores = LOO_CORES)
      row$mm_status <- "ok"
      out
    }, error = function(e) {
      row$mm_status <<- paste("failed:", gsub("\\s+", " ", conditionMessage(e)))
      obj0
    })
  } else {
    row$mm_status <- "not needed (no k > 0.7)"
  }
  b1 <- pareto_bins(obj$diagnostics$pareto_k)
  row$k_gt_0.7_after_mm <- b1[["k_0.7_1"]] + b1[["k_gt_1"]]
  if (row$k_gt_0.7_after_mm > 0) {
    if (!DO_RELOO) {
      row$reloo_status <- "skipped (R3_RELOO=0 or smoke)"
    } else if (row$k_gt_0.7_after_mm > RELOO_MAX) {
      row$reloo_status <- sprintf("skipped (%d points > R3_RELOO_MAX=%d)", row$k_gt_0.7_after_mm, RELOO_MAX)
    } else {
      status("loo", sprintf("%s reloo on %d points", key, row$k_gt_0.7_after_mm))
      obj <- tryCatch({
        out <- brms::reloo(fit, loo = obj, k_threshold = 0.7, check = FALSE)
        row$reloo_status <- sprintf("ok (%d points refit)", row$k_gt_0.7_after_mm)
        out
      }, error = function(e) {
        row$reloo_status <<- paste("failed:", gsub("\\s+", " ", conditionMessage(e)))
        obj
      })
    }
  }
  b2 <- pareto_bins(obj$diagnostics$pareto_k)
  row$elpd_loo <- obj$estimates["elpd_loo", "Estimate"]
  row$se_elpd_loo <- obj$estimates["elpd_loo", "SE"]
  row$p_loo <- obj$estimates["p_loo", "Estimate"]
  row$looic <- obj$estimates["looic", "Estimate"]
  row$n_pointwise <- nrow(obj$pointwise)
  row <- c(row, as.list(b2))
  row$loo_minutes <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  saveRDS(strip_loo(obj), path)
  write_csv(as_tibble(row), file.path(DIRS$loo, sprintf("loo_%s_status.csv", key)))
  rm(obj0, obj)
  gc(verbose = FALSE)
  NULL
}

if ("loo" %in% STAGES) {
  for (key in names(fits)) {
    status("loo", paste("start", key))
    tryCatch(run_loo(key), error = function(e) status("loo", paste("FAILED", key, conditionMessage(e))))
    status("loo", paste("done", key))
  }
  st <- list.files(DIRS$loo, pattern = "^loo_M[0-9]_status\\.csv$", full.names = TRUE)
  if (length(st)) write_tbl(bind_rows(lapply(st, read_csv, show_col_types = FALSE)), "loo_models.csv")
}

# ---- stage: compare and pointwise forensics --------------------------------

forensics <- function(a, b, la, lb) {
  ea <- a$pointwise[, "elpd_loo"]
  eb <- b$pointwise[, "elpd_loo"]
  stopifnot(length(ea) == nrow(dat), length(eb) == nrow(dat))
  pw <- dat %>%
    mutate(trial_index = row_number(), elpd_a = ea, elpd_b = eb, elpd_diff = ea - eb,
           k_a = a$diagnostics$pareto_k, k_b = b$diagnostics$pareto_k)
  tot <- sum(pw$elpd_diff)
  tot_abs <- sum(abs(pw$elpd_diff))
  name <- paste0(la, "_minus_", lb)
  by_cond <- pw %>%
    group_by(difficulty_3, effort_condition, task) %>%
    summarise(n_trials = n(), sum_elpd_diff = sum(elpd_diff), mean_elpd_diff = mean(elpd_diff),
              sum_abs_elpd_diff = sum(abs(elpd_diff)), .groups = "drop") %>%
    mutate(share_of_signed_total = sum_elpd_diff / tot, share_of_abs_total = sum_abs_elpd_diff / tot_abs) %>%
    arrange(task, effort_condition, difficulty_3)
  pw$rt_decile <- dplyr::ntile(pw$rt, 10)
  by_dec <- pw %>%
    group_by(rt_decile) %>%
    summarise(n_trials = n(), rt_min = min(rt), rt_max = max(rt), sum_elpd_diff = sum(elpd_diff),
              mean_elpd_diff = mean(elpd_diff), sum_abs_elpd_diff = sum(abs(elpd_diff)), .groups = "drop") %>%
    mutate(share_of_signed_total = sum_elpd_diff / tot, share_of_abs_total = sum_abs_elpd_diff / tot_abs)
  ord <- order(-abs(pw$elpd_diff))
  shares <- bind_rows(lapply(c(20L, 50L, 100L), function(k) {
    idx <- ord[seq_len(min(k, length(ord)))]
    tibble(n_trials = k, sum_elpd_diff = sum(pw$elpd_diff[idx]),
           share_of_signed_total = sum(pw$elpd_diff[idx]) / tot,
           share_of_abs_total = sum(abs(pw$elpd_diff[idx])) / tot_abs)
  }))
  top <- pw[ord[seq_len(min(20, length(ord)))], c("trial_index", "subject_id", "task", "effort_condition",
                                                    "difficulty_3", "rt", "choice_binary", "elpd_diff", "k_a", "k_b")]
  names(top)[names(top) == "k_a"] <- paste0("pareto_k_", la)
  names(top)[names(top) == "k_b"] <- paste0("pareto_k_", lb)
  write_tbl(by_cond, sprintf("forensics_%s_by_condition.csv", name))
  write_tbl(by_dec, sprintf("forensics_%s_by_rt_decile.csv", name))
  write_tbl(shares, sprintf("forensics_%s_top_share.csv", name))
  write_tbl(top, sprintf("forensics_%s_top20.csv", name))
  tibble(contrast = name, n_trials = nrow(pw), sum_elpd_diff = tot, sum_abs_elpd_diff = tot_abs)
}

if ("compare" %in% STAGES) {
  status("compare", "start")
  keys <- names(FORMULAS)[file.exists(vapply(names(FORMULAS), loo_path, character(1)))]
  loos <- setNames(lapply(keys, function(k) readRDS(loo_path(k))), keys)
  if (length(loos) >= 2) {
    cmp <- loo::loo_compare(loos)
    cmp_df <- as.data.frame(cmp)
    cmp_df <- tibble(model = rownames(cmp_df), !!!cmp_df)
    write_tbl(cmp_df, "loo_compare.csv")
  }
  tot <- list()
  if (all(c("M2", "M1") %in% keys)) tot[[1]] <- forensics(loos$M2, loos$M1, "M2", "M1")
  if (all(c("M1", "M0") %in% keys)) tot[[2]] <- forensics(loos$M1, loos$M0, "M1", "M0")
  if (length(tot)) write_tbl(bind_rows(tot), "forensics_totals.csv")
  status("compare", "done")
}

# ---- stage: sensitivity ----------------------------------------------------

if ("sens" %in% STAGES) {
  conv <- read_tbl("convergence_models.csv")
  primary <- "M1"
  reason <- "M3 missing"
  if (!is.null(conv) && "M3" %in% conv$model) {
    if (passes_convergence(conv[conv$model == "M3", ])) {
      primary <- "M3"
      reason <- sprintf("M3 passed (max Rhat <= %.2f, bulk and tail ESS >= %.0f, 0 divergences)", RHAT_MAX, ESS_MIN)
    } else {
      reason <- "M3 failed the convergence rule; falling back to M1"
    }
  }
  write_tbl(tibble(primary_model = primary, label = MODEL_LABELS[[primary]], reason = reason), "sensitivity_selection.csv")
  status("sens", paste("primary =", primary, "|", reason))
  sens_conv <- list()
  sens_eff <- list()
  for (thr in names(cutoff_data)) {
    key <- paste0(primary, "_thr", thr)
    status("sens", paste("start", key))
    res <- tryCatch(
      fit_one(key, FORMULAS[[primary]], cutoff_data[[thr]],
              sprintf("sens_%s__probe_onset_locked__thr%s.rds", primary, thr)),
      error = function(e) { status("sens", paste("FAILED", key, conditionMessage(e))); NULL }
    )
    if (is.null(res)) next
    row <- convergence_row(res$fit, key, MODEL_LABELS[[primary]], nrow(res$fit$data), res$minutes, res$ndt)
    row$cue_locked_cutoff_s <- as.numeric(thr)
    sens_conv[[thr]] <- row
    eff <- effort_contrasts(res$fit, key)
    eff$cue_locked_cutoff_s <- as.numeric(thr)
    sens_eff[[thr]] <- eff
    status("sens", sprintf("done %s in %.1f min", key, res$minutes))
  }
  if (primary %in% names(fits)) {
    row <- read_tbl("convergence_models.csv") %>% filter(model == primary)
    row$cue_locked_cutoff_s <- 0.20
    eff <- read_tbl("effort_contrasts_models.csv") %>% filter(model == primary)
    eff$cue_locked_cutoff_s <- 0.20
    sens_conv[["0.20"]] <- row
    sens_eff[["0.20"]] <- eff
  }
  if (length(sens_conv)) {
    write_tbl(bind_rows(sens_conv) %>% arrange(cue_locked_cutoff_s), "sensitivity_convergence.csv")
    write_tbl(bind_rows(sens_eff) %>% arrange(cue_locked_cutoff_s), "sensitivity_effort_contrasts.csv")
  }
}

# ---- stage: summary markdown -----------------------------------------------

md_cell <- function(x) {
  if (is.numeric(x)) {
    out <- vapply(x, function(v) {
      if (is.na(v)) return("")
      if (abs(v - round(v)) < 1e-9 && abs(v) < 1e9) return(format(round(v), big.mark = "", scientific = FALSE))
      formatC(v, format = "f", digits = if (abs(v) >= 100) 1 else 4)
    }, character(1))
  } else {
    out <- ifelse(is.na(x), "", as.character(x))
  }
  gsub("|", "\\|", out, fixed = TRUE)
}
md_table <- function(df) {
  if (is.null(df) || !nrow(df)) return("_(not available)_")
  df <- as.data.frame(df)
  cells <- lapply(df, md_cell)
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |"),
    vapply(seq_len(nrow(df)), function(i) paste0("| ", paste(vapply(cells, `[[`, "", i), collapse = " | "), " |"), ""))
}
section <- function(title, df, note = NULL) c(paste("##", title), "", md_table(df), "", if (!is.null(note)) c(note, ""))

fmt <- function(x, d = 2) {
  if (length(x) == 0) return("NA")
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x), "NA", formatC(x, format = "f", digits = d))
}

build_summary <- function() {
  conv <- read_tbl("convergence_models.csv")
  lm <- read_tbl("loo_models.csv")
  cmp <- read_tbl("loo_compare.csv")
  eff <- read_tbl("effort_contrasts_models.csv")
  sel <- read_tbl("sensitivity_selection.csv")
  sc <- read_tbl("sensitivity_convergence.csv")
  se <- read_tbl("sensitivity_effort_contrasts.csv")
  l <- character(5)

  if (!is.null(conv)) {
    pass <- vapply(seq_len(nrow(conv)), function(i) passes_convergence(conv[i, ]), logical(1))
    l[1] <- sprintf(
      "Convergence (%d chains x %d post-warmup draws, N = %s): %s. Rule: max Rhat <= %.2f and min bulk/tail ESS >= %.0f over all parameters, 0 divergences.",
      SAMPLER$chains, SAMPLER$iter - SAMPLER$warmup, paste(unique(conv$n_obs), collapse = "/"),
      paste(sprintf("%s %s (Rhat %s, bulk %s, tail %s, div %d)", conv$model, ifelse(pass, "PASS", "FAIL"),
                    fmt(conv$max_rhat_all, 3), fmt(conv$min_bulk_ess_all, 0), fmt(conv$min_tail_ess_all, 0),
                    as.integer(conv$divergences)), collapse = "; "),
      RHAT_MAX, ESS_MIN
    )
  } else l[1] <- "Convergence table not available."

  if (!is.null(cmp)) {
    l[2] <- paste0("loo_compare: ", paste(sprintf("%s %s (SE %s)", cmp$model, fmt(cmp$elpd_diff, 1), fmt(cmp$se_diff, 1)), collapse = "; "),
                   if (!is.null(lm)) paste0(". Remaining Pareto-k > 0.7 after moment matching/reloo: ",
                                            paste(sprintf("%s %d", lm$model, as.integer(lm$k_0.7_1 + lm$k_gt_1)), collapse = ", "), ".") else ".")
  } else l[2] <- "loo_compare not available."

  tots <- read_tbl("forensics_totals.csv")
  if (!is.null(tots)) {
    parts <- vapply(tots$contrast, function(nm) {
      dec <- read_tbl(sprintf("forensics_%s_by_rt_decile.csv", nm))
      d1 <- dec$share_of_signed_total[dec$rt_decile == 1]
      sh <- read_tbl(sprintf("forensics_%s_top_share.csv", nm))
      sprintf("%s total %s, fastest RT decile %s%% of the net, top 100 trials %s%% of |diff|",
              nm, fmt(tots$sum_elpd_diff[tots$contrast == nm], 1), fmt(100 * d1, 1),
              fmt(100 * sh$share_of_abs_total[sh$n_trials == 100], 1))
    }, character(1))
    l[3] <- paste0("Pointwise forensics: ", paste(parts, collapse = "; "), ".")
  } else l[3] <- "Pointwise forensics not available."

  if (!is.null(eff)) {
    pick <- function(m, pat) {
      r <- eff[eff$model == m & grepl(pat, eff$contrast, fixed = TRUE), ]
      if (!nrow(r)) return(NA_character_)
      sprintf("%s [%s, %s]", fmt(r$median[1], 3), fmt(r$q2.5[1], 3), fmt(r$q97.5[1], 3))
    }
    l[4] <- sprintf(
      "Effort: M1 drift %s, M1 log-boundary %s; M3 criterion shift %s, M3 evidence-quality change %s, M3 log-boundary %s (median [95%% CrI]).",
      pick("M1", "drift: effort_conditionhigh"), pick("M1", "boundary (log)"),
      pick("M3", "drift: effort_conditionhigh"), pick("M3", "drift: effort_x_stim"), pick("M3", "boundary (log)")
    )
  } else l[4] <- "Effort contrasts not available."

  if (!is.null(sel) && !is.null(sc)) {
    l[5] <- sprintf(
      "Sensitivity uses %s (%s). %s",
      sel$primary_model[1], sel$reason[1],
      paste(sprintf("Cutoff %.2f s: N %d, max Rhat %s, min bulk ESS %s, div %d",
                    sc$cue_locked_cutoff_s, as.integer(sc$n_obs), fmt(sc$max_rhat_all, 3),
                    fmt(sc$min_bulk_ess_all, 0), as.integer(sc$divergences)), collapse = "; ")
    )
  } else l[5] <- "Sensitivity not available."
  l
}

if ("summary" %in% STAGES) {
  status("summary", "writing r3_summary.md")
  tables <- list(
    c("Environment", "environment.csv"),
    c("wiener dpar check (sz/sv/st0 and brms names sv/sw/sndt)", "wiener_dpar_check.csv"),
    c("Data at each cue-locked cutoff", "data_cutoffs.csv"),
    c("M3 design identifiability", "m3_identifiability.csv"),
    c("Convergence: M0-M3", "convergence_models.csv"),
    c("Fixed effects: M0-M3", "fixef_models.csv"),
    c("exp(Intercept_ndt): M0-M3", "ndt_models.csv"),
    c("Effort contrasts: M0-M3", "effort_contrasts_models.csv"),
    c("LOO with moment matching and reloo", "loo_models.csv"),
    c("loo_compare", "loo_compare.csv"),
    c("Pointwise totals", "forensics_totals.csv"),
    c("M2 - M1 by difficulty x effort x task", "forensics_M2_minus_M1_by_condition.csv"),
    c("M2 - M1 by RT decile", "forensics_M2_minus_M1_by_rt_decile.csv"),
    c("M2 - M1 share from largest |diff| trials", "forensics_M2_minus_M1_top_share.csv"),
    c("M2 - M1 top 20 trials", "forensics_M2_minus_M1_top20.csv"),
    c("M1 - M0 by difficulty x effort x task", "forensics_M1_minus_M0_by_condition.csv"),
    c("M1 - M0 by RT decile", "forensics_M1_minus_M0_by_rt_decile.csv"),
    c("M1 - M0 share from largest |diff| trials", "forensics_M1_minus_M0_top_share.csv"),
    c("M1 - M0 top 20 trials", "forensics_M1_minus_M0_top20.csv"),
    c("Sensitivity model selection", "sensitivity_selection.csv"),
    c("Sensitivity convergence by cutoff", "sensitivity_convergence.csv"),
    c("Sensitivity effort contrasts by cutoff", "sensitivity_effort_contrasts.csv")
  )
  notes <- list(
    "m3_identifiability.csv" = "The literal effort_condition:stim_sign term is rank-deficient, so M3 uses effort_x_stim = 1[high] x stim_sign. In M3, b_effort_conditionhigh is the drift-criterion shift toward 'different' (upper boundary) for all trials. b_effort_x_stim is the evidence-quality change: drift moves toward the correct boundary on both Standard and Hard/Easy trials. M3 is nested in M2.",
    "data_cutoffs.csv" = "Cutoffs apply to cue-locked RT (rt_cue >= cutoff, <= 3.0 s). The modeled RT is probe-onset-locked (cue + 0.35 s), as in the canonical pipeline. The ndt upper bound is min(rt) - 0.01. When exp(Intercept_ndt) = 0.50 would violate that bound, ndt is initialized at 0.98 x the bound (convergence table column ndt_init).",
    "effort_contrasts_models.csv" = "Contrasts use population-level predictions (re_formula = NA). Drift contrasts are on the identity scale and boundary contrasts on the log scale and as a ratio. p_gt_0 is the posterior probability > 0 (for ratios, > 1).",
    "loo_models.csv" = "elpd_psis and k_gt_0.7_psis are plain PSIS-LOO results. Moment matching runs only when some k > 0.7. reloo runs only if k > 0.7 points remain and their count is <= R3_RELOO_MAX. Bin columns are the final counts."
  )
  md <- c(
    "# R3 behavioral refit summary", "",
    sprintf("Run: `%s`. Generated %s. Canonical run `%s` was read only.", RUN_DIR, format(Sys.time(), "%Y-%m-%d %H:%M %Z"), CANON_RUN),
    if (SMOKE) c("", "**SMOKE TEST: subset data and tiny sampler. Numbers are not interpretable.**") else NULL,
    "", "## Five-line summary", "", build_summary(), ""
  )
  for (t in tables) {
    df <- read_tbl(t[[2]])
    md <- c(md, section(t[[1]], df, notes[[t[[2]]]]))
  }
  writeLines(md, table_path("r3_summary.md"))
  status("summary", paste("wrote", table_path("r3_summary.md")))
}

status("done", paste("R3 finished; run dir", RUN_DIR))
