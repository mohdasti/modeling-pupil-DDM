# Refit the three behavioral models that miss max R-hat < 1.01.
# Does not start unless r10 has finished and its extract has been written.
# Does not write into r9 or r10. Does not add iterations if a model still fails.
#
#   cd ~/Feb2026
#   Rscript scripts/r11/refit_failing_behavioral.R
#
# Formulas, priors, data, init, and seed match the original fits.
# Sampler: 8 chains, 4500 iterations, 1500 warmup (twice the original
# post-warmup draws), adapt_delta 0.95, max_treedepth 12, seed 2026.

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
ROOT <- normalizePath(Sys.getenv("PROJECT_ROOT", getwd()), mustWork = TRUE)
setwd(ROOT)

r10_exported <- function() {
  id_file <- "output/ddm_refits/runs/r10_latest_run_id.txt"
  if (!file.exists(id_file)) {
    stop("r10 has not finished: missing ", id_file, call. = FALSE)
  }
  run_id <- trimws(readLines(id_file, n = 1L, warn = FALSE))
  if (!grepl("^r10_", run_id)) stop("r10 run id is not an r10 directory: ", run_id, call. = FALSE)
  run <- file.path("output/ddm_refits/runs", run_id)
  need <- c(
    file.path(run, "logs", "r8_status.txt"),
    file.path(run, "tables", "r8_slopes.csv"),
    file.path(run, "tables", "r8_effort_terms.csv")
  )
  missing <- need[!file.exists(need)]
  if (length(missing)) {
    stop("r10 has not been exported. Missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  status_txt <- paste(readLines(need[1], warn = FALSE), collapse = "\n")
  if (!grepl("pupil fit/loo finished", status_txt)) {
    stop("r10 status file does not say the pupil fit finished.", call. = FALSE)
  }
  run
}

r10_exported()

OUT_ROOT <- Sys.getenv("R11_OUT_ROOT", file.path("output", "ddm_refits", "runs"))
RUN_ID <- Sys.getenv("R11_RUN_ID", "")
if (!nzchar(RUN_ID)) RUN_ID <- paste0("r11_", format(Sys.time(), "%Y%m%d_%H%M%S"))
if (!grepl("^r11_", RUN_ID)) stop("R11_RUN_ID must start with 'r11_'.")
RUN_DIR <- file.path(OUT_ROOT, RUN_ID)
if (grepl("r9_|r10_|r8_20261017|r3_20261014|r7_20261016|final_20261016", RUN_DIR)) {
  stop("Refusing to write into an existing pupil or final run.")
}
DIRS <- list(
  models = file.path(RUN_DIR, "models"),
  loo = file.path(RUN_DIR, "loo"),
  tables = file.path(RUN_DIR, "tables"),
  logs = file.path(RUN_DIR, "logs")
)
for (d in DIRS) dir.create(d, recursive = TRUE, showWarnings = FALSE)
writeLines(RUN_ID, file.path(OUT_ROOT, "r11_latest_run_id.txt"))

FINAL <- "output/ddm_refits/runs/final_20261016"
TAB <- file.path(FINAL, "tables", "final")
N_CORES <- as.integer(Sys.getenv("R11_CORES", as.character(parallel::detectCores())))
SAMPLER <- list(chains = 8L, iter = 4500L, warmup = 1500L, adapt_delta = 0.95, max_treedepth = 12L, seed = 2026L)
CHAIN_CORES <- max(1L, min(SAMPLER$chains, N_CORES))
THREADS <- as.integer(Sys.getenv("R11_THREADS", as.character(max(1L, N_CORES %/% SAMPLER$chains))))
LOO_CORES <- as.integer(Sys.getenv("R11_LOO_CORES", "8"))
RELOO_MAX <- 5L
options(mc.cores = LOO_CORES)

LOG_FILE <- file.path(DIRS$logs, "r11_master.log")
STATUS_FILE <- file.path(DIRS$logs, "r11_status.txt")
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
write_tbl <- function(df, name) write_csv(df, file.path(DIRS$tables, name), na = "NA")

log_msg("==== R11 refit start ====")
log_msg("run:", RUN_DIR)
log_msg("Sampler: chains", SAMPLER$chains, "iter", SAMPLER$iter, "warmup", SAMPLER$warmup,
        "adapt_delta", SAMPLER$adapt_delta, "max_treedepth", SAMPLER$max_treedepth, "seed", SAMPLER$seed)

# ---- formulas, priors, init: identical to r3 (M1, M2) and r7 (M4_thr0.15) ----

FAMILY <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")
BIAS_F <- bias ~ task + effort_condition + (1 | subject_id)
FORMULAS <- list(
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
  M4_thr0.15 = bf(
    rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id),
    bs ~ difficulty_3 + task + effort_condition + (1 | subject_id),
    ndt ~ 1, BIAS_F
  )
)

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
    Intercept = 0, Intercept_bs = log(2.2),
    Intercept_ndt = log(nb$init_val), Intercept_bias = 0
  )
  for (m in m_names) {
    k <- sub("^M_", "", m)
    base[[paste0("sd_", k)]] <- array(rep(0.1, sdata[[m]]), dim = sdata[[m]])
  }
  function(chain_id = 1) base
}
add_design <- function(df) {
  df$difficulty_3 <- factor(as.character(df$difficulty_3), levels = c("Standard", "Hard", "Easy"))
  df$effort_condition <- factor(tolower(as.character(df$effort_condition)), levels = c("low", "high"))
  df$task <- factor(as.character(df$task), levels = c("ADT", "VDT"))
  df$subject_id <- as.character(df$subject_id)
  df$choice_binary <- as.integer(df$choice_binary)
  df$stim_sign <- ifelse(df$difficulty_3 %in% c("Hard", "Easy"), 1, -1)
  df$effort_x_stim <- as.numeric(df$effort_condition == "high") * df$stim_sign
  df
}

# ---- data, same objects as the original fits ----

status("data", "loading M1/M2 canonical 0.20 data")
canon_candidates <- c(
  "scripts/refit_r3/inputs/additive__probe_onset_locked__thr0.20.rds",
  "output/ddm_refits/runs/20260226_092110/models/additive__probe_onset_locked__thr0.20.rds"
)
canon_path <- canon_candidates[file.exists(canon_candidates)][1]
if (is.na(canon_path)) stop("Canonical additive rds not found.")
canon <- readRDS(canon_path)$data
attr(canon, "terms") <- NULL
dat20 <- add_design(canon)
if (nrow(dat20) != 17857L) stop("M1/M2 data has ", nrow(dat20), " rows, expected 17857.")

status("data", "loading M4_thr0.15")
thr_path <- "data/analysis_ready/r7/ddm_m4_cue_thr0.15.csv"
if (!file.exists(thr_path)) stop("Missing ", thr_path)
prepare15 <- function(df) {
  df$difficulty_3 <- factor(df$difficulty_3, levels = c("Standard", "Hard", "Easy"))
  df$effort_condition <- factor(df$effort_condition, levels = c("low", "high"))
  df$task <- factor(df$task, levels = c("ADT", "VDT"))
  df$subject_id <- as.character(df$subject_id)
  df$choice_binary <- as.integer(df$choice_binary)
  df$stim_sign <- ifelse(df$difficulty_3 %in% c("Hard", "Easy"), 1, -1)
  df$effort_x_stim <- as.numeric(df$effort_condition == "high") * df$stim_sign
  stopifnot(all(abs(df$rt - df$rt_cue - 0.35) < 1e-6), min(df$rt) > 0.45)
  df
}
thr_raw <- read_csv(thr_path, show_col_types = FALSE)
dat15 <- prepare15(thr_raw)
if (nrow(dat15) != 17981L) stop("M4_thr0.15 data has ", nrow(dat15), " rows, expected 17981.")
if (abs(min(dat15$rt_cue) - 0.15) > 0.01) stop("M4_thr0.15 minimum cue RT is not 0.15 s.")

DATA <- list(M1 = dat20, M2 = dat20, M4_thr0.15 = dat15)
model_file <- c(
  M1 = "M1__probe_onset_locked__thr0.20.rds",
  M2 = "M2__probe_onset_locked__thr0.20.rds",
  M4_thr0.15 = "M4__probe_onset_locked__thr0.15.rds"
)

fit_one <- function(key) {
  df <- DATA[[key]]
  nb <- ndt_bounds(df)
  path <- file.path(DIRS$models, model_file[[key]])
  t0 <- Sys.time()
  fit <- brm(
    formula = FORMULAS[[key]], data = df, family = FAMILY, prior = make_priors(nb$ub),
    chains = SAMPLER$chains, iter = SAMPLER$iter, warmup = SAMPLER$warmup,
    cores = CHAIN_CORES, threads = if (THREADS > 1) threading(THREADS) else NULL,
    init = make_init(FORMULAS[[key]], df, nb),
    control = list(adapt_delta = SAMPLER$adapt_delta, max_treedepth = SAMPLER$max_treedepth),
    save_pars = save_pars(all = TRUE), backend = "cmdstanr", seed = SAMPLER$seed,
    file = path, file_refit = "on_change", refresh = 250
  )
  list(fit = fit, minutes = as.numeric(difftime(Sys.time(), t0, units = "mins")), ndt = nb)
}

fits <- list()
minutes <- list()
for (key in names(DATA)) {
  status("fit", paste("start", key))
  res <- fit_one(key)
  fits[[key]] <- res$fit
  minutes[[key]] <- res$minutes
  status("fit", sprintf("done %s in %.1f min", key, res$minutes))
}

convergence_row <- function(fit, key) {
  draws <- posterior::as_draws_array(fit)
  s <- posterior::summarise_draws(draws, rhat = posterior::rhat, ess_bulk = posterior::ess_bulk, ess_tail = posterior::ess_tail)
  b <- s[grepl("^b_", s$variable), , drop = FALSE]
  np <- brms::nuts_params(fit)
  div <- sum(np$Parameter == "divergent__" & np$Value > 0)
  tdh <- sum(np$Parameter == "treedepth__" & np$Value >= SAMPLER$max_treedepth)
  tibble(
    model = key,
    chains = SAMPLER$chains, iter = SAMPLER$iter, warmup = SAMPLER$warmup,
    worst_param = s$variable[which.max(s$rhat)],
    max_rhat = max(s$rhat, na.rm = TRUE),
    max_rhat_b = max(b$rhat, na.rm = TRUE),
    min_bulk_ess = min(s$ess_bulk, na.rm = TRUE),
    min_bulk_ess_b = min(b$ess_bulk, na.rm = TRUE),
    min_tail_ess = min(s$ess_tail, na.rm = TRUE),
    min_tail_ess_b = min(b$ess_tail, na.rm = TRUE),
    divergences = div, treedepth_hits = tdh,
    minutes = minutes[[key]]
  )
}
conv <- bind_rows(lapply(names(fits), function(key) convergence_row(fits[[key]], key)))
conv$passes <- with(conv, max_rhat < 1.01 & min_bulk_ess >= 400 & min_tail_ess >= 400 & divergences == 0)
write_tbl(conv, "convergence.csv")

# ---- LOO for M1 and M2: moment matching, then reloo, as in r3/r7 ----

pareto_bins <- function(k) {
  k <- as.numeric(k)
  c(
    k_le_0.5 = sum(k <= 0.5, na.rm = TRUE),
    k_0.5_0.7 = sum(k > 0.5 & k <= 0.7, na.rm = TRUE),
    k_0.7_1 = sum(k > 0.7 & k <= 1, na.rm = TRUE),
    k_gt_1 = sum(k > 1, na.rm = TRUE)
  )
}
strip_loo <- function(obj) { obj$psis_object <- NULL; obj }
run_loo <- function(key) {
  path <- file.path(DIRS$loo, paste0("loo_", key, ".rds"))
  if (file.exists(path)) return(readRDS(path))
  status("loo", paste("start", key))
  fit <- fits[[key]]
  obj0 <- brms::loo(fit, cores = LOO_CORES)
  bad0 <- sum(obj0$diagnostics$pareto_k > 0.7, na.rm = TRUE)
  obj <- obj0
  if (bad0 > 0) {
    obj <- tryCatch(
      brms::loo_moment_match(fit, loo = obj0, k_threshold = 0.7, cores = LOO_CORES),
      error = function(e) {
        status("loo", paste(key, "moment match failed:", conditionMessage(e)))
        obj0
      }
    )
  }
  bad1 <- sum(obj$diagnostics$pareto_k > 0.7, na.rm = TRUE)
  if (bad1 > 0 && bad1 <= RELOO_MAX) {
    status("loo", sprintf("%s reloo on %d points", key, bad1))
    obj <- tryCatch(
      brms::reloo(fit, loo = obj, k_threshold = 0.7, check = FALSE),
      error = function(e) {
        status("loo", paste(key, "reloo failed:", conditionMessage(e)))
        obj
      }
    )
  } else if (bad1 > RELOO_MAX) {
    status("loo", sprintf("%s reloo skipped: %d points > %d", key, bad1, RELOO_MAX))
  }
  saveRDS(strip_loo(obj), path)
  bins <- pareto_bins(obj$diagnostics$pareto_k)
  write_tbl(tibble(model = key, !!!as.list(bins), elpd_loo = obj$estimates["elpd_loo", "Estimate"]), paste0("loo_", key, "_status.csv"))
  status("loo", paste("done", key))
  obj
}
loos_new <- list(M1 = run_loo("M1"), M2 = run_loo("M2"))

# ---- M0-M4b comparison, with stored LOO for the models that were not refit ----

load_stored_loo <- function(id) {
  path <- file.path(FINAL, "loo", paste0("loo_", id, ".rds"))
  if (!file.exists(path)) stop("Missing stored LOO: ", path)
  readRDS(path)
}
loos <- c(list(M0 = load_stored_loo("M0"), M3 = load_stored_loo("M3"), M4 = load_stored_loo("M4"), M4b = load_stored_loo("M4b")), loos_new)
cmp_ids <- c("M0", "M1", "M2", "M3", "M4", "M4b")
elpd_of <- function(obj) obj$estimates["elpd_loo", "Estimate"]
se_of <- function(obj) obj$estimates["elpd_loo", "SE"]
n_ref <- length(loos$M4$pointwise[, "elpd_loo"])
for (id in c("M1", "M2")) {
  n_new <- length(loos[[id]]$pointwise[, "elpd_loo"])
  if (n_new != n_ref) stop(id, " LOO has ", n_new, " points; M4 has ", n_ref, ". Not comparing them.")
}
delta_vs <- function(a, b) {
  d <- loos[[a]]$pointwise[, "elpd_loo"] - loos[[b]]$pointwise[, "elpd_loo"]
  c(delta = sum(d), se = stats::sd(d) * sqrt(length(d)))
}
cmp <- bind_rows(lapply(cmp_ids, function(id) {
  dv <- delta_vs(id, "M4")
  tibble(
    model = id,
    elpd_loo = elpd_of(loos[[id]]),
    se_elpd_loo = se_of(loos[[id]]),
    p_loo = loos[[id]]$estimates["p_loo", "Estimate"],
    delta_elpd_vs_M4 = unname(dv["delta"]),
    se_delta_elpd_vs_M4 = unname(dv["se"]),
    n_k_gt_0.7 = sum(loos[[id]]$diagnostics$pareto_k > 0.7, na.rm = TRUE),
    refit = id %in% c("M1", "M2")
  )
}))
write_tbl(cmp, "model_comparison_M0_M4b.csv")

# ---- M4_thr0.15 effort terms, same quantities as T6a ----

qsum <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) {
    return(list(median = NA_real_, q2.5 = NA_real_, q97.5 = NA_real_, p_lt0 = NA_real_, p_gt0 = NA_real_))
  }
  list(
    median = stats::median(x), q2.5 = as.numeric(stats::quantile(x, 0.025)),
    q97.5 = as.numeric(stats::quantile(x, 0.975)), p_lt0 = mean(x < 0), p_gt0 = mean(x > 0)
  )
}
ROPE <- list(v = 0.02, a = 0.05, z = 0.05)
rope_for <- function(term) {
  if (grepl("^b_bs_|^bs_", term)) return(ROPE$a)
  if (grepl("bias", term)) return(ROPE$z)
  ROPE$v
}
effort_rows <- function(d) {
  spec <- tribble(
    ~term, ~label, ~link,
    "b_effort_conditionhigh", "drift criterion (High - Low)", "identity",
    "b_effort_x_stim", "evidence quality (high x stimulus)", "identity",
    "b_bs_effort_conditionhigh", "boundary (High - Low)", "log",
    "b_bias_effort_conditionhigh", "bias (High - Low)", "logit",
    "drift_different", "drift change, different trials (criterion + quality)", "identity",
    "drift_same", "drift change, same trials (criterion - quality)", "identity"
  )
  d$drift_different <- d$b_effort_conditionhigh + d$b_effort_x_stim
  d$drift_same <- d$b_effort_conditionhigh - d$b_effort_x_stim
  bias_int <- d$b_bias_Intercept
  bind_rows(lapply(seq_len(nrow(spec)), function(i) {
    term <- spec$term[i]
    x <- d[[term]]
    s <- qsum(x)
    half <- rope_for(term)
    nat <- if (term == "b_bs_effort_conditionhigh") {
      qsum(100 * (exp(x) - 1))
    } else if (term == "b_bias_effort_conditionhigh") {
      qsum(plogis(bias_int + x) - plogis(bias_int))
    } else {
      s
    }
    tibble(
      term = term, label = spec$label[i], link = spec$link[i],
      median = s$median, q2.5 = s$q2.5, q97.5 = s$q97.5,
      p_lt0 = s$p_lt0, p_gt0 = s$p_gt0,
      pct_in_rope = mean(abs(x) < half) * 100, rope_halfwidth = half,
      natural_scale_median = nat$median, natural_scale_q2.5 = nat$q2.5, natural_scale_q97.5 = nat$q97.5
    )
  }))
}
draws15 <- as.data.frame(posterior::as_draws_df(fits$M4_thr0.15))
new_eff <- effort_rows(draws15)
new_eff$model <- "M4_thr0.15"
t0_new <- qsum(exp(draws15$b_ndt_Intercept))
new_eff$t0_median <- t0_new$median
new_eff$t0_q2.5 <- t0_new$q2.5
new_eff$t0_q97.5 <- t0_new$q97.5
write_tbl(new_eff, "M4_thr0.15_effort_terms.csv")

old_t6 <- read_csv(file.path(TAB, "T6a_robustness_effort_terms.csv"), show_col_types = FALSE) %>%
  filter(model == "M4_thr0.15")
old_t5 <- read_csv(file.path(TAB, "T5_model_comparison.csv"), show_col_types = FALSE)
old_t10 <- read_csv(file.path(TAB, "T10_convergence_all.csv"), show_col_types = FALSE) %>%
  filter(model %in% conv$model)
side_eff <- new_eff %>%
  left_join(old_t6 %>% select(term, median_old = median, q2.5_old = q2.5, q97.5_old = q97.5), by = "term")
side_elpd <- cmp %>%
  filter(model %in% c("M1", "M2")) %>%
  left_join(old_t5 %>% select(model, elpd_old = elpd_loo, delta_old = delta_elpd_vs_M4), by = "model")
side_conv <- conv %>%
  left_join(
    old_t10 %>% select(model, max_rhat_old = max_rhat, min_bulk_ess_old = min_bulk_ess,
                       min_tail_ess_old = min_tail_ess, divergences_old = divergences),
    by = "model"
  )
write_tbl(side_eff, "old_vs_new_effort.csv")
write_tbl(side_elpd, "old_vs_new_elpd.csv")
write_tbl(side_conv, "old_vs_new_convergence.csv")

failed <- conv$model[!conv$passes]
if (length(failed)) {
  msg <- paste0(
    "These models still fail max R-hat < 1.01, bulk and tail ESS >= 400, and 0 divergences: ",
    paste(failed, collapse = ", "),
    ". The run was not extended. tables/final was not changed."
  )
  writeLines(msg, file.path(DIRS$tables, "r11_STOPPED.md"))
  status("stop", msg)
  stop(msg, call. = FALSE)
}

# Export is a separate script so it can be re-run against the local Phase 1d
# tables if this process exported onto an older VM copy.
status("export", "all three models passed; running scripts/r11/export_r11.R")
Sys.setenv(R11_RUN_ID = RUN_ID)
export_status <- system2("Rscript", "scripts/r11/export_r11.R")
if (!is.null(export_status) && export_status != 0) {
  stop("scripts/r11/export_r11.R exited with status ", export_status, call. = FALSE)
}
status("done", "R11 export finished")
