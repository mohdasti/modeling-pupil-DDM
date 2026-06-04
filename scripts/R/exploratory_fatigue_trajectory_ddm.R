# scripts/R/exploratory_fatigue_trajectory_ddm.R
#
# Exploratory Supplementary Analysis: Within-Session Fatigue Trajectories
#
# Scientific goal:
#   Determine whether the combination of high somatic load (40% MVC) and
#   advancing trial position within a run causes dynamic degradation of
#   drift rate (v) or collapse of boundary separation (a) in older adults —
#   evidence of fatigue-driven processing decay rather than a static effort cost.
#
# Design:
#   Each run contains 30 trials (trial_index 1-30). We partition each run
#   into First_Half / Second_Half using the median of the OBSERVED trial
#   indices in that run (accommodating gaps from trial exclusions).
#   block_half is then entered as a predictor interacting with effort_condition.
#
# NOTE on age:
#   No age column exists in bap_ddm_only_ready.csv. Age (continuous,
#   60-87 years) is loaded from the external demographics spreadsheet and
#   joined on subject_id. It is z-scored (mean-centred, SD-scaled) to
#   create age_z, so the coefficient represents a 1-SD (~6.4 year) effect.
#   The three-way effort_condition × block_half × age_z interaction tests
#   whether older participants within this cohort show steeper fatigue
#   trajectories under high somatic load.
#
# NOTE on grouping:
#   Effort condition alternates randomly at the trial level WITHIN each run.
#   Grouping by (subject × task × effort_condition) would break the
#   continuous temporal sequence required for fatigue estimation.
#   Correct grouping is (subject_id × task × run), matching the actual
#   continuous block delivery. effort_condition is then a fixed-effect
#   predictor, not a grouping variable.
#
# Architecture mirrors fit_primary_vza_vEff.R exactly (family, priors,
# sampler settings, logging). Only the formula is extended.
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
    if (!is.null(doc_path) && doc_path != "")
      setwd(dirname(dirname(doc_path)))   # scripts/R/ → project root
  }
}, error = function(e) invisible(NULL))

# ─── Paths ────────────────────────────────────────────────────────────────────

DATA        <- "data/analysis_ready/bap_ddm_only_ready.csv"
OUT_DIR     <- "output/models"
PUBLISH_DIR <- "output/publish"
LOG_DIR     <- "output/logs"

for (d in c(OUT_DIR, PUBLISH_DIR, LOG_DIR))
  dir.create(d, showWarnings = FALSE, recursive = TRUE)

LOG_FILE <- file.path(LOG_DIR, "exploratory_fatigue_trajectory_ddm.log")
sink(LOG_FILE, append = TRUE, split = TRUE)
on.exit(sink(NULL), add = TRUE)

log_line("================================================================================")
log_line("START exploratory_fatigue_trajectory_ddm.R")
log_line("Working directory: ", getwd())

tic_all <- Sys.time()

# ─── 1. Load data ─────────────────────────────────────────────────────────────

log_line("Loading: ", DATA)
stopifnot(file.exists(DATA))
dd_raw <- read_csv(DATA, show_col_types = FALSE)

n_raw <- nrow(dd_raw)
log_line(sprintf("Raw rows: %d  |  Subjects: %d", n_raw, length(unique(dd_raw$subject_id))))

required_cols <- c("subject_id", "task", "run", "trial_index",
                   "rt", "dec_upper", "iscorr", "effort_condition", "difficulty_level")
missing_cols  <- setdiff(required_cols, names(dd_raw))
if (length(missing_cols) > 0)
  stop("Missing required columns: ", paste(missing_cols, collapse = ", "))

# ─── 1b. Load and join continuous age ─────────────────────────────────────────
#
# Age is not in bap_ddm_only_ready.csv. We load the demographics spreadsheet,
# filter to QA-included subjects, extract the continuous age variable, and
# join it onto the behavioral data on subject_id.
# age_z: z-scored (mean-centred, SD-scaled). A 1-unit change = 1 SD ≈ 6.4 years,
# keeping the prior normal(0, 0.70) on drift slopes well-calibrated.

DEMO_PATH <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/LC Aging Subject Data master spreadsheet - demographics.csv"
QA_PATH   <- "output/publish/qa_subject_inclusion.csv"

log_line("Loading age from demographics: ", DEMO_PATH)

if (!file.exists(DEMO_PATH)) stop("Demographics file not found: ", DEMO_PATH)
if (!file.exists(QA_PATH))   stop("QA inclusion file not found: ", QA_PATH)

qa_included <- read_csv(QA_PATH, show_col_types = FALSE)

demo_raw <- read_csv(DEMO_PATH, skip = 1, show_col_types = FALSE,
  col_names = c(
    "study", "subject_id", "subject_id2", "demo_comments", "completion",
    "bap_ses1_date", "bap_ses2_date", "bap_ses3_date", "bap_ses_order",
    "bap_tablet_date", "blank1", "bam_ses1", "bam_ses2", "bam_ses3", "bam_order",
    "bam_tablet", "blank2", "dob", "age", "sex", "edu", "hand", "race",
    "ethnicity", "first_lang", "blank3", "vision", "prescription", "blank4",
    "neuropsych_comments", "adt_comments", "vdt_comments", "stx_comments",
    "future_contact", "blank5", "days_ses1_2", "days_ses2_3", "extra"
  )
)

age_lookup <- demo_raw |>
  filter(subject_id %in% qa_included$subject_id) |>
  mutate(age = suppressWarnings(as.numeric(age))) |>
  filter(!is.na(age)) |>
  select(subject_id, age) |>
  distinct(subject_id, .keep_all = TRUE)

age_mean <- mean(age_lookup$age)
age_sd   <- sd(age_lookup$age)

age_lookup <- age_lookup |>
  mutate(age_z = as.numeric(scale(age, center = TRUE, scale = TRUE)))

log_line(sprintf(
  "Age joined: N=%d subjects, range %.0f-%.0f, mean=%.1f, SD=%.1f",
  nrow(age_lookup),
  min(age_lookup$age), max(age_lookup$age),
  age_mean, age_sd
))

# Join age onto behavioral data; warn if any subjects are missing age
dd_raw <- dd_raw |> left_join(age_lookup, by = "subject_id")

n_missing_age <- sum(is.na(dd_raw$age_z))
if (n_missing_age > 0) {
  warning(sprintf(
    "%d rows have no age data after join — these subjects will be dropped. ",
    n_missing_age
  ),
  "Check that subject_id values match between the behavioral CSV and demographics file."
  )
  dd_raw <- dd_raw |> filter(!is.na(age_z))
  log_line(sprintf("Rows after age-missing drop: %d", nrow(dd_raw)))
} else {
  log_line("Age join complete: all subjects have valid age_z.")
}

# Update n_raw to reflect any rows dropped due to missing age, so subsequent
# QC conservation checks use the correct post-join denominator.
n_raw <- nrow(dd_raw)

# ─── 2. Feature engineering: block_half partitioning ─────────────────────────
#
# Partition each continuous 30-trial run into two equal halves.
# Using median of OBSERVED trial_index values (not a fixed 15.5 cutoff)
# correctly handles gaps from prior trial exclusions.
# Grouping: subject_id × task × run (the actual continuous temporal unit).

log_line("Engineering block_half variable (grouping: subject_id × task × run)...")

dd_halved <- dd_raw |>
  arrange(subject_id, task, run, trial_index) |>
  group_by(subject_id, task, run) |>
  mutate(
    median_trial = median(trial_index, na.rm = TRUE),
    block_half   = if_else(trial_index <= median_trial, "First_Half", "Second_Half")
  ) |>
  ungroup()

# ─── 3. QC Check 1: Row-count conservation law ───────────────────────────────

log_line("--- QC CHECK 1: Row-count conservation ---")
n_after <- nrow(dd_halved)

if (n_after != n_raw) {
  stop(sprintf(
    "QC1 FAILED: Row count changed from %d to %d after block_half mutation. Inspect mutate logic.",
    n_raw, n_after
  ))
} else {
  log_line(sprintf("QC1 passed: row count conserved (%d rows before and after).", n_raw))
}

# ─── 4. QC Check 2: Trial distribution balance ───────────────────────────────
#
# Within each (subject × task × run) group, verify First_Half and Second_Half
# counts differ by at most 1 trial (expected when run has odd trial count).

log_line("--- QC CHECK 2: Trial distribution balance ---")

balance_summary <- dd_halved |>
  group_by(subject_id, task, run, block_half) |>
  summarise(n = n(), .groups = "drop") |>
  pivot_wider(names_from = block_half, values_from = n, values_fill = 0L) |>
  mutate(imbalance = abs(First_Half - Second_Half))

max_imbalance <- max(balance_summary$imbalance, na.rm = TRUE)
n_imbalanced  <- sum(balance_summary$imbalance > 1, na.rm = TRUE)

log_line(sprintf("  Max half-imbalance across runs : %d trial(s)", max_imbalance))
log_line(sprintf("  Runs with imbalance > 1 trial  : %d", n_imbalanced))

if (n_imbalanced > 0) {
  warning(sprintf(
    "QC2 WARNING: %d run(s) have >1-trial imbalance between halves. ",
    n_imbalanced
  ),
  "This can occur if a run has many consecutive missing trial_indices. ",
  "Inspect: balance_summary[balance_summary$imbalance > 1, ]"
  )
  print(balance_summary[balance_summary$imbalance > 1, ] |> head(20))
} else {
  log_line("QC2 passed: all runs balanced within ±1 trial.")
}

# Print overall counts for transparency
overall_balance <- dd_halved |>
  count(block_half) |>
  mutate(pct = round(100 * n / sum(n), 1))
log_line("Overall block_half distribution:")
print(as.data.frame(overall_balance))

# ─── 5. Final type coercions ──────────────────────────────────────────────────

effort_levels <- sort(unique(dd_halved$effort_condition))
log_line("Effort levels detected: ", paste(effort_levels, collapse = ", "))

# Confirm High_40_MVC is first (reference) after sort; if not, reverse
# We want Low_5_MVC as reference so High_40_MVC contrast is the focal effect
if ("Low_5_MVC" %in% effort_levels) {
  effort_ref_order <- c("Low_5_MVC", "High_40_MVC")
} else {
  effort_ref_order <- sort(effort_levels)
}

dd <- dd_halved |>
  mutate(
    subject_id       = factor(subject_id),
    task             = factor(task),
    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),
    effort_condition = factor(effort_condition, levels = effort_ref_order),
    block_half       = factor(block_half, levels = c("First_Half", "Second_Half")),
    decision         = as.integer(dec_upper)   # 1 = Different (upper), 0 = Same (lower)
  )

log_line(sprintf(
  "Final analytic dataset: %d rows, %d subjects",
  nrow(dd), length(unique(dd$subject_id))
))
log_line(sprintf("  Reference levels: effort = '%s', block_half = 'First_Half'",
                 levels(dd$effort_condition)[1]))

# ─── 6. DDM family ────────────────────────────────────────────────────────────

fam <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")

# ─── 7. Model formulas ────────────────────────────────────────────────────────
#
# Focal effect: effort_condition × block_half interaction on v and bs.
#   - Positive b_block_halfSecond_Half on drift       → processing IMPROVES
#   - Negative b_block_halfSecond_Half on drift       → processing DECAYS (fatigue)
#   - Positive b_block_halfSecond_Half on boundary    → caution INCREASES (adaptation)
#   - Negative b_block_halfSecond_Half on boundary    → boundary COLLAPSES (fatigue)
#   - Interaction with effort_condition:block_half    → fatigue trajectory differs by load
#
# Random effect (1 + block_half | subject_id) allows each participant's
# within-run fatigue slope to vary — this is the key individual-differences term.
#
# NDT and bias are kept at baseline specification to preserve degrees of freedom.
# block_half is NOT added to NDT because the response-signal design already
# constrains t0 estimation (see primary model rationale).

form <- bf(
  # DRIFT: full three-way effort × block_half × age_z — primary scientific endpoint.
  #   Focal term: effort_condition:block_half:age_z
  #   A negative coefficient here means older participants within this cohort
  #   show greater processing-efficiency decay in the second half under high load.
  rt | dec(decision) ~
    difficulty_level + task + effort_condition * block_half * age_z +
    (1 + block_half | subject_id),

  # BOUNDARY: two-way effort × block_half + age_z as main effect.
  #   Age moderation of boundary is a secondary hypothesis; the full three-way
  #   in BOTH drift and boundary simultaneously doubles model complexity and
  #   destabilizes threading. The two-way captures adaptive caution under load;
  #   age_z as a main effect captures the between-subject boundary level.
  bs ~
    difficulty_level + task + effort_condition * block_half + age_z +
    (1 | subject_id),

  # NDT: baseline specification (response-signal design constraint)
  ndt  ~ task + effort_condition,

  # BIAS: baseline specification (pre-stimulus; no fatigue or age pathway)
  bias ~ difficulty_level + task + (1 | subject_id)
)

log_line("Formula specified:")
log_line("  Drift:    difficulty + task + effort * block_half * age_z + (1 + block_half | subject)")
log_line("  Boundary: difficulty + task + effort * block_half + age_z + (1 | subject)")
log_line("  NDT:      task + effort [baseline]")
log_line("  Bias:     difficulty + task [baseline]")
log_line("  KEY: drift effort:block_half:age_z = fatigue × age interaction (focal)")
log_line("  NOTE: age_z omitted from bs three-way to preserve sampling stability")

# ─── 8. Priors ────────────────────────────────────────────────────────────────
#
# Intercepts and baseline slopes preserved from fit_primary_vza_vEff.R.
# block_half and effort:block_half interaction use the same slope scales
# as the corresponding parameter families.
# normal(0, 0.70) for drift slopes; normal(0, 0.25) for boundary slopes.
# A moderately tight prior on block_half effects is appropriate: within-run
# fatigue is plausible but unlikely to exceed the difficulty effect in magnitude.

pri <- c(
  # --- Intercepts (primary architecture) ---
  prior(normal(0, 1),             class = "Intercept"),
  prior(normal(log(1.7), 0.30),   class = "Intercept", dpar = "bs"),
  prior(normal(log(0.23), 0.12),  class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.5),           class = "Intercept", dpar = "bias"),

  # --- Drift slopes (includes block_half, effort:block_half) ---
  prior(normal(0, 0.70),          class = "b"),

  # --- Boundary slopes ---
  prior(normal(0, 0.25),          class = "b", dpar = "bs"),

  # --- Bias slopes ---
  prior(normal(0, 0.35),          class = "b", dpar = "bias"),

  # --- NDT slopes ---
  prior(normal(0, 0.08),          class = "b", dpar = "ndt"),

  # --- Random effects ---
  prior(student_t(3, 0, 0.30),   class = "sd"),
  prior(lkj(2),                   class = "cor")   # for (1 + block_half | subject)
)

log_line("Priors: preserved from fit_primary_vza_vEff.R + same slope priors for block_half terms.")

# ─── 9. Safe initialisation ───────────────────────────────────────────────────

min_rt   <- min(dd$rt, na.rm = TRUE)
safe_ndt <- min_rt * 0.30

log_line(sprintf("min RT = %.3f s  |  safe NDT = %.3f s (log = %.3f)",
                 min_rt, safe_ndt, log(safe_ndt)))

safe_init <- function(chain_id = 1) {
  # Intercepts are set to principled starting values.
  # Slope vectors (b, b_bs, b_ndt, b_bias) are zeroed explicitly.
  #
  # WHY b_ndt MUST be zeroed:
  #   Intercept_ndt = log(safe_ndt) ≈ −2.59.
  #   If Stan draws b_ndt slopes from Uniform(−2, 2), the per-trial NDT becomes
  #   exp(−2.59 + slope_task + slope_effort). With slopes of ~1.5, NDT → 1.5 s,
  #   which exceeds the minimum RT (0.251 s) and makes the Wiener log-density −Inf.
  #   Setting b_ndt = 0 guarantees NDT_init = exp(−2.59) = 0.075 s < min_RT.
  #
  # Slope vector lengths derived from formula:
  #   b      (drift):    difficulty(2) + task(1) + effort*block*age_z(7) = 10
  #   b_bs   (boundary): difficulty(2) + task(1) + effort*block(3) + age_z(1) = 7
  #   b_ndt  (ndt):      task(1) + effort(1) = 2
  #   b_bias (bias):     difficulty(2) + task(1) = 3
  list(
    Intercept      = rnorm(1, 0, 0.1),
    Intercept_bs   = log(runif(1, 1.3, 1.9)),
    Intercept_ndt  = log(safe_ndt),
    Intercept_bias = rnorm(1, 0, 0.05),
    b              = rep(0, 10L),
    b_bs           = rep(0,  7L),
    b_ndt          = rep(0,  2L),
    b_bias         = rep(0,  3L)
  )
}

# ─── 10. MCMC settings (preserved from primary models) ────────────────────────

CHAINS      <- 4L
ITER        <- 8000L    # matching primary models for direct comparability
WARMUP      <- 4000L
CORES       <- 4L
ADAPT_DELTA <- 0.995
MAX_TREE    <- 15L
SEED        <- 20260603L

options(mc.cores = CORES)

log_line(sprintf("Sampler: chains=%d, iter=%d, warmup=%d, adapt_delta=%.3f, max_treedepth=%d",
                 CHAINS, ITER, WARMUP, ADAPT_DELTA, MAX_TREE))

# ─── 11. Fit model ────────────────────────────────────────────────────────────

log_line("==============================")
log_line("Fitting M_fatigue (effort × block_half DDM)...")
tic_fit <- Sys.time()

fit_fatigue <- brm(
  form,
  data      = dd,
  family    = fam,
  prior     = pri,
  chains    = CHAINS,
  iter      = ITER,
  warmup    = WARMUP,
  cores     = CORES,
  # Threading is intentionally omitted for the Wiener DDM.
  # The Wiener density + three-way interaction + threading(reduce_sum)
  # reliably destabilises all chains. Each chain runs on its own core;
  # 4 chains × 1 core = 4 cores, which is sufficient.
  control   = list(adapt_delta = ADAPT_DELTA, max_treedepth = MAX_TREE),
  backend   = "cmdstanr",
  file      = file.path(OUT_DIR, "exploratory_fatigue_trajectory"),
  file_refit = "always",
  refresh   = 200,
  init      = safe_init,
  seed      = SEED,
  save_pars = save_pars(all = TRUE)
)

elapsed_fit <- as.numeric(difftime(Sys.time(), tic_fit, units = "mins"))
log_line(sprintf("M_fatigue completed: %.1f min", elapsed_fit))

# ─── 12. QC Check 3: Convergence diagnostics ─────────────────────────────────

log_line("--- QC CHECK 3: Convergence diagnostics ---")

rhats     <- summarise_draws(fit_fatigue, "rhat")
max_rhat  <- max(rhats$rhat, na.rm = TRUE)
n_diverge <- sum(nuts_params(fit_fatigue)$Value[
  nuts_params(fit_fatigue)$Parameter == "divergent__"
])

log_line(sprintf("Max Rhat: %.4f  |  Divergent transitions: %d", max_rhat, n_diverge))

if (max_rhat >= 1.05) {
  warning(sprintf(
    "CONVERGENCE FAILURE: max Rhat = %.4f >= 1.05. Do not interpret results.",
    max_rhat
  ))
} else {
  log_line(sprintf("Rhat check PASSED (max = %.4f < 1.05).", max_rhat))
}

if (n_diverge > 0) {
  warning(sprintf(
    "%d divergent transitions. Consider raising adapt_delta toward 0.999.",
    n_diverge
  ))
} else {
  log_line("Divergence check PASSED (0 divergent transitions).")
}

# ─── 13. Posterior summary: focal fatigue parameters ─────────────────────────
#
# Primary targets (drift, b_*):
#   b_block_halfSecond_Half                                    — within-run decay, Low effort
#   b_effort_conditionHigh_40_MVC                             — effort main effect
#   b_effort_conditionHigh_40_MVC:block_halfSecond_Half       — extra decay under High
#   b_age_z                                                    — age slope on drift
#   b_block_halfSecond_Half:age_z                             — age moderates fatigue
#   b_effort_conditionHigh_40_MVC:block_halfSecond_Half:age_z — FOCAL three-way
#
# Primary targets (boundary, b_bs_*):
#   Same interaction structure as drift but for boundary separation.

focal_patterns <- c(
  "b_block_half",
  "b_effort_condition",
  "b_age_z",
  "b_bs_block_half",
  "b_bs_effort_condition",
  "b_bs_age_z"
)

extract_fatigue_summary <- function(fit) {
  draws <- as_draws_df(fit)

  focal_cols <- unlist(lapply(focal_patterns, function(p)
    grep(p, names(draws), value = TRUE, fixed = TRUE)
  ))
  focal_cols <- unique(focal_cols)

  if (length(focal_cols) == 0) {
    log_line("No focal parameters matched. Check formula labels.")
    return(NULL)
  }

  draws[, focal_cols, drop = FALSE] |>
    pivot_longer(everything(), names_to = "parameter", values_to = "draw") |>
    group_by(parameter) |>
    summarise(
      median    = median(draw),
      sd        = sd(draw),
      q2.5      = quantile(draw, 0.025),
      q97.5     = quantile(draw, 0.975),
      p_gt_0    = mean(draw > 0),
      .groups   = "drop"
    ) |>
    mutate(
      parameter_type = dplyr::case_when(
        grepl("^b_bs_", parameter) ~ "Boundary (a)",
        TRUE                       ~ "Drift (v)"
      ),
      CrI_95    = sprintf("[%.3f, %.3f]", q2.5, q97.5),
      excludes0 = (q2.5 > 0) | (q97.5 < 0)
    ) |>
    select(parameter_type, parameter, median, sd, q2.5, q97.5, CrI_95, p_gt_0, excludes0) |>
    arrange(parameter_type, parameter)
}

posterior_table <- extract_fatigue_summary(fit_fatigue)

log_line("--- Posterior summary: focal fatigue parameters ---")
print(as.data.frame(posterior_table), row.names = FALSE)

# ─── 14. Save outputs ─────────────────────────────────────────────────────────

rds_path     <- file.path(PUBLISH_DIR, "fit_exploratory_fatigue_trajectory.rds")
csv_path     <- file.path(PUBLISH_DIR, "exploratory_fatigue_trajectory_posterior_summary.csv")
balance_path <- file.path(PUBLISH_DIR, "exploratory_fatigue_trajectory_balance_check.csv")

saveRDS(fit_fatigue, rds_path)
write_csv(posterior_table, csv_path)
write_csv(balance_summary, balance_path)

log_line("Saved model RDS     : ", rds_path)
log_line("Saved posterior CSV : ", csv_path)
log_line("Saved balance CSV   : ", balance_path)

# ─── 15. Total runtime ────────────────────────────────────────────────────────

total_elapsed <- as.numeric(difftime(Sys.time(), tic_all, units = "mins"))
log_line("================================================================================")
log_line(sprintf("TOTAL TIME: %.1f minutes (%.2f hours)", total_elapsed, total_elapsed / 60))
log_line(sprintf("  Model fit : %.1f min", elapsed_fit))
log_line("================================================================================")
log_line("END exploratory_fatigue_trajectory_ddm.R")

cat("\n\u2713 Model saved  : output/publish/fit_exploratory_fatigue_trajectory.rds\n")
cat("\u2713 Posteriors    : output/publish/exploratory_fatigue_trajectory_posterior_summary.csv\n")
cat("\u2713 Balance check : output/publish/exploratory_fatigue_trajectory_balance_check.csv\n")
cat("\u2713 Log           : output/logs/exploratory_fatigue_trajectory_ddm.log\n\n")
cat("Focal interactions to inspect:\n")
cat("  Two-way: b_effort_conditionHigh_40_MVC:block_halfSecond_Half  [drift]\n")
cat("           b_bs_effort_conditionHigh_40_MVC:block_halfSecond_Half  [boundary]\n")
cat("  Three-way (KEY): b_effort_conditionHigh_40_MVC:block_halfSecond_Half:age_z  [drift]\n")
cat("                   b_bs_effort_conditionHigh_40_MVC:block_halfSecond_Half:age_z  [boundary]\n\n")
cat("Interpretation:\n")
cat("  Negative 3-way drift  = older-within-cohort show GREATER processing decay\n")
cat("                          in the second half under high somatic load.\n")
cat("  Negative 3-way boundary = older-within-cohort collapse boundary under load + fatigue.\n\n")
cat("Next step: loo_compare(loo(fit_primary), loo(fit_fatigue)) to test block_half contribution\n")
