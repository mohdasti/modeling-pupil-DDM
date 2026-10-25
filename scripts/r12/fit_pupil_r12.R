# Fit the 15 r12 pupil models. No behavioral refit.
#   Rscript scripts/r12/fit_pupil_r12.R --dry-run
#   Rscript scripts/r12/fit_pupil_r12.R
# A worker is the same script with --model P0 --run-dir <dir>.

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

args <- commandArgs(trailingOnly = TRUE)
dry <- "--dry-run" %in% args
arg_val <- function(flag) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) return("")
  args[i + 1L]
}
one_model <- arg_val("--model")
run_dir_arg <- arg_val("--run-dir")

DATA_DIR <- "data/analysis_ready/r12"
PUPIL_CSV <- file.path(DATA_DIR, "ddm_pupil_r12.csv")
MD5_FILE <- file.path(DATA_DIR, "MD5SUMS")

check_md5 <- function() {
  if (!file.exists(MD5_FILE)) stop("Missing ", MD5_FILE, call. = FALSE)
  lines <- readLines(MD5_FILE, warn = FALSE)
  lines <- lines[nzchar(lines)]
  if (!length(lines)) stop("MD5SUMS is empty.", call. = FALSE)
  for (line in lines) {
    bits <- strsplit(line, "  ", fixed = TRUE)[[1]]
    if (length(bits) != 2L) stop("Bad MD5SUMS line: ", line, call. = FALSE)
    path <- file.path(DATA_DIR, bits[2])
    if (!file.exists(path)) stop("MD5SUMS lists a missing file: ", bits[2], call. = FALSE)
    got <- unname(tools::md5sum(path))
    if (!identical(got, bits[1])) {
      stop(sprintf("md5 mismatch for %s: %s, expected %s", bits[2], got, bits[1]), call. = FALSE)
    }
  }
  invisible(TRUE)
}

FAMILY <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")
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
WANTED <- c("P0", "P1", "P2", "P3", "P0_base", "P4", "P5",
            "P0_rt", "P3_rt", "P0_lag", "P6", "P0_pre", "P7", "P0_grip", "P8")
BASELINE <- c(
  P1 = "P0", P2 = "P0", P3 = "P0", P4 = "P0_base", P5 = "P0_base",
  P3_rt = "P0_rt", P6 = "P0_lag", P7 = "P0_pre", P8 = "P0_grip"
)
SLOPE_TERMS <- list(
  P0 = c("b_effort_conditionhigh", "b_effort_x_stim", "b_bs_effort_conditionhigh", "b_bias_effort_conditionhigh"),
  P1 = "b_bias_tepr_c",
  P2 = c("b_tepr_c", "b_tepr_c:stim_sign"),
  P3 = "b_bs_tepr_c",
  P4 = "b_bias_base_c",
  P5 = "b_bs_base_c",
  P6 = "b_bs_lag_tepr_c",
  P7 = "b_bs_prechoice_c",
  P8 = "b_bs_grip_c",
  P3_rt = "b_bs_tepr_c"
)

check_md5()
if (!file.exists(PUPIL_CSV)) stop("Missing ", PUPIL_CSV, call. = FALSE)
pupil_raw <- read_csv(PUPIL_CSV, show_col_types = FALSE)
need_cols <- c("subject_id", "task", "effort_condition", "difficulty_3", "choice_binary",
               "rt", "rt_cue", "stim_sign", "effort_x_stim", "tepr_c", "base_c",
               "lag_tepr_c", "prechoice_c", "grip_c", "keep_p3_rt")
missing_cols <- setdiff(need_cols, names(pupil_raw))
if (length(missing_cols)) stop("r12 file is missing: ", paste(missing_cols, collapse = ", "), call. = FALSE)
if (!all(vapply(WANTED, function(k) inherits(FORMULAS[[k]], "brmsformula"), logical(1)))) {
  stop("A pupil formula was not built.", call. = FALSE)
}

if (dry && !nzchar(one_model)) {
  message(sprintf(
    "dry-run ok: %d trials, %d participants, %d formulas. Concurrent models would be %d.",
    nrow(pupil_raw), dplyr::n_distinct(pupil_raw$subject_id), length(WANTED),
    max(1L, floor(parallel::detectCores() / 8))
  ))
  quit(save = "no", status = 0)
}

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
pupil <- prepare(pupil_raw)
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
pupil_coef_priors <- function(formula, data) {
  gp <- as.data.frame(get_prior(formula, data = data, family = FAMILY))
  hit <- gp[gp$class == "b" & nzchar(gp$coef) & grepl("tepr_c|base_c|prechoice_c|grip_c|lag_tepr_c", gp$coef), , drop = FALSE]
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

fit_passes <- function(fit) {
  s <- posterior::summarise_draws(
    fit, rhat = posterior::rhat, ess_bulk = posterior::ess_bulk, ess_tail = posterior::ess_tail
  )
  np <- brms::nuts_params(fit)
  div <- sum(np$Parameter == "divergent__" & np$Value > 0)
  list(
    pass = isTRUE(max(s$rhat, na.rm = TRUE) < 1.01 &&
                    min(s$ess_bulk, na.rm = TRUE) >= 400 &&
                    min(s$ess_tail, na.rm = TRUE) >= 400 &&
                    div == 0),
    max_rhat = max(s$rhat, na.rm = TRUE),
    min_bulk_ess = min(s$ess_bulk, na.rm = TRUE),
    min_tail_ess = min(s$ess_tail, na.rm = TRUE),
    divergences = div,
    worst_param = s$variable[which.max(s$rhat)]
  )
}

if (!nzchar(one_model)) {
  n_cores <- parallel::detectCores()
  n_concurrent <- max(1L, floor(n_cores / 8))
  OUT_ROOT <- file.path("output", "ddm_refits", "runs")
  dir.create(OUT_ROOT, recursive = TRUE, showWarnings = FALSE)
  run_id <- paste0("r12_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  run_dir <- file.path(OUT_ROOT, run_id)
  for (d in c("fits", "loo", "tables", "logs")) dir.create(file.path(run_dir, d), recursive = TRUE)
  writeLines(run_id, file.path(OUT_ROOT, "r12_latest_run_id.txt"))
  writeLines(sprintf("md5 ok %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
             file.path(run_dir, "logs", "md5_ok.txt"))
  message("Run ", run_dir, " with ", n_concurrent, " models at a time.")
  pending <- WANTED
  running <- list()
  # system2(wait = FALSE) returns 0 on this R, so the pid comes from the shell.
  launch <- function(key) {
    log <- file.path(run_dir, "logs", paste0(key, ".log"))
    cmd <- sprintf(
      "Rscript scripts/r12/fit_pupil_r12.R --model %s --run-dir %s > %s 2>&1 & echo $!",
      shQuote(key), shQuote(run_dir), shQuote(log)
    )
    pid <- as.integer(system(cmd, intern = TRUE))
    if (!is.finite(pid) || pid <= 0L) stop("Could not start ", key, call. = FALSE)
    pid
  }
  still_running <- function(pid) {
    system2("ps", c("-p", as.character(pid)), stdout = FALSE, stderr = FALSE) == 0
  }
  while (length(pending) || length(running)) {
    while (length(pending) && length(running) < n_concurrent) {
      key <- pending[1]
      pending <- pending[-1]
      running[[key]] <- launch(key)
    }
    Sys.sleep(5)
    done <- names(running)[!vapply(running, still_running, logical(1))]
    for (key in done) running[[key]] <- NULL
  }
  conv <- bind_rows(lapply(WANTED, function(key) {
    path <- file.path(run_dir, "tables", paste0("conv_", key, ".csv"))
    if (file.exists(path)) read_csv(path, show_col_types = FALSE) else
      tibble(model = key, pass = FALSE, note = "no convergence file")
  }))
  write_csv(conv, file.path(run_dir, "tables", "convergence_full.csv"))
  if (any(grepl("^N_MISMATCH_", list.files(run_dir)))) {
    stop("Pointwise LOO n differed for a model and its baseline.", call. = FALSE)
  }
  parts <- lapply(WANTED, function(key) {
    path <- file.path(run_dir, "tables", paste0("summary_", key, ".csv"))
    if (file.exists(path)) read_csv(path, show_col_types = FALSE) else NULL
  })
  summary_tbl <- bind_rows(parts)
  # Workers may finish before their baseline's LOO file exists, so the parent fills ΔELPD here.
  for (i in seq_len(nrow(summary_tbl))) {
    key <- summary_tbl$model[i]
    base <- unname(BASELINE[key])
    if (is.na(base) || !nzchar(base)) next
    a <- file.path(run_dir, "loo", paste0("loo_", key, ".rds"))
    b <- file.path(run_dir, "loo", paste0("loo_", base, ".rds"))
    if (!file.exists(a) || !file.exists(b)) next
    e1 <- readRDS(a)$pointwise[, "elpd_loo"]
    e0 <- readRDS(b)$pointwise[, "elpd_loo"]
    if (length(e1) != length(e0)) {
      stop(sprintf("Pointwise n differs: %s %d vs %s %d", key, length(e1), base, length(e0)), call. = FALSE)
    }
    d <- e1 - e0
    summary_tbl$baseline[i] <- base
    summary_tbl$delta_elpd[i] <- sum(d)
    summary_tbl$se_delta_elpd[i] <- sqrt(length(d) * var(d))
  }
  write_csv(summary_tbl, file.path(run_dir, "tables", "pupil_summary.csv"))
  message("Finished ", run_dir)
  quit(save = "no", status = 0)
}

# ---- one model ----
if (!one_model %in% WANTED) stop("Unknown model: ", one_model, call. = FALSE)
if (!nzchar(run_dir_arg) || !dir.exists(run_dir_arg)) stop("Worker needs --run-dir.", call. = FALSE)
RUN_DIR <- run_dir_arg
fit_path <- file.path(RUN_DIR, "fits", paste0(one_model, ".rds"))
loo_path <- file.path(RUN_DIR, "loo", paste0("loo_", one_model, ".rds"))
log_line <- function(...) {
  cat(paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", paste(..., collapse = " "), "\n"),
      file = file.path(RUN_DIR, "logs", paste0(one_model, ".log")), append = TRUE)
}

sample_one <- function(key, iter, warmup, adapt_delta) {
  df <- DATA[[key]]
  formula <- FORMULAS[[key]]
  nb <- ndt_bounds(df)
  pr <- priors_for(formula, df, nb)
  if (file.exists(fit_path)) file.remove(fit_path)
  log_line("Fit", key, "N", nrow(df), "iter", iter, "adapt_delta", adapt_delta)
  brm(
    formula = formula, data = df, family = FAMILY, prior = pr,
    chains = 8L, iter = iter, warmup = warmup, cores = 8L,
    threads = threading(1),
    init = make_init(formula, df, nb, pr),
    control = list(adapt_delta = adapt_delta, max_treedepth = 12),
    save_pars = save_pars(all = TRUE), backend = "cmdstanr", seed = 2026L,
    file = sub("\\.rds$", "", fit_path), file_refit = "always", refresh = 200
  )
}

fit <- NULL
conv <- NULL
if (file.exists(fit_path)) {
  loaded <- tryCatch(readRDS(fit_path), error = function(e) NULL)
  if (!is.null(loaded)) {
    conv <- tryCatch(fit_passes(loaded), error = function(e) NULL)
    if (!is.null(conv) && isTRUE(conv$pass)) {
      fit <- loaded
      log_line(one_model, "existing fit passes; skipping the sampler")
    }
  }
}
if (is.null(fit)) {
  res <- tryCatch(sample_one(one_model, 3000L, 1500L, 0.95), error = function(e) e)
  if (!inherits(res, "error")) conv <- tryCatch(fit_passes(res), error = function(e) e)
  if (inherits(res, "error") || inherits(conv, "error") || !isTRUE(conv$pass)) {
    why <- if (inherits(res, "error")) conditionMessage(res) else
      sprintf("Rhat %.4f bulk %.0f tail %.0f div %d", conv$max_rhat, conv$min_bulk_ess, conv$min_tail_ess, conv$divergences)
    log_line(one_model, "failed (", why, "); refit at 4500 / adapt_delta 0.99")
    res2 <- tryCatch(sample_one(one_model, 4500L, 1500L, 0.99), error = function(e) e)
    if (inherits(res2, "error")) {
      writeLines(conditionMessage(res2), file.path(RUN_DIR, paste0("FAILED_", one_model, ".txt")))
      quit(save = "no", status = 0)
    }
    conv <- tryCatch(fit_passes(res2), error = function(e) e)
    if (inherits(conv, "error") || !isTRUE(conv$pass)) {
      msg <- if (inherits(conv, "error")) conditionMessage(conv) else
        sprintf("Rhat %.4f bulk ESS %.0f tail ESS %.0f divergences %d",
                conv$max_rhat, conv$min_bulk_ess, conv$min_tail_ess, conv$divergences)
      writeLines(msg, file.path(RUN_DIR, paste0("FAILED_", one_model, ".txt")))
      quit(save = "no", status = 0)
    }
    fit <- res2
  } else {
    fit <- res
  }
}

write_csv(tibble(
  model = one_model, n_trials = nrow(DATA[[one_model]]),
  n_subjects = dplyr::n_distinct(DATA[[one_model]]$subject_id),
  max_rhat = conv$max_rhat, min_bulk_ess = conv$min_bulk_ess, min_tail_ess = conv$min_tail_ess,
  divergences = conv$divergences, worst_param = conv$worst_param, pass = conv$pass
), file.path(RUN_DIR, "tables", paste0("conv_", one_model, ".csv")))

run_loo <- function(fit) {
  obj0 <- brms::loo(fit)
  k <- obj0$diagnostics$pareto_k
  obj <- obj0
  if (any(k > 0.7, na.rm = TRUE)) {
    obj <- tryCatch(brms::loo_moment_match(fit, loo = obj0, k_threshold = 0.7), error = function(e) obj0)
    k2 <- obj$diagnostics$pareto_k
    if (any(k2 > 0.7, na.rm = TRUE)) {
      obj <- tryCatch(brms::reloo(fit, loo = obj, k_threshold = 0.7, check = FALSE), error = function(e) obj)
    }
  }
  obj$psis_object <- NULL
  obj
}
if (!file.exists(loo_path)) {
  lo <- tryCatch(run_loo(fit), error = function(e) e)
  if (inherits(lo, "error")) {
    writeLines(paste("LOO failed:", conditionMessage(lo)), file.path(RUN_DIR, paste0("FAILED_", one_model, ".txt")))
    quit(save = "no", status = 0)
  }
  saveRDS(lo, loo_path)
} else {
  lo <- readRDS(loo_path)
}

summarise_model <- function(key, fit, lo) {
  draws <- posterior::as_draws_df(fit)
  terms <- SLOPE_TERMS[[key]]
  rows <- list()
  if (!is.null(terms)) {
    for (term in terms) {
      if (!term %in% names(draws)) stop("Missing coefficient ", term, " in ", key, call. = FALSE)
      x <- draws[[term]]
      q <- quantile(x, c(0.025, 0.5, 0.975))
      on_boundary <- grepl("^b_bs_", term)
      rows[[length(rows) + 1L]] <- tibble(
        model = key, term = term,
        n_trials = nrow(DATA[[key]]), n_subjects = dplyr::n_distinct(DATA[[key]]$subject_id),
        median = unname(q[2]), q025 = unname(q[1]), q975 = unname(q[3]),
        pct = if (on_boundary) 100 * (exp(q[2]) - 1) else NA_real_,
        pct_lo = if (on_boundary) 100 * (exp(q[1]) - 1) else NA_real_,
        pct_hi = if (on_boundary) 100 * (exp(q[3]) - 1) else NA_real_,
        baseline = unname(BASELINE[key]), delta_elpd = NA_real_, se_delta_elpd = NA_real_
      )
    }
  } else {
    rows[[1]] <- tibble(
      model = key, term = NA_character_,
      n_trials = nrow(DATA[[key]]), n_subjects = dplyr::n_distinct(DATA[[key]]$subject_id),
      median = NA_real_, q025 = NA_real_, q975 = NA_real_,
      pct = NA_real_, pct_lo = NA_real_, pct_hi = NA_real_,
      baseline = NA_character_, delta_elpd = NA_real_, se_delta_elpd = NA_real_
    )
  }
  base <- unname(BASELINE[key])
  if (!is.na(base) && nzchar(base)) {
    base_loo_path <- file.path(RUN_DIR, "loo", paste0("loo_", base, ".rds"))
    if (file.exists(base_loo_path)) {
      base_loo <- readRDS(base_loo_path)
      e1 <- lo$pointwise[, "elpd_loo"]
      e0 <- base_loo$pointwise[, "elpd_loo"]
      if (length(e1) != length(e0)) {
        writeLines(sprintf("%s n=%d %s n=%d", key, length(e1), base, length(e0)),
                   file.path(RUN_DIR, paste0("N_MISMATCH_", key, ".txt")))
        stop(sprintf("Pointwise n differs: %s %d vs %s %d", key, length(e1), base, length(e0)), call. = FALSE)
      }
      d <- e1 - e0
      rows <- lapply(rows, function(r) {
        r$delta_elpd <- sum(d)
        r$se_delta_elpd <- sqrt(length(d) * var(d))
        r
      })
    }
  }
  bind_rows(rows)
}
write_csv(summarise_model(one_model, fit, lo), file.path(RUN_DIR, "tables", paste0("summary_", one_model, ".csv")))
log_line(one_model, "done")
