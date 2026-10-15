#!/usr/bin/env Rscript
# Read-only LOO forensics for the canonical probe-onset-locked, thr 0.20 DDMs.
#
# Does not refit models and does not write into the run directory.
# Reuses saved loo objects when they belong to the loaded fit; otherwise
# computes loo() and saves the new object under output/diagnostics/loo_forensics/.
#
# Usage (from the repository root):
#   Rscript scripts/diagnostics/loo_forensics.R

suppressPackageStartupMessages({
  library(brms)
  library(loo)
  library(posterior)
  library(dplyr)
  library(readr)
})

options(warn = 1)

# ---- paths -----------------------------------------------------------------

find_root <- function() {
  env <- Sys.getenv("LOO_FORENSICS_ROOT", unset = "")
  if (nzchar(env)) {
    return(normalizePath(env, mustWork = TRUE))
  }
  d <- normalizePath(getwd(), mustWork = TRUE)
  for (i in seq_len(8)) {
    if (dir.exists(file.path(d, "output", "ddm_refits", "runs"))) {
      return(d)
    }
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("Could not find the repository root (output/ddm_refits/runs).")
}

resolve_run <- function(root) {
  runs_root <- file.path(root, "output", "ddm_refits", "runs")
  preferred <- file.path(runs_root, "20260226_092110")
  marker <- "additive__probe_onset_locked__thr0.20.rds"
  if (file.exists(file.path(preferred, "models", marker))) {
    return(normalizePath(preferred))
  }
  if (!dir.exists(runs_root)) {
    stop("Run directory is absent: ", runs_root)
  }
  runs <- list.dirs(runs_root, recursive = FALSE, full.names = TRUE)
  hits <- runs[file.exists(file.path(runs, "models", marker))]
  if (length(hits) == 0) {
    listed <- paste(basename(runs), collapse = ", ")
    stop(
      "Preferred run 20260226_092110 is absent or has no ", marker,
      ". Runs present: ", if (nzchar(listed)) listed else "(none)"
    )
  }
  normalizePath(hits[[1]])
}

ROOT <- find_root()
setwd(ROOT)
RUN_DIR <- resolve_run(ROOT)
MODELS_DIR <- file.path(RUN_DIR, "models")
LOO_DIR <- file.path(RUN_DIR, "loo")
OUT_DIR <- file.path(ROOT, "output", "diagnostics", "loo_forensics")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
if (startsWith(normalizePath(OUT_DIR), normalizePath(RUN_DIR))) {
  stop("Refusing to write into the canonical run directory.")
}

LOG_FILE <- file.path(OUT_DIR, "loo_forensics.log")
MD_FILE <- file.path(OUT_DIR, "loo_forensics.md")
cat("", file = LOG_FILE)

log_msg <- function(...) {
  msg <- paste0(
    "[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ",
    paste(..., collapse = " ")
  )
  message(msg)
  cat(msg, "\n", file = LOG_FILE, append = TRUE)
}

log_msg("Repository:", ROOT)
log_msg("Run:", RUN_DIR)
log_msg("Output:", OUT_DIR)

MODEL_ORDER <- c("baseline", "difficultyonly", "additive", "interaction")
MODEL_FILE <- function(model) {
  file.path(MODELS_DIR, sprintf("%s__probe_onset_locked__thr0.20.rds", model))
}
LOO_CANDIDATES <- list(
  baseline = c("loo_baseline_primary_thr.rds", "loo_baseline.rds"),
  difficultyonly = c("loo_difficultyonly_primary_thr.rds"),
  additive = c("loo_additive_primary_thr.rds"),
  interaction = c("loo_interaction_primary_thr.rds")
)

find_saved_loo <- function(model) {
  names <- LOO_CANDIDATES[[model]]
  hits <- file.path(LOO_DIR, names)
  hits <- hits[file.exists(hits)]
  if (length(hits) == 0) return(NA_character_)
  hits[[1]]
}

# ---- small helpers ---------------------------------------------------------

n_chains_of <- function(fit) {
  if (inherits(fit$fit, "stanfit")) {
    return(as.integer(fit$fit@sim$chains))
  }
  if (inherits(fit$fit, "CmdStanMCMC")) {
    return(as.integer(fit$fit$num_chains()))
  }
  as.integer(nchains(fit))
}

n_divergences_of <- function(fit) {
  np <- tryCatch(
    brms::nuts_params(fit, pars = "divergent__"),
    error = function(e) NULL
  )
  if (is.null(np) || nrow(np) == 0) return(NA_integer_)
  as.integer(sum(np$Value > 0, na.rm = TRUE))
}

ndt_summary_of <- function(fit) {
  draws <- posterior::as_draws_df(fit, variable = "Intercept_ndt")
  x <- exp(draws$Intercept_ndt)
  qs <- as.numeric(stats::quantile(x, probs = c(0.025, 0.5, 0.975), names = FALSE))
  data.frame(
    parameter = "exp(Intercept_ndt)",
    median = qs[[2]],
    q02.5 = qs[[1]],
    q97.5 = qs[[3]],
    stringsAsFactors = FALSE
  )
}

fixef_table <- function(fit, model) {
  fx <- brms::fixef(fit)
  data.frame(
    model = model,
    term = rownames(fx),
    Estimate = fx[, "Estimate"],
    Est.Error = fx[, "Est.Error"],
    Q2.5 = fx[, "Q2.5"],
    Q97.5 = fx[, "Q97.5"],
    row.names = NULL,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

pareto_k_vec <- function(obj) {
  if (!is.null(obj$diagnostics) && !is.null(obj$diagnostics$pareto_k)) {
    return(as.numeric(obj$diagnostics$pareto_k))
  }
  as.numeric(obj$pointwise[, "influence_pareto_k"])
}

pareto_counts <- function(k) {
  k <- as.numeric(k)
  c(
    n = length(k),
    k_gt_0.5_le_0.7 = sum(k > 0.5 & k <= 0.7, na.rm = TRUE),
    k_gt_0.7_le_1 = sum(k > 0.7 & k <= 1, na.rm = TRUE),
    k_gt_1 = sum(k > 1, na.rm = TRUE)
  )
}

loo_elpd <- function(obj) {
  est <- obj$estimates
  c(
    elpd_loo = unname(est["elpd_loo", "Estimate"]),
    se = unname(est["elpd_loo", "SE"])
  )
}

tf_chr <- function(x) {
  if (isTRUE(x)) "TRUE" else if (identical(x, FALSE)) "FALSE" else NA_character_
}

write_table <- function(df, filename) {
  path <- file.path(OUT_DIR, filename)
  readr::write_csv(df, path, na = "NA")
  log_msg("Wrote", path)
  invisible(path)
}

md_cell <- function(x) {
  if (is.factor(x)) x <- as.character(x)
  if (is.logical(x)) {
    out <- ifelse(is.na(x), "", ifelse(x, "TRUE", "FALSE"))
  } else if (is.character(x)) {
    out <- ifelse(is.na(x), "", x)
  } else if (is.numeric(x)) {
    out <- ifelse(is.na(x), "", vapply(x, format_num, character(1)))
  } else {
    out <- ifelse(is.na(x), "", as.character(x))
  }
  gsub("|", "\\|", out, fixed = TRUE)
}

format_num <- function(x) {
  if (!is.finite(x)) return("")
  if (abs(x - round(x)) < 1e-8 && abs(x) < 1e12) {
    return(formatC(round(x), format = "f", digits = 0))
  }
  digits <- if (abs(x) >= 100) 2 else 4
  formatC(x, format = "f", digits = digits)
}

md_table <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  if (nrow(df) == 0) {
    return("_(empty table)_")
  }
  cells <- lapply(df, md_cell)
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  rows <- vapply(seq_len(nrow(df)), function(i) {
    vals <- vapply(cells, function(col) col[[i]], character(1))
    paste0("| ", paste(vals, collapse = " | "), " |")
  }, character(1))
  paste(c(header, sep, rows), collapse = "\n")
}

fmt2 <- function(x) formatC(x, format = "f", digits = 2)
fmt4 <- function(x) formatC(x, format = "f", digits = 4)

# ---- 1. Load fits and extract diagnostics ----------------------------------

log_msg("Loading brmsfit files")
overview_rows <- list()
fixef_list <- list()
ndt_rows <- list()
vectors <- list()
trial_source <- NULL
baseline_fit <- NULL

for (model in MODEL_ORDER) {
  path <- MODEL_FILE(model)
  if (!file.exists(path)) {
    log_msg("Missing model file:", path)
    overview_rows[[model]] <- data.frame(
      model = model,
      file_name = basename(path),
      file_found = "FALSE",
      n_rows = NA_integer_,
      n_chains = NA_integer_,
      max_rhat = NA_real_,
      min_bulk_ess = NA_real_,
      n_divergences = NA_integer_,
      stringsAsFactors = FALSE
    )
    next
  }
  log_msg("Reading", basename(path))
  fit <- readRDS(path)
  d <- as.data.frame(fit$data)
  rh <- rhat(fit)
  eb <- ess_bulk(fit)
  overview_rows[[model]] <- data.frame(
    model = model,
    file_name = basename(path),
    file_found = "TRUE",
    n_rows = nrow(d),
    n_chains = n_chains_of(fit),
    max_rhat = max(rh, na.rm = TRUE),
    min_bulk_ess = min(eb, na.rm = TRUE),
    n_divergences = n_divergences_of(fit),
    stringsAsFactors = FALSE
  )
  fx <- fixef_table(fit, model)
  fixef_list[[model]] <- fx
  write_table(fx, sprintf("fixef_%s.csv", model))
  ndt <- ndt_summary_of(fit)
  ndt$model <- model
  ndt_rows[[model]] <- ndt[, c("model", "parameter", "median", "q02.5", "q97.5")]
  vectors[[model]] <- list(
    n = nrow(d),
    rt = as.numeric(d$rt),
    choice = as.integer(d$choice_binary),
    difficulty_3 = if ("difficulty_3" %in% names(d)) as.character(d$difficulty_3) else NULL,
    effort_condition = if ("effort_condition" %in% names(d)) as.character(d$effort_condition) else NULL,
    task = if ("task" %in% names(d)) as.character(d$task) else NULL,
    subject_id = if ("subject_id" %in% names(d)) as.character(d$subject_id) else NULL
  )
  if (model == "additive") {
    trial_source <- d
  }
  if (model == "baseline") {
    baseline_fit <- fit
  } else {
    rm(fit)
  }
  gc(verbose = FALSE)
}

overview <- bind_rows(overview_rows)
write_table(overview, "fit_overview.csv")
ndt_tbl <- bind_rows(ndt_rows)
write_table(ndt_tbl, "ndt_exp_intercept.csv")

same_vec <- function(a, b, field) {
  if (is.null(vectors[[a]]) || is.null(vectors[[b]])) return(FALSE)
  xa <- vectors[[a]][[field]]
  xb <- vectors[[b]][[field]]
  if (is.null(xa) || is.null(xb)) return(FALSE)
  identical(xa, xb)
}

loaded <- MODEL_ORDER[vapply(MODEL_ORDER, function(m) !is.null(vectors[[m]]), logical(1))]
present_four <- length(loaded) == 4L
ns <- vapply(MODEL_ORDER, function(m) {
  if (is.null(vectors[[m]])) NA_integer_ else vectors[[m]]$n
}, integer(1))

all_same_nrow <- isTRUE(present_four) && length(unique(stats::na.omit(ns))) == 1L
all_same_rt <- isTRUE(present_four) && all(vapply(MODEL_ORDER[-1], function(m) {
  same_vec(MODEL_ORDER[[1]], m, "rt")
}, logical(1)))
all_same_choice <- isTRUE(present_four) && all(vapply(MODEL_ORDER[-1], function(m) {
  same_vec(MODEL_ORDER[[1]], m, "choice")
}, logical(1)))

trio <- c("baseline", "additive", "interaction")
trio_loaded <- all(trio %in% loaded)
trio_same_nrow <- isTRUE(trio_loaded) && length(unique(ns[trio])) == 1L
trio_same_rt <- isTRUE(trio_loaded) && same_vec("baseline", "additive", "rt") &&
  same_vec("baseline", "interaction", "rt")
trio_same_choice <- isTRUE(trio_loaded) && same_vec("baseline", "additive", "choice") &&
  same_vec("baseline", "interaction", "choice")

identity <- data.frame(
  check = c(
    "all_four_files_present",
    "all_four_same_nrow",
    "all_four_identical_rt",
    "all_four_identical_choice_binary",
    "baseline_additive_interaction_same_nrow",
    "baseline_additive_interaction_identical_rt",
    "baseline_additive_interaction_identical_choice_binary",
    "additive_vs_interaction_identical_difficulty_3",
    "additive_vs_interaction_identical_effort_condition",
    "additive_vs_interaction_identical_task",
    "additive_vs_interaction_identical_subject_id",
    "baseline_nrow",
    "difficultyonly_nrow",
    "additive_nrow",
    "interaction_nrow",
    "columns_in_identity_check"
  ),
  result = c(
    tf_chr(present_four),
    tf_chr(all_same_nrow),
    tf_chr(all_same_rt),
    tf_chr(all_same_choice),
    tf_chr(trio_same_nrow),
    tf_chr(trio_same_rt),
    tf_chr(trio_same_choice),
    tf_chr(same_vec("additive", "interaction", "difficulty_3")),
    tf_chr(same_vec("additive", "interaction", "effort_condition")),
    tf_chr(same_vec("additive", "interaction", "task")),
    tf_chr(same_vec("additive", "interaction", "subject_id")),
    as.character(ns[["baseline"]]),
    as.character(ns[["difficultyonly"]]),
    as.character(ns[["additive"]]),
    as.character(ns[["interaction"]]),
    "rt and choice_binary"
  ),
  stringsAsFactors = FALSE
)
write_table(identity, "data_identity.csv")

if (is.null(trial_source)) {
  stop("Additive fit is required as the trial table for pointwise joins.")
}

trials <- data.frame(
  trial_index = seq_len(nrow(trial_source)),
  rt = as.numeric(trial_source$rt),
  choice_binary = as.integer(trial_source$choice_binary),
  difficulty_3 = as.character(trial_source$difficulty_3),
  effort_condition = as.character(trial_source$effort_condition),
  task = as.character(trial_source$task),
  subject_id = as.character(trial_source$subject_id),
  stringsAsFactors = FALSE
)
rm(trial_source)
gc(verbose = FALSE)

# ---- 2. LOO: reuse or compute ----------------------------------------------

load_loo_obj <- function(path) {
  log_msg("Reading LOO", path, sprintf("(%.1f MB)", file.info(path)$size / 1024^2))
  readRDS(path)
}

compute_loo <- function(fit, model) {
  n_cores <- max(1L, min(4L, parallel::detectCores() - 1L))
  log_msg("Computing loo() for", model, "with cores =", n_cores)
  t0 <- Sys.time()
  obj <- tryCatch(
    brms::loo(fit, cores = n_cores, save_psis = FALSE, use_stored = FALSE),
    error = function(e) {
      log_msg("Parallel loo() failed:", conditionMessage(e), "| retrying cores = 1")
      brms::loo(fit, cores = 1L, save_psis = FALSE, use_stored = FALSE)
    }
  )
  mins <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  out_rds <- file.path(OUT_DIR, sprintf("loo_%s.rds", model))
  saveRDS(obj, out_rds)
  log_msg("Saved", out_rds, sprintf("in %.1f min", mins))
  list(obj = obj, path = out_rds, source = "computed", elapsed_min = mins)
}

loo_objs <- list()
loo_meta <- list()

if (!is.null(baseline_fit)) {
  saved <- find_saved_loo("baseline")
  use_saved <- FALSE
  if (!is.na(saved)) {
    obj <- load_loo_obj(saved)
    n_loo <- length(pareto_k_vec(obj))
    if (identical(n_loo, vectors$baseline$n)) {
      use_saved <- TRUE
      loo_objs$baseline <- obj
      loo_meta$baseline <- list(
        path = saved, source = "reused", elapsed_min = NA_real_, n = n_loo
      )
    } else {
      log_msg(
        "Saved baseline LOO has", n_loo, "rows; fit has", vectors$baseline$n,
        ". Recomputing."
      )
      rm(obj)
    }
  }
  if (!use_saved) {
    computed <- compute_loo(baseline_fit, "baseline")
    loo_objs$baseline <- computed$obj
    loo_meta$baseline <- list(
      path = computed$path,
      source = "computed",
      elapsed_min = computed$elapsed_min,
      n = length(pareto_k_vec(computed$obj))
    )
  }
  rm(baseline_fit)
  gc(verbose = FALSE)
}

for (model in c("difficultyonly", "additive", "interaction")) {
  saved <- find_saved_loo(model)
  if (is.na(saved)) {
    if (is.null(vectors[[model]])) {
      log_msg("No fit and no saved LOO for", model)
      next
    }
    stop("No saved LOO for ", model, " and the fit was already released. This is a script bug.")
  }
  obj <- load_loo_obj(saved)
  n_loo <- length(pareto_k_vec(obj))
  n_fit <- if (is.null(vectors[[model]])) NA_integer_ else vectors[[model]]$n
  matches <- isTRUE(!is.na(n_fit) && n_loo == n_fit)
  loo_objs[[model]] <- obj
  loo_meta[[model]] <- list(
    path = saved,
    source = if (matches) "reused" else "reused_n_mismatch",
    elapsed_min = NA_real_,
    n = n_loo,
    matches_fit = matches
  )
  if (!matches) {
    log_msg(
      "LOO/fit observation mismatch for", model,
      ": loo n =", n_loo, ", fit n =", n_fit,
      ". Pointwise comparison against this object will not be forced."
    )
  }
  rm(obj)
  gc(verbose = FALSE)
}

loo_rows <- list()
for (model in MODEL_ORDER) {
  meta <- loo_meta[[model]]
  obj <- loo_objs[[model]]
  if (is.null(obj)) {
    loo_rows[[model]] <- data.frame(
      model = model,
      loo_file = NA_character_,
      loo_source = "absent",
      fit_n = ns[[model]],
      loo_n = NA_integer_,
      loo_matches_fit = "FALSE",
      elpd_loo = NA_real_,
      se = NA_real_,
      pareto_k_gt_0.5_le_0.7 = NA_integer_,
      pareto_k_gt_0.7_le_1 = NA_integer_,
      pareto_k_gt_1 = NA_integer_,
      loo_elapsed_min = NA_real_,
      stringsAsFactors = FALSE
    )
    next
  }
  est <- loo_elpd(obj)
  pk <- pareto_counts(pareto_k_vec(obj))
  matches <- isTRUE(meta$matches_fit %||% (meta$source == "reused" || meta$source == "computed"))
  if (model == "baseline" && meta$source %in% c("reused", "computed")) {
    matches <- isTRUE(pk[["n"]] == ns[[model]])
  }
  loo_rows[[model]] <- data.frame(
    model = model,
    loo_file = basename(meta$path),
    loo_source = meta$source,
    fit_n = ns[[model]],
    loo_n = as.integer(pk[["n"]]),
    loo_matches_fit = tf_chr(matches),
    elpd_loo = est[["elpd_loo"]],
    se = est[["se"]],
    pareto_k_gt_0.5_le_0.7 = as.integer(pk[["k_gt_0.5_le_0.7"]]),
    pareto_k_gt_0.7_le_1 = as.integer(pk[["k_gt_0.7_le_1"]]),
    pareto_k_gt_1 = as.integer(pk[["k_gt_1"]]),
    loo_elapsed_min = meta$elapsed_min,
    stringsAsFactors = FALSE
  )
}
loo_summary <- bind_rows(loo_rows)
write_table(loo_summary, "loo_summary.csv")

comparable <- loo_summary$model[loo_summary$loo_matches_fit == "TRUE"]
scope_rows <- lapply(MODEL_ORDER, function(model) {
  row <- loo_summary[loo_summary$model == model, ]
  included <- model %in% comparable
  reason <- if (included) {
    sprintf("LOO and fit both have %s observations", row$fit_n)
  } else if (row$loo_source == "absent") {
    "No LOO object is available."
  } else if (is.na(row$fit_n)) {
    sprintf(
      "brmsfit file is missing. Saved LOO has %s observations, so loo_compare cannot align it to the other models.",
      row$loo_n
    )
  } else {
    sprintf(
      "Saved LOO has %s observations and the fit has %s. loo_compare requires equal observation counts.",
      row$loo_n, row$fit_n
    )
  }
  data.frame(
    model = model,
    included_in_loo_compare = tf_chr(included),
    reason = reason,
    stringsAsFactors = FALSE
  )
})
loo_scope <- bind_rows(scope_rows)
write_table(loo_scope, "loo_compare_scope.csv")

if (length(comparable) < 2) {
  stop("Fewer than two LOO objects share the fit observation count; loo_compare cannot run.")
}
compare_list <- loo_objs[comparable]
cmp <- loo::loo_compare(compare_list)
cmp_df <- as.data.frame(cmp)
cmp_df$model <- rownames(cmp_df)
cmp_df <- cmp_df[, c("model", setdiff(names(cmp_df), "model")), drop = FALSE]
rownames(cmp_df) <- NULL
write_table(cmp_df, "loo_compare.csv")
log_msg("loo_compare models:", paste(cmp_df$model, collapse = ", "))

# ---- 3. Pointwise forensics ------------------------------------------------

build_pointwise <- function(loo_a, loo_b, name_a, name_b, trials) {
  ka <- pareto_k_vec(loo_a)
  kb <- pareto_k_vec(loo_b)
  ea <- as.numeric(loo_a$pointwise[, "elpd_loo"])
  eb <- as.numeric(loo_b$pointwise[, "elpd_loo"])
  n <- nrow(trials)
  if (!all(c(length(ka), length(kb), length(ea), length(eb)) == n)) {
    stop(sprintf(
      "Pointwise length mismatch for %s - %s: trials=%d, loo lengths=%s",
      name_a, name_b, n,
      paste(c(length(ea), length(eb), length(ka), length(kb)), collapse = ",")
    ))
  }
  out <- trials
  out[[paste0("elpd_", name_a)]] <- ea
  out[[paste0("elpd_", name_b)]] <- eb
  out$elpd_diff <- ea - eb
  out[[paste0("pareto_k_", name_a)]] <- ka
  out[[paste0("pareto_k_", name_b)]] <- kb
  out
}

contrast_tables <- function(pw, contrast_name) {
  total_signed <- sum(pw$elpd_diff)
  total_abs <- sum(abs(pw$elpd_diff))
  check <- data.frame(
    contrast = contrast_name,
    n_trials = nrow(pw),
    sum_elpd_diff = total_signed,
    sum_abs_elpd_diff = total_abs,
    stringsAsFactors = FALSE
  )

  cond <- pw %>%
    mutate(
      difficulty_3 = factor(difficulty_3, levels = c("Standard", "Hard", "Easy")),
      effort_condition = factor(effort_condition, levels = c("low", "high")),
      task = factor(task, levels = c("ADT", "VDT"))
    ) %>%
    group_by(difficulty_3, effort_condition, task, .drop = FALSE) %>%
    summarise(
      n_trials = n(),
      sum_elpd_diff = sum(elpd_diff),
      mean_elpd_diff = mean(elpd_diff),
      .groups = "drop"
    ) %>%
    mutate(
      share_of_signed_total = sum_elpd_diff / total_signed,
      share_of_abs_total = NA_real_
    ) %>%
    arrange(task, effort_condition, difficulty_3)
  # Absolute share uses the grouped sum of absolute differences, not |grouped sum|.
  abs_by_cell <- pw %>%
    mutate(
      difficulty_3 = factor(difficulty_3, levels = c("Standard", "Hard", "Easy")),
      effort_condition = factor(effort_condition, levels = c("low", "high")),
      task = factor(task, levels = c("ADT", "VDT"))
    ) %>%
    group_by(difficulty_3, effort_condition, task, .drop = FALSE) %>%
    summarise(sum_abs_elpd_diff = sum(abs(elpd_diff)), .groups = "drop")
  cond <- cond %>%
    left_join(abs_by_cell, by = c("difficulty_3", "effort_condition", "task")) %>%
    mutate(share_of_abs_total = sum_abs_elpd_diff / total_abs)

  pw$rt_decile <- dplyr::ntile(pw$rt, 10)
  dec <- pw %>%
    group_by(rt_decile) %>%
    summarise(
      n_trials = n(),
      rt_min = min(rt),
      rt_max = max(rt),
      sum_elpd_diff = sum(elpd_diff),
      mean_elpd_diff = mean(elpd_diff),
      sum_abs_elpd_diff = sum(abs(elpd_diff)),
      .groups = "drop"
    ) %>%
    mutate(
      share_of_signed_total = sum_elpd_diff / total_signed,
      share_of_abs_total = sum_abs_elpd_diff / total_abs
    ) %>%
    arrange(rt_decile)

  ord <- order(-abs(pw$elpd_diff), pw$trial_index)
  share_rows <- lapply(c(20L, 50L, 100L), function(k) {
    idx <- ord[seq_len(k)]
    data.frame(
      n_trials = k,
      sum_elpd_diff_in_subset = sum(pw$elpd_diff[idx]),
      sum_abs_elpd_diff_in_subset = sum(abs(pw$elpd_diff[idx])),
      total_signed_elpd_diff = total_signed,
      total_abs_elpd_diff = total_abs,
      share_of_signed_total = sum(pw$elpd_diff[idx]) / total_signed,
      share_of_abs_total = sum(abs(pw$elpd_diff[idx])) / total_abs,
      stringsAsFactors = FALSE
    )
  })
  shares <- bind_rows(share_rows)

  top <- pw[ord[seq_len(20)], ]
  top$rank <- seq_len(20)
  pareto_cols <- grep("^pareto_k_", names(top), value = TRUE)
  elpd_cols <- setdiff(grep("^elpd_", names(top), value = TRUE), "elpd_diff")
  top <- top[, c(
    "rank", "trial_index", "subject_id", "task", "effort_condition", "difficulty_3",
    "rt", "choice_binary", "elpd_diff", pareto_cols, elpd_cols
  ), drop = FALSE]

  list(check = check, condition = cond, decile = dec, shares = shares, top20 = top, pw = pw)
}

log_msg("Building interaction - additive pointwise contrast")
pw_ia <- build_pointwise(
  loo_objs$interaction, loo_objs$additive,
  "interaction", "additive", trials
)
ia <- contrast_tables(pw_ia, "interaction_minus_additive")
# Confirm the pointwise sum equals the difference of elpd estimates.
elpd_gap <- loo_elpd(loo_objs$interaction)[["elpd_loo"]] - loo_elpd(loo_objs$additive)[["elpd_loo"]]
ia$check$elpd_estimate_difference <- elpd_gap
ia$check$pointwise_minus_estimate <- ia$check$sum_elpd_diff - elpd_gap
if (abs(ia$check$pointwise_minus_estimate) > 0.05) {
  log_msg(
    "WARNING: pointwise ELPD sum differs from the elpd estimates by",
    ia$check$pointwise_minus_estimate
  )
}

write_table(ia$pw, "pointwise_interaction_minus_additive.csv")
write_table(ia$condition, "sum_by_condition_interaction_minus_additive.csv")
write_table(ia$decile, "sum_by_rt_decile_interaction_minus_additive.csv")
write_table(ia$shares, "influence_share_interaction_minus_additive.csv")
write_table(ia$top20, "top20_interaction_minus_additive.csv")
write_table(ia$check, "pointwise_total_check_interaction_minus_additive.csv")

diff_status <- loo_summary[loo_summary$model == "difficultyonly", ]
diff_reason <- if (diff_status$loo_source == "absent") {
  "No difficulty-only LOO object is available."
} else if (is.na(diff_status$fit_n)) {
  sprintf(
    paste(
      "The difficulty-only brmsfit file is absent, so loo() cannot be recomputed",
      "without refitting. The saved LOO object has %s pointwise values and the",
      "additive fit has %s trials. Those vectors cannot be joined or passed to",
      "loo_compare. No model was refit."
    ),
    diff_status$loo_n, loo_summary$fit_n[loo_summary$model == "additive"]
  )
} else if (diff_status$loo_matches_fit != "TRUE") {
  sprintf(
    "Saved difficulty-only LOO has %s rows and its fit has %s. Pointwise alignment was not forced.",
    diff_status$loo_n, diff_status$fit_n
  )
} else {
  "Difficulty-only LOO matches its fit; the contrast should have been computed."
}

diff_only_computed <- isTRUE(diff_status$loo_matches_fit == "TRUE") &&
  !is.null(loo_objs$difficultyonly) &&
  !is.null(loo_objs$additive)

if (diff_only_computed) {
  log_msg("Building additive - difficultyonly pointwise contrast")
  pw_ad <- build_pointwise(
    loo_objs$additive, loo_objs$difficultyonly,
    "additive", "difficultyonly", trials
  )
  ad <- contrast_tables(pw_ad, "additive_minus_difficultyonly")
  write_table(ad$pw, "pointwise_additive_minus_difficultyonly.csv")
  write_table(ad$condition, "sum_by_condition_additive_minus_difficultyonly.csv")
  write_table(ad$decile, "sum_by_rt_decile_additive_minus_difficultyonly.csv")
  write_table(ad$shares, "influence_share_additive_minus_difficultyonly.csv")
  write_table(ad$top20, "top20_additive_minus_difficultyonly.csv")
  write_table(ad$check, "pointwise_total_check_additive_minus_difficultyonly.csv")
} else {
  ad <- NULL
  log_msg("Skipping additive - difficultyonly pointwise contrast.", diff_reason)
}

status_ad <- data.frame(
  contrast = "additive_minus_difficultyonly",
  computed = tf_chr(diff_only_computed),
  reason = diff_reason,
  stringsAsFactors = FALSE
)
write_table(status_ad, "additive_minus_difficultyonly_status.csv")

# ---- 4. Interaction effort x difficulty terms ------------------------------

fx_int <- fixef_list$interaction
if (is.null(fx_int)) stop("Interaction fixef table is missing.")
term <- fx_int$term
drift_idx <- grepl("effort_condition.*:difficulty_3", term) &
  !grepl("^(bs_|ndt_|bias_)", term)
bs_idx <- grepl("^bs_effort_condition.*:difficulty_3", term)
int_terms <- fx_int[drift_idx | bs_idx, ]
int_terms$dpar <- ifelse(grepl("^bs_", int_terms$term), "bs", "drift")
int_terms$link <- ifelse(int_terms$dpar == "bs", "log", "identity")
int_terms$cri_excludes_0 <- (int_terms$Q2.5 > 0) | (int_terms$Q97.5 < 0)
int_terms <- int_terms[, c(
  "model", "dpar", "link", "term", "Estimate", "Est.Error", "Q2.5", "Q97.5", "cri_excludes_0"
)]
write_table(int_terms, "interaction_effort_difficulty_terms.csv")

# Release the large additive PSIS weights before moment matching.
rm(loo_objs)
gc(verbose = FALSE)

# ---- markdown --------------------------------------------------------------

largest_abs_row <- function(df, value_col) {
  df[which.max(abs(df[[value_col]])), , drop = FALSE]
}

build_summary <- function(mm) {
  n_shared <- overview$n_rows[overview$model == "additive"]
  line1 <- sprintf(
    paste0(
      "All four fits use identical data: %s. ",
      "Baseline, additive, and interaction have the same nrow (%s) and identical rt and choice_binary vectors: %s. ",
      "The difficulty-only brmsfit file is %s; its saved LOO object has %s pointwise values."
    ),
    tf_chr(all_same_nrow && all_same_rt && all_same_choice),
    format(n_shared, scientific = FALSE, trim = TRUE),
    tf_chr(trio_same_nrow && trio_same_rt && trio_same_choice),
    if (overview$file_found[overview$model == "difficultyonly"] == "TRUE") "present" else "absent",
    ifelse(is.na(diff_status$loo_n), "no", format(diff_status$loo_n, scientific = FALSE, trim = TRUE))
  )

  pk_phrase <- function(model) {
    row <- loo_summary[loo_summary$model == model, ]
    sprintf(
      "%s %s (SE %s; Pareto-k in (0.5, 0.7] / (0.7, 1] / >1: %s/%s/%s)",
      model, fmt2(row$elpd_loo), fmt2(row$se),
      row$pareto_k_gt_0.5_le_0.7, row$pareto_k_gt_0.7_le_1, row$pareto_k_gt_1
    )
  }
  cmp_phrase <- paste(sprintf(
    "%s elpd_diff %s (SE %s)",
    cmp_df$model, fmt2(cmp_df$elpd_diff), fmt2(cmp_df$se_diff)
  ), collapse = "; ")
  line2 <- sprintf(
    "On the shared trials, %s; %s; %s. loo_compare (%s) gives %s. The saved difficulty-only LOO is excluded from that comparison.",
    pk_phrase("interaction"), pk_phrase("additive"), pk_phrase("baseline"),
    paste(comparable, collapse = ", "), cmp_phrase
  )

  cell <- largest_abs_row(ia$condition, "sum_elpd_diff")
  dec <- largest_abs_row(ia$decile, "sum_elpd_diff")
  line3 <- sprintf(
    paste0(
      "The interaction minus additive pointwise ELPD sum is %s. ",
      "The largest condition sum is %s / %s effort / %s (sum %s, n = %s). ",
      "The largest RT-decile sum is decile %s, RT %s to %s s (sum %s); decile 1 is the fastest tenth."
    ),
    fmt2(ia$check$sum_elpd_diff),
    as.character(cell$difficulty_3), as.character(cell$effort_condition), as.character(cell$task),
    fmt2(cell$sum_elpd_diff), format(cell$n_trials, scientific = FALSE, trim = TRUE),
    dec$rt_decile, fmt4(dec$rt_min), fmt4(dec$rt_max), fmt2(dec$sum_elpd_diff)
  )

  sh <- ia$shares
  share_txt <- function(k) {
    row <- sh[sh$n_trials == k, ]
    sprintf("%s trials %s%%", k, fmt2(100 * row$share_of_abs_total))
  }
  top1 <- ia$top20[1, ]
  line4 <- sprintf(
    paste0(
      "Share of the sum of absolute pointwise ELPD differences from the trials with the largest absolute differences: %s, %s, and %s. ",
      "Signed shares of the net difference for those same trials are %s%%, %s%%, and %s%%. ",
      "The largest absolute difference is trial %s (%s, %s, %s effort, %s, RT %s s, choice %s): elpd_diff %s, interaction Pareto-k %s, additive Pareto-k %s."
    ),
    share_txt(20), share_txt(50), share_txt(100),
    fmt2(100 * sh$share_of_signed_total[sh$n_trials == 20]),
    fmt2(100 * sh$share_of_signed_total[sh$n_trials == 50]),
    fmt2(100 * sh$share_of_signed_total[sh$n_trials == 100]),
    top1$trial_index, top1$subject_id, top1$task, top1$effort_condition, top1$difficulty_3,
    fmt4(top1$rt), top1$choice_binary, fmt2(top1$elpd_diff),
    fmt4(top1$pareto_k_interaction), fmt4(top1$pareto_k_additive)
  )

  term_txt <- paste(sprintf(
    "%s (%s) %s [%s, %s]",
    int_terms$term, int_terms$dpar, fmt4(int_terms$Estimate),
    fmt4(int_terms$Q2.5), fmt4(int_terms$Q97.5)
  ), collapse = "; ")
  excl <- int_terms$term[int_terms$cri_excludes_0]
  incl <- int_terms$term[!int_terms$cri_excludes_0]
  cri_txt <- paste0(
    if (length(excl)) paste0("CrIs excluding zero: ", paste(excl, collapse = ", "), ". ") else "",
    if (length(incl)) paste0("CrIs including zero: ", paste(incl, collapse = ", "), ". ") else ""
  )
  mm_txt <- mm$summary_sentence
  line5 <- paste0(term_txt, ". ", cri_txt, mm_txt)
  c(line1, line2, line3, line4, line5)
}

section <- function(title, df) {
  c(paste0("## ", title), "", md_table(df), "")
}

render_md <- function(mm) {
  lines <- c(
    "# LOO forensics",
    "",
    sprintf("Run: `%s`", RUN_DIR),
    sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "This script did not refit any model and did not write into the run directory.",
    "",
    "## Five-line summary",
    "",
    build_summary(mm),
    "",
    section("1. Fit diagnostics", overview),
    section("1b. Identical-data check", identity),
    "Identity checks compare `rt` and `choice_binary` in fit$data row order. Baseline data has no `difficulty_3` column. The covariate checks below are only between additive and interaction, which supply the pointwise join.",
    "",
    section("1c. Fixed effects: baseline", fixef_list$baseline),
    section("1c. Fixed effects: additive", fixef_list$additive),
    section("1c. Fixed effects: interaction", fixef_list$interaction),
    "The difficulty-only brmsfit file is absent, so there is no `fixef()` table for it.",
    "",
    section("1d. Posterior of exp(Intercept_ndt)", ndt_tbl),
    "`Intercept_ndt` is the log non-decision time. The table reports the posterior median and the 2.5% and 97.5% quantiles of `exp(Intercept_ndt)`.",
    "",
    section("2. LOO estimates and Pareto-k counts", loo_summary),
    "Pareto-k bins are (0.5, 0.7], (0.7, 1], and >1. `loo_matches_fit` is TRUE when the saved or computed LOO has one value per row of that model's `fit$data`.",
    "",
    section("2b. Models entered in loo_compare", loo_scope),
    section("2c. loo_compare", cmp_df),
    "`elpd_diff` is relative to the model in the first row. Negative values are worse than that model.",
    "",
    section("3. Interaction minus additive: total", ia$check),
    "Positive `elpd_diff` means the interaction model has the higher pointwise ELPD on that trial. RT decile 1 is the fastest tenth of trials (`dplyr::ntile`).",
    "",
    section("3a. Sum of ELPD differences by difficulty x effort x task", ia$condition),
    section("3b. Sum of ELPD differences by RT decile", ia$decile),
    section("3c. Share from the trials with the largest absolute difference", ia$shares),
    "`share_of_abs_total` is the share of the sum of absolute pointwise differences. `share_of_signed_total` is the share of the net sum.",
    "",
    section("3d. Top 20 trials by absolute ELPD difference", ia$top20),
    "The full trial-level join is `pointwise_interaction_minus_additive.csv` (one row per trial). It is not inlined here.",
    "",
    section("3e. Additive minus difficulty-only", status_ad)
  )
  if (!is.null(ad)) {
    lines <- c(
      lines,
      section("3e1. Additive minus difficulty-only by condition", ad$condition),
      section("3e2. Additive minus difficulty-only by RT decile", ad$decile),
      section("3e3. Additive minus difficulty-only influence share", ad$shares),
      section("3e4. Additive minus difficulty-only top 20 trials", ad$top20)
    )
  }
  lines <- c(
    lines,
    "",
    section("4. Interaction effort x difficulty terms", int_terms),
    "Drift coefficients are on the identity scale. Boundary-separation (`bs`) coefficients are on the log scale.",
    "",
    section("5. Optional loo_moment_match on the interaction model", mm$table),
    mm$note,
    "",
    sprintf(
      "Packages: brms %s, loo %s, posterior %s, R %s.",
      as.character(packageVersion("brms")),
      as.character(packageVersion("loo")),
      as.character(packageVersion("posterior")),
      paste(R.version$major, R.version$minor, sep = ".")
    ),
    ""
  )
  writeLines(lines, MD_FILE)
  log_msg("Wrote", MD_FILE)
}

mm_pending <- list(
  table = data.frame(
    status = "not_started",
    elapsed_min = NA_real_,
    elpd_loo_before = loo_summary$elpd_loo[loo_summary$model == "interaction"],
    se_before = loo_summary$se[loo_summary$model == "interaction"],
    elpd_loo_after = NA_real_,
    se_after = NA_real_,
    delta_elpd = NA_real_,
    pareto_k_gt_0.5_le_0.7 = NA_integer_,
    pareto_k_gt_0.7_le_1 = NA_integer_,
    pareto_k_gt_1 = NA_integer_,
    n_obs = NA_integer_,
    message = "Moment matching has not been started.",
    stringsAsFactors = FALSE
  ),
  note = "The required tables above were written before the optional moment-matching step.",
  summary_sentence = "loo_moment_match had not finished when this summary was written."
)
write_table(mm_pending$table, "moment_match.csv")
render_md(mm_pending)

# ---- 5. Optional moment matching, 60 minute cap ----------------------------

run_moment_match <- function() {
  n_bad <- loo_summary$pareto_k_gt_0.7_le_1[loo_summary$model == "interaction"] +
    loo_summary$pareto_k_gt_1[loo_summary$model == "interaction"]
  before <- loo_summary$elpd_loo[loo_summary$model == "interaction"]
  se_before <- loo_summary$se[loo_summary$model == "interaction"]
  base_tbl <- function(status, elapsed, message, after = NA_real_, se_after = NA_real_, pk = NULL) {
    if (is.null(pk)) {
      pk <- c(n = NA_integer_, a = NA_integer_, b = NA_integer_, c = NA_integer_)
    }
    data.frame(
      status = status,
      elapsed_min = elapsed,
      elpd_loo_before = before,
      se_before = se_before,
      elpd_loo_after = after,
      se_after = se_after,
      delta_elpd = after - before,
      pareto_k_gt_0.5_le_0.7 = pk[["a"]],
      pareto_k_gt_0.7_le_1 = pk[["b"]],
      pareto_k_gt_1 = pk[["c"]],
      n_obs = pk[["n"]],
      message = message,
      stringsAsFactors = FALSE
    )
  }
  if (!is.finite(n_bad) || n_bad <= 0) {
    return(list(
      table = base_tbl("skipped", 0, "No interaction Pareto-k exceeds 0.7, so moment matching was skipped."),
      note = "Moment matching was skipped because no Pareto-k exceeded 0.7.",
      summary_sentence = "loo_moment_match was skipped because no interaction Pareto-k exceeded 0.7."
    ))
  }

  fit_path <- MODEL_FILE("interaction")
  loo_path <- find_saved_loo("interaction")
  out_rds <- file.path(OUT_DIR, "loo_interaction_moment_match.rds")
  if (file.exists(out_rds)) unlink(out_rds)
  worker <- file.path(OUT_DIR, "moment_match_worker.R")
  worker_log <- file.path(OUT_DIR, "moment_match.log")
  writeLines(c(
    "suppressPackageStartupMessages({library(brms); library(loo)})",
    sprintf("fit <- readRDS(%s)", deparse(fit_path, width.cutoff = 500)),
    sprintf("lw <- readRDS(%s)", deparse(loo_path, width.cutoff = 500)),
    "run_mm <- function(check) {",
    "  brms::loo_moment_match(fit, loo = lw, k_threshold = 0.7, check = check, recompile = FALSE)",
    "}",
    "mm <- tryCatch(run_mm(TRUE), error = function(e) {",
    "  msg <- conditionMessage(e)",
    "  if (grepl(\"Response values used in 'loo'\", msg, fixed = FALSE) &&",
    "      length(lw$diagnostics$pareto_k) == nrow(fit$data)) {",
    "    message('yhash check failed; retrying with check = FALSE')",
    "    run_mm(FALSE)",
    "  } else {",
    "    stop(e)",
    "  }",
    "})",
    sprintf("saveRDS(mm, %s)", deparse(out_rds, width.cutoff = 500)),
    "cat('MOMENT_MATCH_OK\\n')"
  ), worker)

  cmd <- sprintf(
    "Rscript --vanilla %s > %s 2>&1 & echo $!",
    shQuote(worker), shQuote(worker_log)
  )
  shell_out <- tryCatch(system(cmd, intern = TRUE), error = function(e) character())
  pid_chr <- shell_out[grepl("^[0-9]+$", shell_out)]
  pid <- if (length(pid_chr)) as.integer(tail(pid_chr, 1)) else NA_integer_
  if (is.na(pid)) {
    return(list(
      table = base_tbl("failed", NA_real_, "Could not start the moment-matching process."),
      note = "Moment matching did not start.",
      summary_sentence = "loo_moment_match did not start."
    ))
  }
  log_msg("Moment matching PID", pid, "(60 minute cap)")
  alive <- function() system(sprintf("ps -p %d >/dev/null 2>&1", pid)) == 0
  t0 <- Sys.time()
  limit_sec <- 60 * 60
  repeat {
    if (!alive()) break
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (elapsed > limit_sec) {
      log_msg("Moment matching exceeded 60 minutes; stopping PID", pid)
      system(sprintf("pkill -P %d >/dev/null 2>&1; kill %d >/dev/null 2>&1", pid, pid))
      Sys.sleep(2)
      if (alive()) {
        system(sprintf("kill -9 %d >/dev/null 2>&1", pid))
      }
      mins <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
      return(list(
        table = base_tbl(
          "exceeded_60_min", mins,
          "Stopped after 60 minutes without a returned LOO object."
        ),
        note = "loo_moment_match was stopped because it exceeded 60 minutes.",
        summary_sentence = "loo_moment_match was stopped after 60 minutes and did not return an updated elpd."
      ))
    }
    Sys.sleep(20)
  }
  mins <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  if (!file.exists(out_rds)) {
    tail_lines <- if (file.exists(worker_log)) readLines(worker_log, warn = FALSE) else character()
    err <- paste(tail(tail_lines, 20), collapse = " ")
    if (!nzchar(err)) err <- "Moment matching exited without writing a LOO object."
    err_line <- tail_lines[grepl("^Error", tail_lines)]
    err_line <- if (length(err_line)) gsub("\\s+", " ", err_line[[1]]) else substr(gsub("\\s+", " ", err), 1, 240)
    return(list(
      table = base_tbl("failed", mins, substr(gsub("\\s+", " ", err), 1, 2000)),
      note = paste(
        "loo_moment_match failed. The worker log is moment_match.log.",
        "brms may recompile a temporary Stan model while moment matching.",
        "The original interaction rds was not overwritten and the model was not refit."
      ),
      summary_sentence = paste0(
        "loo_moment_match failed and returned no updated elpd; the saved brmsfit was not modified. ",
        err_line
      )
    ))
  }
  mm <- readRDS(out_rds)
  est <- loo_elpd(mm)
  pk <- pareto_counts(pareto_k_vec(mm))
  pk_named <- c(n = pk[["n"]], a = pk[["k_gt_0.5_le_0.7"]], b = pk[["k_gt_0.7_le_1"]], c = pk[["k_gt_1"]])
  sentence <- sprintf(
    "loo_moment_match finished in %s min. Updated elpd_loo is %s (SE %s), a change of %s. Updated Pareto-k counts in (0.5, 0.7] / (0.7, 1] / >1 are %s/%s/%s.",
    fmt2(mins), fmt2(est[["elpd_loo"]]), fmt2(est[["se"]]), fmt2(est[["elpd_loo"]] - before),
    pk_named[["a"]], pk_named[["b"]], pk_named[["c"]]
  )
  list(
    table = base_tbl(
      "success", mins, "Completed within 60 minutes.",
      after = est[["elpd_loo"]], se_after = est[["se"]], pk = pk_named
    ),
    note = "Moment matching used k_threshold = 0.7 and recompile = FALSE. The original brmsfit file was not modified.",
    summary_sentence = sentence
  )
}

log_msg("Starting optional moment matching")
mm_done <- tryCatch(
  run_moment_match(),
  error = function(e) {
    list(
      table = data.frame(
        status = "failed",
        elapsed_min = NA_real_,
        elpd_loo_before = loo_summary$elpd_loo[loo_summary$model == "interaction"],
        se_before = loo_summary$se[loo_summary$model == "interaction"],
        elpd_loo_after = NA_real_,
        se_after = NA_real_,
        delta_elpd = NA_real_,
        pareto_k_gt_0.5_le_0.7 = NA_integer_,
        pareto_k_gt_0.7_le_1 = NA_integer_,
        pareto_k_gt_1 = NA_integer_,
        n_obs = NA_integer_,
        message = substr(conditionMessage(e), 1, 2000),
        stringsAsFactors = FALSE
      ),
      note = "Moment matching raised an error in the parent process.",
      summary_sentence = paste0("loo_moment_match failed: ", conditionMessage(e))
    )
  }
)
write_table(mm_done$table, "moment_match.csv")
render_md(mm_done)
log_msg("Done. Markdown:", MD_FILE)
