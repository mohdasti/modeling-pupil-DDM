# Part C. Pupil models only, on the r8 QC sample.
# Does not fit or modify M0-M4b, M4r, cutoff, or near-chance models.

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(posterior)
  library(dplyr)
  library(readr)
  library(tibble)
})

options(warn = 1)
ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
PUPIL_CSV <- Sys.getenv("PUPIL_CSV", unset = "data/analysis_ready/r8/ddm_pupil_r8.csv")
stopifnot(file.exists(PUPIL_CSV))

OUT_ROOT <- file.path("output", "ddm_refits", "runs")
RUN_PREFIX <- Sys.getenv("PUPIL_RUN_PREFIX", unset = "r8")
RUN_ID <- paste0(RUN_PREFIX, "_", format(Sys.time(), "%Y%m%d_%H%M%S"))
RUN_DIR <- file.path(OUT_ROOT, RUN_ID)
DIRS <- list(models = file.path(RUN_DIR, "models"), loo = file.path(RUN_DIR, "loo"),
             tables = file.path(RUN_DIR, "tables"), logs = file.path(RUN_DIR, "logs"))
for (d in DIRS) dir.create(d, recursive = TRUE, showWarnings = FALSE)
writeLines(RUN_ID, file.path(OUT_ROOT, paste0(RUN_PREFIX, "_latest_run_id.txt")))
writeLines(RUN_DIR, "output/diagnostics/pupil_rebuild/r8_run_dir.txt")

N_CORES <- parallel::detectCores()
SAMPLER <- list(chains = 8L, iter = 3000L, warmup = 1500L, adapt_delta = 0.95,
                max_treedepth = 12L, seed = 2026L)
CHAIN_CORES <- max(1L, min(SAMPLER$chains, N_CORES))
THREADS <- max(1L, N_CORES %/% SAMPLER$chains)
LOO_CORES <- min(8L, N_CORES)
options(mc.cores = LOO_CORES)

LOG_FILE <- file.path(DIRS$logs, "r8_master.log")
STATUS_FILE <- file.path(DIRS$logs, "r8_status.txt")
log_msg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", paste(..., collapse = " "))
  cat(line, "\n"); cat(line, "\n", file = LOG_FILE, append = TRUE)
}
status <- function(stage, msg) {
  line <- sprintf("%s | %-8s | %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), stage, msg)
  cat(line, "\n", file = STATUS_FILE, append = TRUE); log_msg(stage, "-", msg)
}
stop_run <- function(msg) {
  writeLines(msg, "output/diagnostics/pupil_rebuild/STOPPED.md")
  status("STOP", msg)
  quit(status = 2)
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
pupil_coef_priors <- function(formula, data) {
  gp <- as.data.frame(get_prior(formula, data = data, family = FAMILY))
  hit <- gp[gp$class == "b" & nzchar(gp$coef) & grepl("tepr_c|base_c|prechoice_c|grip_c", gp$coef), , drop = FALSE]
  if (!nrow(hit)) return(NULL)
  pr <- vector("list", nrow(hit))
  for (i in seq_len(nrow(hit))) {
    dpar <- hit$dpar[i]
    dpar <- if (is.na(dpar)) "" else dpar
    sd <- if (identical(dpar, "bs")) 0.20 else 0.5
    spec <- sprintf("normal(0, %g)", sd)
    pr[[i]] <- if (!nzchar(dpar)) prior_string(spec, class = "b", coef = hit$coef[i]) else
      prior_string(spec, class = "b", coef = hit$coef[i], dpar = dpar)
  }
  do.call(c, pr)
}
BIAS_F <- bias ~ task + effort_condition + (1 | subject_id)
BS_F <- bs ~ difficulty_3 + task + effort_condition + (1 | subject_id)
V_F <- rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id)
FORMULAS <- list(
  P0 = bf(V_F, BS_F, ndt ~ 1, BIAS_F),
  P1 = bf(V_F, BS_F, ndt ~ 1, bias ~ task + effort_condition + tepr_c + (1 | subject_id)),
  P2 = bf(
    rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim +
      tepr_c + tepr_c:stim_sign + (1 | subject_id),
    BS_F, ndt ~ 1, BIAS_F
  ),
  P3 = bf(V_F, bs ~ difficulty_3 + task + effort_condition + tepr_c + (1 | subject_id), ndt ~ 1, BIAS_F),
  P4 = bf(V_F, BS_F, ndt ~ 1, bias ~ task + effort_condition + base_c + (1 | subject_id)),
  P5 = bf(V_F, bs ~ difficulty_3 + task + effort_condition + base_c + (1 | subject_id), ndt ~ 1, BIAS_F),
  P6 = bf(V_F, bs ~ difficulty_3 + task + effort_condition + lag_tepr_c + (1 | subject_id), ndt ~ 1, BIAS_F),
  P7 = bf(V_F, bs ~ difficulty_3 + task + effort_condition + prechoice_c + (1 | subject_id), ndt ~ 1, BIAS_F),
  P8 = bf(V_F, bs ~ difficulty_3 + task + effort_condition + grip_c + (1 | subject_id), ndt ~ 1, BIAS_F),
  P3_rt = bf(V_F, bs ~ difficulty_3 + task + effort_condition + tepr_c + (1 | subject_id), ndt ~ 1, BIAS_F)
)
FORMULAS$P0_base <- FORMULAS$P0
FORMULAS$P0_lag <- FORMULAS$P0
FORMULAS$P0_pre <- FORMULAS$P0
FORMULAS$P0_grip <- FORMULAS$P0
FORMULAS$P0_rt <- FORMULAS$P0

prepare <- function(df) {
  df$difficulty_3 <- factor(df$difficulty_3, levels = c("Standard", "Hard", "Easy"))
  df$effort_condition <- factor(df$effort_condition, levels = c("low", "high"))
  df$task <- factor(df$task, levels = c("ADT", "VDT"))
  df$subject_id <- as.character(df$subject_id)
  df$choice_binary <- as.integer(df$choice_binary)
  df$stim_sign <- ifelse(df$difficulty_3 %in% c("Hard", "Easy"), 1, -1)
  df$effort_x_stim <- as.numeric(df$effort_condition == "high") * df$stim_sign
  df$keep_p3_rt <- as.logical(df$keep_p3_rt)
  stopifnot(all(abs(df$rt - df$rt_cue - 0.35) < 1e-6), min(df$rt) > 0.5)
  df
}
finite_col <- function(df, col) df[is.finite(df[[col]]), , drop = FALSE]
ndt_bounds <- function(df) {
  ub_val <- min(df$rt) - 0.01
  if (!is.finite(ub_val) || ub_val <= 0.05) stop("Invalid ndt upper bound: ", ub_val)
  init_val <- if (log(0.50) < log(ub_val) - 0.005) 0.50 else 0.98 * ub_val
  list(ub_val = ub_val, ub = log(ub_val), init_val = init_val)
}
make_init <- function(formula, df, nb, priors) {
  sdata <- brms::standata(formula, data = df, family = FAMILY, prior = priors)
  m_names <- grep("^M_[0-9]+$", names(sdata), value = TRUE)
  base <- list(Intercept = 0, Intercept_bs = log(2.2), Intercept_ndt = log(nb$init_val), Intercept_bias = 0)
  for (m in m_names) {
    k <- sub("^M_", "", m)
    base[[paste0("sd_", k)]] <- array(rep(0.1, sdata[[m]]), dim = sdata[[m]])
  }
  function(chain_id = 1) base
}
priors_for <- function(formula, df, nb) {
  pr <- make_priors(nb$ub)
  extra <- pupil_coef_priors(formula, df)
  if (!is.null(extra)) pr <- c(pr, extra)
  pr
}

pupil <- prepare(read_csv(PUPIL_CSV, show_col_types = FALSE))
base_rows <- finite_col(pupil, "base_c")
DATA <- list(
  P0 = pupil, P1 = pupil, P2 = pupil, P3 = pupil,
  P4 = base_rows, P5 = base_rows, P0_base = base_rows,
  P0_rt = pupil[pupil$keep_p3_rt %in% TRUE, , drop = FALSE],
  P3_rt = pupil[pupil$keep_p3_rt %in% TRUE, , drop = FALSE],
  P0_lag = finite_col(pupil, "lag_tepr_c"),
  P6 = finite_col(pupil, "lag_tepr_c"),
  P0_pre = finite_col(pupil, "prechoice_c"),
  P7 = finite_col(pupil, "prechoice_c"),
  P0_grip = finite_col(pupil, "grip_c"),
  P8 = finite_col(pupil, "grip_c")
)
# P4/P5 need a baseline on the same rows. P3 is compared with the full-sample P0.
# P5 is also compared with P0_base, because  trials without a B0 mean cannot enter base_c.
log_msg("==== R8 pupil refit ====", RUN_DIR)
log_msg("Full QC", nrow(pupil), "with base_c", nrow(base_rows),
        "missing base_c", nrow(pupil) - nrow(base_rows))
log_msg("Sampler chains", SAMPLER$chains, "iter", SAMPLER$iter, "warmup", SAMPLER$warmup,
        "adapt_delta", SAMPLER$adapt_delta, "threads", THREADS)

wanted <- c("P0", "P1", "P2", "P3", "P0_base", "P4", "P5",
            "P0_rt", "P3_rt", "P0_lag", "P6", "P0_pre", "P7", "P0_grip", "P8")

fit_one <- function(key, adapt_delta) {
  formula <- FORMULAS[[key]]
  df <- DATA[[key]]
  nb <- ndt_bounds(df)
  pr <- priors_for(formula, df, nb)
  path <- file.path(DIRS$models, sprintf("%s__probe_onset_locked__thr0.20.rds", key))
  if (file.exists(path)) file.remove(path)
  log_msg("Fit", key, "N", nrow(df), "adapt_delta", adapt_delta, "ndt ub", round(nb$ub_val, 4))
  t0 <- Sys.time()
  fit <- brm(
    formula = formula, data = df, family = FAMILY, prior = pr,
    chains = SAMPLER$chains, iter = SAMPLER$iter, warmup = SAMPLER$warmup,
    cores = CHAIN_CORES, threads = if (THREADS > 1) threading(THREADS) else NULL,
    init = make_init(formula, df, nb, pr),
    control = list(adapt_delta = adapt_delta, max_treedepth = SAMPLER$max_treedepth),
    save_pars = save_pars(all = TRUE), backend = "cmdstanr", seed = SAMPLER$seed,
    file = path, file_refit = "always", refresh = 250
  )
  list(fit = fit, minutes = as.numeric(difftime(Sys.time(), t0, units = "mins")), path = path)
}
converged <- function(fit) {
  s <- summarise_draws(as_draws_array(fit))
  sp <- rstan::get_sampler_params(fit$fit, inc_warmup = FALSE)
  div <- sum(vapply(sp, function(x) sum(x[, "divergent__"]), numeric(1)))
  rhat <- max(s$rhat, na.rm = TRUE)
  ess <- min(s$ess_bulk, na.rm = TRUE)
  list(pass = isTRUE(rhat < 1.01 && ess > 400 && div == 0), rhat = rhat, ess = ess, div = div)
}

conv_rows <- list()
fits <- list()
for (key in wanted) {
  status("fit", paste("start", key))
  res <- tryCatch(fit_one(key, 0.95), error = function(e) e)
  if (inherits(res, "error")) {
    status("fit", paste("error", key, conditionMessage(res), "retry adapt_delta 0.99"))
    res <- tryCatch(fit_one(key, 0.99), error = function(e) e)
    if (inherits(res, "error")) stop_run(paste("STOP.", key, "failed to sample twice:", conditionMessage(res)))
  }
  conv <- converged(res$fit)
  adapt_used <- 0.95
  if (!conv$pass) {
    status("fit", sprintf("%s failed Rhat %.4f ESS %.1f div %d; retry adapt_delta 0.99",
                           key, conv$rhat, conv$ess, conv$div))
    res <- tryCatch(fit_one(key, 0.99), error = function(e) e)
    if (inherits(res, "error")) stop_run(paste("STOP.", key, "retry failed:", conditionMessage(res)))
    conv <- converged(res$fit)
    adapt_used <- 0.99
    if (!conv$pass) {
      stop_run(sprintf("STOP. %s failed after adapt_delta 0.99 (Rhat %.4f, bulk ESS %.1f, divergences %d).",
                       key, conv$rhat, conv$ess, conv$div))
    }
  }
  fits[[key]] <- res$fit
  conv_rows[[key]] <- tibble(model = key, n = nrow(DATA[[key]]), adapt_delta = adapt_used,
                              rhat = conv$rhat, ess_bulk = conv$ess, divergences = conv$div,
                              pass = conv$pass, minutes = res$minutes)
  write_csv(bind_rows(conv_rows), file.path(DIRS$tables, "convergence.csv"))
  status("fit", sprintf("done %s in %.1f min Rhat %.4f ESS %.0f div %d",
                         key, res$minutes, conv$rhat, conv$ess, conv$div))
}

pareto_bins <- function(k) {
  k <- as.numeric(k)
  c(k_le_0.5 = sum(k <= 0.5, na.rm = TRUE), k_0.5_0.7 = sum(k > 0.5 & k <= 0.7, na.rm = TRUE),
    k_0.7_1 = sum(k > 0.7 & k <= 1, na.rm = TRUE), k_gt_1 = sum(k > 1, na.rm = TRUE))
}
strip_loo <- function(obj) { obj$psis_object <- NULL; obj }
for (key in wanted) {
  status("loo", paste("start", key))
  path <- file.path(DIRS$loo, sprintf("loo_%s.rds", key))
  row <- list(model = key, mm_status = NA_character_, reloo_status = "not needed")
  t0 <- Sys.time()
  ok <- tryCatch({
    obj0 <- brms::loo(fits[[key]], cores = LOO_CORES)
    b0 <- pareto_bins(obj0$diagnostics$pareto_k)
    row$k_gt_0.7_psis <- b0[["k_0.7_1"]] + b0[["k_gt_1"]]
    obj <- obj0
    if (row$k_gt_0.7_psis > 0) {
      obj <- tryCatch({
        out <- brms::loo_moment_match(fits[[key]], loo = obj0, k_threshold = 0.7, cores = LOO_CORES)
        row$mm_status <- "ok"; out
      }, error = function(e) { row$mm_status <<- paste("failed:", gsub("\\s+", " ", conditionMessage(e))); obj0 })
    } else row$mm_status <- "not needed (no k > 0.7)"
    b1 <- pareto_bins(obj$diagnostics$pareto_k)
    row$k_gt_0.7_after_mm <- b1[["k_0.7_1"]] + b1[["k_gt_1"]]
    if (row$k_gt_0.7_after_mm > 0 && row$k_gt_0.7_after_mm <= 5) {
      status("loo", sprintf("%s reloo on %d points", key, row$k_gt_0.7_after_mm))
      obj <- tryCatch({
        out <- brms::reloo(fits[[key]], loo = obj, k_threshold = 0.7, check = FALSE)
        row$reloo_status <- sprintf("ok (%d points refit)", row$k_gt_0.7_after_mm); out
      }, error = function(e) { row$reloo_status <<- paste("failed:", gsub("\\s+", " ", conditionMessage(e))); obj })
    } else if (row$k_gt_0.7_after_mm > 5) {
      row$reloo_status <- sprintf("skipped (%d points > 5)", row$k_gt_0.7_after_mm)
    }
    b2 <- pareto_bins(obj$diagnostics$pareto_k)
    row$elpd_loo <- obj$estimates["elpd_loo", "Estimate"]
    row$se_elpd_loo <- obj$estimates["elpd_loo", "SE"]
    row$p_loo <- obj$estimates["p_loo", "Estimate"]
    row <- c(row, as.list(b2))
    row$loo_minutes <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
    saveRDS(strip_loo(obj), path)
    write_csv(as_tibble(row), file.path(DIRS$loo, sprintf("loo_%s_status.csv", key)))
    TRUE
  }, error = function(e) { status("loo", paste("FAILED", key, conditionMessage(e))); FALSE })
  if (!isTRUE(ok)) stop_run(paste("STOP. LOO failed for", key))
  status("loo", paste("done", key))
}
status("done", paste("R8 pupil fit/loo finished", RUN_DIR))
