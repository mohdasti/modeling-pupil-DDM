# R/fit_primary_vza_vEff.R

# Primary model with effort on drift + retuned priors
# 1. Drift: difficulty + task + effort (effort added)
# 2. Boundary: difficulty + task (mains only)
# 3. NDT: task + effort (small condition effects)
# 4. Bias: difficulty + task (mains only)
# 5. Retuned priors: wider drift slopes (0.70), tighter boundary slopes (0.25)

suppressPackageStartupMessages({

  library(brms)

  library(cmdstanr)

  library(dplyr)

  library(readr)

  library(posterior)

})



# --- Set working directory for RStudio (optional, skip if already set) ---

tryCatch({

  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {

    doc_path <- rstudioapi::getActiveDocumentContext()$path

    if (!is.null(doc_path) && doc_path != "") {

      script_dir <- dirname(doc_path)

      parent_dir <- dirname(script_dir)

      if (file.exists(parent_dir)) {

        setwd(parent_dir)

      }

    }

  }

}, error = function(e) {

  # Silently continue if setwd fails (user may have already set it)

})



# --- logging helpers ---

timestamp <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")

log_line <- function(...) {

  cat("[", timestamp(), "] ", paste0(..., collapse = ""), "\n", sep = "")

  flush.console()

}



# --- dirs ---

DATA <- "data/analysis_ready/bap_ddm_ready.csv"

OUT_DIR <- "output/models"

PUBLISH_DIR <- "output/publish"

LOG_DIR <- "output/logs"

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

dir.create(PUBLISH_DIR, showWarnings = FALSE, recursive = TRUE)

dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)

LOG_FILE <- file.path(LOG_DIR, "fit_primary_vza_vEff.log")

sink(LOG_FILE, append = TRUE, split = TRUE)

on.exit(sink(NULL), add = TRUE)

log_line("================================================================================")

log_line("START fit_primary_vza_vEff.R")

log_line("Working directory: ", getwd())

log_line("Output dir: ", OUT_DIR, " | Publish dir: ", PUBLISH_DIR)



# --- data ---

tic_all <- Sys.time()

log_line("Loading data: ", DATA)

tic_data <- Sys.time()

dd <- read_csv(DATA, show_col_types = FALSE)

# Harmonize/derive decision column (1=correct, 0=incorrect)

if (!"decision" %in% names(dd)) {

  log_line("Column 'decision' not found; attempting to derive from alternatives...")

  if ("iscorr" %in% names(dd)) {

    dd$decision <- as.integer(dd$iscorr)

    log_line("Derived 'decision' from 'iscorr'.")

  } else if ("correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$correct)

    log_line("Derived 'decision' from 'correct'.")

  } else if ("is_correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$is_correct)

    log_line("Derived 'decision' from 'is_correct'.")

  } else if ("accuracy" %in% names(dd)) {

    dd$decision <- as.integer(dd$accuracy)

    log_line("Derived 'decision' from 'accuracy'.")

  } else if ("acc" %in% names(dd)) {

    dd$decision <- as.integer(dd$acc)

    log_line("Derived 'decision' from 'acc'.")

  } else {

    stop("ERROR: Could not find a column to derive 'decision'. Available columns: ", 

         paste(names(dd), collapse = ", "), "\n",

         "Missing 'decision' (or equivalent).")

  }

}

dd <- dd |>

  mutate(

    subject_id = factor(subject_id),

    task = factor(task),                                # ADT / VDT

    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_MVC")),

    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),

    decision = as.integer(decision)

  )

toc_data <- Sys.time()

log_line(sprintf("Data loaded. N=%d rows, %d subjects. Time: %.1f sec",

                 nrow(dd), length(unique(dd$subject_id)), as.numeric(toc_data - tic_data, units = "secs")))



# --- family & formula ---

fam <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")

form <- bf(

  # DRIFT: difficulty + task + effort (effort added)

  rt | dec(decision) ~ difficulty_level + task + effort_condition + (1 + difficulty_level | subject_id),

  # BOUNDARY: difficulty + task (mains only)

  bs   ~ difficulty_level + task + (1 | subject_id),

  # NDT: task + effort (small condition effects, no RE)

  ndt  ~ task + effort_condition,

  # BIAS: difficulty + task (mains only)

  bias ~ difficulty_level + task + (1 | subject_id)

)

log_line("Formula specified:")

log_line("  Drift: difficulty + task + effort + (1 + difficulty | subject)")

log_line("  Boundary: difficulty + task + (1 | subject)")

log_line("  NDT: task + effort")

log_line("  Bias: difficulty + task + (1 | subject)")



# --- priors (retuned) ---

pri <- c(

  prior(normal(0, 1),                class = "Intercept"),                # drift intercept

  prior(normal(log(1.7), 0.30),      class = "Intercept", dpar = "bs"),

  prior(normal(log(0.23), 0.12),    class = "Intercept", dpar = "ndt"),

  prior(normal(0, 0.5),              class = "Intercept", dpar = "bias"),

  prior(normal(0, 0.70),             class = "b"),                        # drift slopes WIDER (was 0.60)

  prior(normal(0, 0.25),             class = "b", dpar = "bs"),             # boundary slopes TIGHTER (was 0.30)

  prior(normal(0, 0.35),             class = "b", dpar = "bias"),

  prior(normal(0, 0.08),             class = "b", dpar = "ndt"),

  prior(student_t(3, 0, 0.30),      class = "sd"),

  prior(lkj(2),                      class = "cor")                        # for (1 + difficulty | subject)

)

log_line("Priors specified:")

log_line("  Drift slopes: normal(0, 0.70) [WIDER]")

log_line("  Boundary slopes: normal(0, 0.25) [TIGHTER]")

log_line("  Bias slopes: normal(0, 0.35) [unchanged]")

log_line("  NDT slopes: normal(0, 0.08) [unchanged]")



# --- safe init (data-aware, correct parameter names) ---

min_rt <- min(dd$rt, na.rm = TRUE)

safe_ndt <- min_rt * 0.3  # Use 30% of min RT as safe NDT

log_line(sprintf("Data check: min RT = %.3fs, safe NDT = %.3fs (log = %.3f)",

                 min_rt, safe_ndt, log(safe_ndt)))



safe_init <- function(chain_id = 1) {

  # brms uses Intercept_ndt (not b_ndt_Intercept) for distributional parameter intercepts

  list(

    Intercept      = rnorm(1, 0, 0.2),                    # drift intercept

    Intercept_bs   = log(runif(1, 1.3, 1.9)),             # boundary intercept

    Intercept_ndt  = log(safe_ndt),                       # ndt intercept (~75ms, conservative)

    Intercept_bias = rnorm(1, 0, 0.1)                     # bias intercept

    # Note: Random slopes and other parameters will be initialized by brms default method

  )

}



# --- sampling ---

options(mc.cores = 4)

fit_file <- file.path(OUT_DIR, "primary_vza_vEff")

log_line("Beginning fit: primary_vza_vEff")

log_line("Sampler settings: chains=4, iter=8000, warmup=4000, cores=4, threads=2")

log_line("HMC control: adapt_delta=0.995, max_treedepth=15")

log_line("Model features: effort on drift, retuned priors (wider drift, tighter boundary)")

tic_fit <- Sys.time()

fit <- brm(

  form,

  data = dd,

  family = fam,

  prior = pri,

  chains = 4,

  iter = 8000,

  warmup = 4000,

  cores = 4,

  threads = threading(2),

  control = list(adapt_delta = 0.995, max_treedepth = 15),

  backend = "cmdstanr",

  file = fit_file,

  file_refit = "always",

  refresh = 200,

  init = safe_init,  # Note: init_r incompatible with function-based init, removed

  seed = 20251117,

  save_pars = save_pars(all = TRUE)

)

toc_fit <- Sys.time()

fit_time <- as.numeric(toc_fit - tic_fit, units = "mins")

log_line(sprintf("Fit completed. Wall time: %.1f minutes (%.2f hours)", fit_time, fit_time / 60))



# --- save ---

tic_save <- Sys.time()

saveRDS(fit, file.path(PUBLISH_DIR, "fit_primary_vza_vEff.rds"))

toc_save <- Sys.time()

log_line(sprintf("Saved: %s (%.1f sec)", 

                 file.path(PUBLISH_DIR, "fit_primary_vza_vEff.rds"),

                 as.numeric(toc_save - tic_save, units = "secs")))



# --- summary timing ---

toc_all <- Sys.time()

total_time <- as.numeric(toc_all - tic_all, units = "mins")

log_line("================================================================================")

log_line(sprintf("TOTAL TIME: %.1f minutes (%.2f hours)", total_time, total_time / 60))

log_line("Breakdown:")

log_line(sprintf("  Data loading: %.1f sec", as.numeric(toc_data - tic_data, units = "secs")))

log_line(sprintf("  Model fitting: %.1f min", fit_time))

log_line(sprintf("  Saving: %.1f sec", as.numeric(toc_save - tic_save, units = "secs")))

log_line("================================================================================")

log_line("SUCCESS: fit_primary_vza_vEff.R completed")

sink(NULL)

cat("✓ Model saved: output/publish/fit_primary_vza_vEff.rds\n")

cat("✓ Log saved: output/logs/fit_primary_vza_vEff.log\n")

cat("✓ Next steps:\n")

cat("  1. Run: source('R/check_convergence_gate.R')\n")

cat("  2. Run: source('R/export_ppc_primary_pooled.R')\n")




