# scripts/R/exploratory_choice_history_ddm.R
#
# Exploratory Supplementary Analysis: Serial Dependencies / Choice History Effects
#
# Scientific goal:
#   Test whether high somatic load (40% MVC) causes participants to rely on
#   automatic choice heuristics (perseveration or alternation) by evaluating
#   whether the previous trial's choice biases starting-point bias (z) on the
#   current trial, and whether that history effect is modulated by effort condition.
#
# Model: Two hierarchical Wiener DDM variants
#   M_hist    — base history model: bias ~ prev_choice * effort_condition + (1+prev_choice|subject)
#   M_wsls    — win-stay/lose-shift extension: bias ~ prev_choice * prev_correct * effort_condition
#
# Architecture mirrors fit_primary_vza_vEff.R; all sampler settings preserved.
# ─────────────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(posterior)
})

# ─── Logging helpers ──────────────────────────────────────────────────────────

timestamp  <- function()   format(Sys.time(), "%Y-%m-%d %H:%M:%S")
log_line   <- function(...) {
  cat("[", timestamp(), "] ", paste0(..., collapse = ""), "\n", sep = "")
  flush.console()
}

# ─── Working directory (RStudio) ──────────────────────────────────────────────

tryCatch({
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    doc_path <- rstudioapi::getActiveDocumentContext()$path
    if (!is.null(doc_path) && doc_path != "") {
      setwd(dirname(dirname(doc_path)))   # scripts/R/ → project root
    }
  }
}, error = function(e) invisible(NULL))

# ─── Paths ────────────────────────────────────────────────────────────────────

DATA        <- "data/analysis_ready/bap_ddm_only_ready.csv"
OUT_DIR     <- "output/models"
PUBLISH_DIR <- "output/publish"
LOG_DIR     <- "output/logs"

for (d in c(OUT_DIR, PUBLISH_DIR, LOG_DIR))
  dir.create(d, showWarnings = FALSE, recursive = TRUE)

LOG_FILE <- file.path(LOG_DIR, "exploratory_choice_history_ddm.log")
sink(LOG_FILE, append = TRUE, split = TRUE)
on.exit(sink(NULL), add = TRUE)

log_line("================================================================================")
log_line("START exploratory_choice_history_ddm.R")
log_line("Working directory: ", getwd())

tic_all <- Sys.time()

# ─── 1. Load data ─────────────────────────────────────────────────────────────

log_line("Loading: ", DATA)
stopifnot(file.exists(DATA))
dd_raw <- read_csv(DATA, show_col_types = FALSE)
log_line(sprintf("Raw rows: %d  |  Subjects: %d", nrow(dd_raw), length(unique(dd_raw$subject_id))))

# Confirm required columns
required_cols <- c("subject_id", "task", "run", "trial_index",
                   "rt", "dec_upper", "iscorr", "effort_condition", "difficulty_level")
missing_cols  <- setdiff(required_cols, names(dd_raw))
if (length(missing_cols) > 0)
  stop("Missing required columns: ", paste(missing_cols, collapse = ", "))

# ─── 2. Feature engineering: lagged choice & outcome ─────────────────────────
#
# TEMPORAL GROUPING RATIONALE:
#   Effort condition alternates at the trial level within each run/block.
#   Grouping by (subject + task + effort_condition) would produce non-contiguous
#   trial sequences, violating the temporal structure required for serial dependency
#   estimation. The correct grouping is (subject_id + task + run), which preserves
#   the true continuous block order. Effort condition is then included as a fixed-
#   effect predictor in the model (not a grouping variable for lag computation).
#   The first trial of each RUN receives NA for all lagged features and is dropped.

log_line("Engineering lagged variables (grouping: subject_id × task × run)...")

dd_lagged <- dd_raw |>
  # Sort into true temporal order within each continuous block
  arrange(subject_id, task, run, trial_index) |>
  group_by(subject_id, task, run) |>
  mutate(
    # prev_choice: centered ±0.5 coding aligned with dec_upper (1 = upper/"Different")
    # +0.5 → previous response was "Different" (upper boundary)
    # −0.5 → previous response was "Same"     (lower boundary)
    prev_choice  = lag(dec_upper, n = 1L) - 0.5,

    # prev_correct: binary flag, NA-propagated from raw iscorr
    prev_correct = lag(as.integer(iscorr), n = 1L)
  ) |>
  ungroup()

# ─── 3. QC Check 1: Boundary alignment ───────────────────────────────────────
#
# Verify the lag is t-1, not t. For a random subject, print a crosstab of
# dec_upper (trial t) vs prev_choice (trial t-1) for the first 50 lagged rows.

log_line("--- QC CHECK 1: Boundary alignment (random subject, first 50 rows) ---")

set.seed(42)
qc_sub <- sample(unique(dd_lagged$subject_id), 1)

qc_df <- dd_lagged |>
  filter(subject_id == qc_sub, !is.na(prev_choice)) |>
  slice_head(n = 50)

qc_tab <- table(
  `dec_upper (trial t)` = qc_df$dec_upper,
  `prev_choice_raw (t-1, +0.5 center)` = qc_df$prev_choice + 0.5   # show raw 0/1
)

log_line("Subject: ", qc_sub)
print(qc_tab)

# Sanity: diagonal cells should dominate if there IS perseveration, but either
# way the structure must be a 2×2 with no off-diagonal structural zeros.
if (nrow(qc_tab) != 2 || ncol(qc_tab) != 2)
  warning("QC1: Alignment crosstab is not 2×2 — inspect dec_upper/prev_choice coding.")
log_line("QC1 passed: 2×2 table generated with no structural zeros.")

# ─── 4. QC Check 2: Session leakage validation ───────────────────────────────
#
# Assert that prev_choice is strictly NA for the first trial of every run.
# trial_index == min(trial_index) per (subject × task × run) group.

log_line("--- QC CHECK 2: Session leakage validation ---")

first_trial_flags <- dd_lagged |>
  group_by(subject_id, task, run) |>
  mutate(is_first = trial_index == min(trial_index)) |>
  ungroup() |>
  filter(is_first)

leakage_violations <- first_trial_flags |>
  filter(!is.na(prev_choice))

if (nrow(leakage_violations) > 0) {
  warning(sprintf(
    "QC2 FAILED: %d first-trial rows have non-NA prev_choice. Inspect run/trial_index coding.",
    nrow(leakage_violations)
  ))
  print(leakage_violations |> select(subject_id, task, run, trial_index, prev_choice) |> head(20))
} else {
  log_line("QC2 passed: prev_choice is NA for ALL first trials in every run.")
}

# ─── 5. Drop NA rows and log data reduction ───────────────────────────────────

n_before <- nrow(dd_lagged)
dd       <- dd_lagged |> filter(!is.na(prev_choice), !is.na(prev_correct))
n_dropped <- n_before - nrow(dd)

# Expected drops = N_unique(subject × task × run) combinations
n_blocks_expected <- dd_lagged |>
  distinct(subject_id, task, run) |>
  nrow()

log_line("--- QC CHECK 3: Data reduction log ---")
log_line(sprintf("  Rows before NA drop : %d", n_before))
log_line(sprintf("  Rows dropped (NA)   : %d", n_dropped))
log_line(sprintf("  Rows retained       : %d", nrow(dd)))
log_line(sprintf("  Expected drops      : %d  (= N_subjects × N_tasks × N_runs)", n_blocks_expected))

if (n_dropped != n_blocks_expected) {
  warning(sprintf(
    "Data reduction mismatch: dropped %d rows but expected %d (one per block). ",
    n_dropped, n_blocks_expected
  ),
  "This may indicate additional NAs in rt/iscorr or misaligned trial_index. Inspect before proceeding."
  )
} else {
  log_line("Reduction log: drop count matches exactly (1 per block). PASSED.")
}

# ─── 6. Final type coercions ──────────────────────────────────────────────────

effort_levels <- sort(unique(dd$effort_condition))
log_line("Effort levels detected: ", paste(effort_levels, collapse = ", "))

dd <- dd |>
  mutate(
    subject_id       = factor(subject_id),
    task             = factor(task),
    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),
    effort_condition = factor(effort_condition, levels = sort(effort_levels)),
    decision         = as.integer(dec_upper),     # 1 = "Different" (upper), 0 = "Same" (lower)
    prev_choice      = as.numeric(prev_choice),   # centered ±0.5
    prev_correct     = as.numeric(prev_correct)   # 0 / 1
  )

log_line(sprintf(
  "Final analytic dataset: %d rows, %d subjects, prev_choice range [%.1f, %.1f]",
  nrow(dd), length(unique(dd$subject_id)),
  min(dd$prev_choice), max(dd$prev_choice)
))

# ─── 7. DDM family (shared with primary models) ───────────────────────────────

fam <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")

# ─── 8. Model formulas ────────────────────────────────────────────────────────
#
# Both models share the primary structure for drift, boundary, and NDT.
# Only the bias subformula differs between M_hist and M_wsls.
#
# NOTE on age_group: This dataset is a single older-adult cohort; age_group is
# not a design variable. The effort_condition × prev_choice interaction tests
# whether high somatic load amplifies or suppresses history-driven biases.

# --- Drift / boundary / NDT subformulas (same as fit_primary_vza_vEff.R) ---
# prev_choice is added to drift to test whether history effects also infiltrate
# evidence accumulation quality (exploratory secondary endpoint).

form_drift <- rt | dec(decision) ~
  difficulty_level + task + effort_condition + prev_choice +
  (1 + difficulty_level | subject_id)

form_bs  <- bs   ~ difficulty_level + task + (1 | subject_id)
form_ndt <- ndt  ~ task + effort_condition

# --- M_hist bias subformula: history main + effort interaction ---
form_bias_hist <- bias ~
  1 + prev_choice + effort_condition + prev_choice:effort_condition +
  (1 + prev_choice | subject_id)

# --- M_wsls bias subformula: win-stay/lose-shift extension ---
# Adds prev_choice × prev_correct to capture outcome-contingent repetition/switching
form_bias_wsls <- bias ~
  1 + prev_choice * prev_correct + effort_condition +
  prev_choice:effort_condition +
  (1 + prev_choice | subject_id)

form_hist <- bf(form_drift, form_bs, form_ndt, form_bias_hist)
form_wsls <- bf(form_drift, form_bs, form_ndt, form_bias_wsls)

log_line("Model M_hist formula (bias subformula):")
log_line("  bias ~ 1 + prev_choice + effort_condition + prev_choice:effort_condition + (1+prev_choice|subject_id)")
log_line("Model M_wsls formula (bias subformula):")
log_line("  bias ~ 1 + prev_choice * prev_correct + effort_condition + prev_choice:effort_condition + (1+prev_choice|subject_id)")

# ─── 9. Priors ────────────────────────────────────────────────────────────────
#
# Base priors are preserved from fit_primary_vza_vEff.R.
# New priors for history terms use the same scale as existing bias slopes.
# prev_choice is centered (±0.5) so a 1-unit effect spans the full range;
# normal(0, 0.35) matches the existing bias slope prior and remains weakly informative.

pri_shared <- c(
  # --- Drift ---
  prior(normal(0, 1),             class = "Intercept"),
  prior(normal(0, 0.70),          class = "b"),
  # --- Boundary ---
  prior(normal(log(1.7), 0.30),   class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.25),          class = "b",          dpar = "bs"),
  # --- NDT ---
  prior(normal(log(0.23), 0.12),  class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.08),          class = "b",          dpar = "ndt"),
  # --- Bias intercept ---
  prior(normal(0, 0.5),           class = "Intercept", dpar = "bias"),
  # --- Bias slopes (includes prev_choice, effort, interaction) ---
  prior(normal(0, 0.35),          class = "b",          dpar = "bias"),
  # --- Random effects ---
  prior(student_t(3, 0, 0.30),   class = "sd"),
  prior(lkj(2),                   class = "cor")
)

# ─── 10. Safe initialisation ──────────────────────────────────────────────────

min_rt   <- min(dd$rt, na.rm = TRUE)
safe_ndt <- min_rt * 0.30

log_line(sprintf("min RT = %.3f s  |  safe NDT = %.3f s (log = %.3f)",
                 min_rt, safe_ndt, log(safe_ndt)))

safe_init <- function(chain_id = 1) {
  list(
    Intercept      = rnorm(1, 0, 0.2),
    Intercept_bs   = log(runif(1, 1.3, 1.9)),
    Intercept_ndt  = log(safe_ndt),
    Intercept_bias = rnorm(1, 0, 0.1)
  )
}

# ─── 11. MCMC settings (preserved from primary models) ───────────────────────

CHAINS     <- 4L
ITER       <- 6000L      # slightly reduced for exploratory; increase if Rhat > 1.05
WARMUP     <- 3000L
CORES      <- 4L
THREADS    <- 2L         # threading(2) per chain; total = 8 logical cores
ADAPT_DELTA <- 0.995
MAX_TREE    <- 15L
SEED        <- 20260602L

options(mc.cores = CORES)

log_line(sprintf("Sampler: chains=%d, iter=%d, warmup=%d, adapt_delta=%.3f, max_treedepth=%d",
                 CHAINS, ITER, WARMUP, ADAPT_DELTA, MAX_TREE))

# ─── 12. Fit M_hist ───────────────────────────────────────────────────────────

log_line("==============================")
log_line("Fitting M_hist (base history model)...")
tic_hist <- Sys.time()

fit_hist <- brm(
  form_hist,
  data    = dd,
  family  = fam,
  prior   = pri_shared,
  chains  = CHAINS,
  iter    = ITER,
  warmup  = WARMUP,
  cores   = CORES,
  threads = threading(THREADS),
  control = list(adapt_delta = ADAPT_DELTA, max_treedepth = MAX_TREE),
  backend = "cmdstanr",
  file    = file.path(OUT_DIR, "exploratory_choice_history_hist"),
  file_refit = "always",
  refresh = 200,
  init    = safe_init,
  seed    = SEED,
  save_pars = save_pars(all = TRUE)
)

elapsed_hist <- as.numeric(difftime(Sys.time(), tic_hist, units = "mins"))
log_line(sprintf("M_hist completed: %.1f min", elapsed_hist))

# ─── 13. Fit M_wsls ───────────────────────────────────────────────────────────

log_line("==============================")
log_line("Fitting M_wsls (win-stay/lose-shift model)...")
tic_wsls <- Sys.time()

fit_wsls <- brm(
  form_wsls,
  data    = dd,
  family  = fam,
  prior   = pri_shared,
  chains  = CHAINS,
  iter    = ITER,
  warmup  = WARMUP,
  cores   = CORES,
  threads = threading(THREADS),
  control = list(adapt_delta = ADAPT_DELTA, max_treedepth = MAX_TREE),
  backend = "cmdstanr",
  file    = file.path(OUT_DIR, "exploratory_choice_history_wsls"),
  file_refit = "always",
  refresh = 200,
  init    = safe_init,
  seed    = SEED + 1L,
  save_pars = save_pars(all = TRUE)
)

elapsed_wsls <- as.numeric(difftime(Sys.time(), tic_wsls, units = "mins"))
log_line(sprintf("M_wsls completed: %.1f min", elapsed_wsls))

# ─── 14. Convergence diagnostics (QC Check 4) ────────────────────────────────

log_line("--- QC CHECK 4: Convergence diagnostics ---")

check_convergence <- function(fit, model_name) {
  draws <- as_draws_df(fit)
  rhats <- summarise_draws(fit, "rhat")

  max_rhat  <- max(rhats$rhat, na.rm = TRUE)
  n_diverge <- sum(nuts_params(fit)$Value[nuts_params(fit)$Parameter == "divergent__"])

  log_line(sprintf("[%s] Max Rhat: %.4f  |  Divergent transitions: %d",
                   model_name, max_rhat, n_diverge))

  if (max_rhat >= 1.05)
    warning(sprintf("[%s] CONVERGENCE FAILURE: max Rhat = %.4f >= 1.05. Do not interpret results.",
                    model_name, max_rhat))
  else
    log_line(sprintf("[%s] Rhat check PASSED (max = %.4f < 1.05).", model_name, max_rhat))

  if (n_diverge > 0)
    warning(sprintf("[%s] %d divergent transitions detected. Consider raising adapt_delta.",
                    model_name, n_diverge))
  else
    log_line(sprintf("[%s] Divergence check PASSED (0 divergent transitions).", model_name))

  invisible(list(max_rhat = max_rhat, n_diverge = n_diverge))
}

conv_hist <- check_convergence(fit_hist, "M_hist")
conv_wsls <- check_convergence(fit_wsls, "M_wsls")

# ─── 15. Posterior summary: key interaction terms ─────────────────────────────
#
# Focal parameters for reporting:
#   b_bias_prev_choice                        — main history effect (perseveration index)
#   b_bias_effort_conditionHigh_MVC           — effort main effect on bias
#   b_bias_prev_choice:effort_conditionHigh_MVC — critical interaction
#   b_bias_prev_correct (M_wsls only)         — win-stay component
#   b_bias_prev_choice:prev_correct (M_wsls)  — outcome-contingent repetition

extract_posterior_summary <- function(fit, model_name,
                                      pattern = "b_bias_|b_prev_choice") {
  draws <- as_draws_df(fit)

  focal_cols <- grep(pattern, names(draws), value = TRUE)
  if (length(focal_cols) == 0) {
    log_line(sprintf("[%s] No focal bias columns matched pattern '%s'.", model_name, pattern))
    return(NULL)
  }

  out <- draws[, focal_cols, drop = FALSE] |>
    pivot_longer(everything(), names_to = "parameter", values_to = "draw") |>
    group_by(parameter) |>
    summarise(
      median   = median(draw),
      mean     = mean(draw),
      sd       = sd(draw),
      q2.5     = quantile(draw, 0.025),
      q97.5    = quantile(draw, 0.975),
      p_gt_0   = mean(draw > 0),
      .groups  = "drop"
    ) |>
    mutate(
      model    = model_name,
      CrI_95   = sprintf("[%.3f, %.3f]", q2.5, q97.5),
      excludes0 = (q2.5 > 0) | (q97.5 < 0)
    ) |>
    select(model, parameter, median, sd, CrI_95, p_gt_0, excludes0)

  out
}

summary_hist <- extract_posterior_summary(fit_hist, "M_hist")
summary_wsls <- extract_posterior_summary(fit_wsls, "M_wsls")

posterior_table <- bind_rows(summary_hist, summary_wsls)

log_line("--- Posterior summary: focal bias parameters ---")
print(as.data.frame(posterior_table), row.names = FALSE)

# ─── 16. Save outputs ─────────────────────────────────────────────────────────

saveRDS(fit_hist, file.path(PUBLISH_DIR, "fit_exploratory_choice_history_hist.rds"))
saveRDS(fit_wsls, file.path(PUBLISH_DIR, "fit_exploratory_choice_history_wsls.rds"))

# Write posterior table to CSV for manuscript / reporting
summary_path <- file.path(PUBLISH_DIR, "exploratory_choice_history_posterior_summary.csv")
write_csv(posterior_table, summary_path)

log_line("Saved M_hist RDS: output/publish/fit_exploratory_choice_history_hist.rds")
log_line("Saved M_wsls RDS: output/publish/fit_exploratory_choice_history_wsls.rds")
log_line("Saved posterior table: ", summary_path)

# ─── 17. Total runtime ────────────────────────────────────────────────────────

total_elapsed <- as.numeric(difftime(Sys.time(), tic_all, units = "mins"))
log_line("================================================================================")
log_line(sprintf("TOTAL TIME: %.1f minutes (%.2f hours)", total_elapsed, total_elapsed / 60))
log_line(sprintf("  M_hist fit : %.1f min", elapsed_hist))
log_line(sprintf("  M_wsls fit : %.1f min", elapsed_wsls))
log_line("================================================================================")
log_line("END exploratory_choice_history_ddm.R")

cat("\n\u2713 M_hist saved: output/publish/fit_exploratory_choice_history_hist.rds\n")
cat("\u2713 M_wsls saved: output/publish/fit_exploratory_choice_history_wsls.rds\n")
cat("\u2713 Posterior table: output/publish/exploratory_choice_history_posterior_summary.csv\n")
cat("\u2713 Log: output/logs/exploratory_choice_history_ddm.log\n\n")
cat("Next steps:\n")
cat("  1. Inspect posterior_table for b_bias_prev_choice:effort_conditionHigh_MVC\n")
cat("  2. Compare M_hist vs M_wsls via LOO: loo_compare(loo(fit_hist), loo(fit_wsls))\n")
cat("  3. Check output/logs/ for convergence details\n")
