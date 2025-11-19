# R/fit_primary_vza_vEff_censored.R

# Same model as fit_primary_vza_vEff.R but with top 2% RTs filtered out

# This is a robustness check, not the primary model

# Note: brms wiener() family doesn't support censoring, so we filter out top 2% RTs instead

suppressPackageStartupMessages({

  library(brms)

  library(cmdstanr)

  library(dplyr)

  library(readr)

  library(posterior)

})



# --- Set working directory for RStudio (optional) ---

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

}, error = function(e) {})



# --- logging helpers ---

timestamp <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")

log_line <- function(...) {

  cat("[", timestamp(), "] ", paste0(..., collapse = ""), "\n", sep = "")

  flush.console()

}



# --- dirs ---

DATA <- "data/analysis_ready/bap_ddm_ready_censored.csv"  # Use censored data

OUT_DIR <- "output/models"

PUBLISH_DIR <- "output/publish"

LOG_DIR <- "output/logs"

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

dir.create(PUBLISH_DIR, showWarnings = FALSE, recursive = TRUE)

dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)

LOG_FILE <- file.path(LOG_DIR, "fit_primary_vza_vEff_censored.log")

sink(LOG_FILE, append = TRUE, split = TRUE)

on.exit(sink(NULL), add = TRUE)

log_line("================================================================================")

log_line("START fit_primary_vza_vEff_censored.R (ROBUSTNESS CHECK)")

log_line("Working directory: ", getwd())

log_line("Filtering out top 2% RTs per cell (robustness check)")



# --- data ---

tic_all <- Sys.time()

log_line("Loading censored data: ", DATA)

tic_data <- Sys.time()

dd <- read_csv(DATA, show_col_types = FALSE)

# Ensure cens_flag exists

if (!"cens_flag" %in% names(dd)) {

  stop("ERROR: cens_flag column not found. Run R/prepare_censoring.R first.")

}

n_censored <- sum(dd$cens_flag, na.rm = TRUE)

pct_censored <- mean(dd$cens_flag, na.rm = TRUE) * 100

log_line(sprintf("Found %d trials in top 2%% (%.2f%%)", n_censored, pct_censored))

log_line("Filtering out top 2% RTs (robustness check)")

dd <- dd %>% filter(cens_flag == 0)

log_line(sprintf("After filtering: N=%d rows (removed %d)", nrow(dd), n_censored))

# Harmonize/derive decision column

if (!"decision" %in% names(dd)) {

  if ("iscorr" %in% names(dd)) {

    dd$decision <- as.integer(dd$iscorr)

  } else if ("correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$correct)

  } else if ("is_correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$is_correct)

  } else if ("accuracy" %in% names(dd)) {

    dd$decision <- as.integer(dd$accuracy)

  } else if ("acc" %in% names(dd)) {

    dd$decision <- as.integer(dd$acc)

  } else {

    stop("ERROR: Could not find a column to derive 'decision'.")

  }

}

dd <- dd |>

  mutate(

    subject_id = factor(subject_id),

    task = factor(task),

    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_MVC")),

    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),

    decision = as.integer(decision)

  )

toc_data <- Sys.time()

log_line(sprintf("Data loaded. N=%d rows, %d subjects. Time: %.1f sec",

                 nrow(dd), length(unique(dd$subject_id)), as.numeric(toc_data - tic_data, units = "secs")))



# --- family & formula (same as vEff) ---

fam <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")

form <- bf(

  rt | dec(decision) ~ difficulty_level + task + effort_condition + (1 + difficulty_level | subject_id),

  bs   ~ difficulty_level + task + (1 | subject_id),

  ndt  ~ task + effort_condition,

  bias ~ difficulty_level + task + (1 | subject_id)

)

log_line("Formula specified (top 2% RTs filtered out):")

log_line("  Drift: difficulty + task + effort + (1 + difficulty | subject)")

log_line("  Boundary: difficulty + task + (1 | subject)")

log_line("  NDT: task + effort")

log_line("  Bias: difficulty + task + (1 | subject)")



# --- priors (same as vEff) ---

pri <- c(

  prior(normal(0, 1),                class = "Intercept"),

  prior(normal(log(1.7), 0.30),      class = "Intercept", dpar = "bs"),

  prior(normal(log(0.23), 0.12),    class = "Intercept", dpar = "ndt"),

  prior(normal(0, 0.5),              class = "Intercept", dpar = "bias"),

  prior(normal(0, 0.70),             class = "b"),                        # drift slopes wider

  prior(normal(0, 0.25),             class = "b", dpar = "bs"),             # boundary slopes tighter

  prior(normal(0, 0.35),             class = "b", dpar = "bias"),

  prior(normal(0, 0.08),             class = "b", dpar = "ndt"),

  prior(student_t(3, 0, 0.30),      class = "sd"),

  prior(lkj(2),                      class = "cor")

)

log_line("Priors specified (same as vEff)")



# --- safe init ---

min_rt <- min(dd$rt, na.rm = TRUE)

safe_ndt <- min_rt * 0.3

log_line(sprintf("Data check: min RT = %.3fs, safe NDT = %.3fs (log = %.3f)",

                 min_rt, safe_ndt, log(safe_ndt)))

safe_init <- function(chain_id = 1) {

  list(

    Intercept      = rnorm(1, 0, 0.2),

    Intercept_bs   = log(runif(1, 1.3, 1.9)),

    Intercept_ndt  = log(safe_ndt),

    Intercept_bias = rnorm(1, 0, 0.1)

  )

}



# --- sampling ---

# Reduce cores/threads to avoid system resource limits

options(mc.cores = 2)

fit_file <- file.path(OUT_DIR, "primary_vza_vEff_censored")

log_line("Beginning fit: primary_vza_vEff_censored (ROBUSTNESS CHECK)")

log_line("Sampler settings: chains=4, iter=8000, warmup=4000, cores=2, threads=1 (reduced for robustness)")

log_line("HMC control: adapt_delta=0.995, max_treedepth=15")

tic_fit <- Sys.time()

fit <- brm(

  form,

  data = dd,

  family = fam,

  prior = pri,

  chains = 4,

  iter = 8000,

  warmup = 4000,

  cores = 2,  # Reduced to avoid fork errors

  threads = threading(1),  # Reduced to avoid fork errors

  control = list(adapt_delta = 0.995, max_treedepth = 15),

  backend = "cmdstanr",

  file = fit_file,

  file_refit = "always",

  refresh = 200,

  init = safe_init,

  seed = 20251117,

  save_pars = save_pars(all = TRUE)

)

toc_fit <- Sys.time()

fit_time <- as.numeric(toc_fit - tic_fit, units = "mins")

log_line(sprintf("Fit completed. Wall time: %.1f minutes (%.2f hours)", fit_time, fit_time / 60))



# --- save ---

tic_save <- Sys.time()

saveRDS(fit, file.path(PUBLISH_DIR, "fit_primary_vza_vEff_censored.rds"))

toc_save <- Sys.time()

log_line(sprintf("Saved: %s (%.1f sec)", 

                 file.path(PUBLISH_DIR, "fit_primary_vza_vEff_censored.rds"),

                 as.numeric(toc_save - tic_save, units = "secs")))



# --- summary timing ---

toc_all <- Sys.time()

total_time <- as.numeric(toc_all - tic_all, units = "mins")

log_line("================================================================================")

log_line(sprintf("TOTAL TIME: %.1f minutes (%.2f hours)", total_time, total_time / 60))

log_line("================================================================================")

log_line("SUCCESS: fit_primary_vza_vEff_censored.R completed (ROBUSTNESS CHECK)")

sink(NULL)

cat("✓ Model saved: output/publish/fit_primary_vza_vEff_censored.rds\n")

cat("✓ This is a robustness check - compare PPCs with uncensored fit\n")

