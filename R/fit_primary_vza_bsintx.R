# R/fit_primary_vza_bsintx.R

# Primary v+z+a model with:
# 1. Boundary interaction: difficulty × task (targets Easy/VDT tails)
# 2. Random slope on drift: (1 + difficulty_level | subject_id)

suppressPackageStartupMessages({

  library(brms)

  library(cmdstanr)

  library(dplyr)

  library(readr)

  library(posterior)

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

LOG_FILE <- file.path(LOG_DIR, "fit_primary_vza_bsintx.log")

sink(LOG_FILE, append = TRUE, split = TRUE)

on.exit(sink(NULL), add = TRUE)

log_line("================================================================================")

log_line("START fit_primary_vza_bsintx.R")

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

    log_line("ERROR: Could not find a column to derive 'decision'. Available columns:")

    log_line(paste(names(dd), collapse = ", "))

    stop("Missing 'decision' (or equivalent). Expected one of: decision, correct, is_correct, accuracy, acc.")

  }

}

# Coerce types and factor encodings

dd <- dd %>%

  mutate(

    subject_id = factor(subject_id),

    task = factor(task),                                # "ADT","VDT"

    effort_condition = factor(effort_condition, levels = c("Low_5_MVC","High_MVC")),

    difficulty_level = factor(difficulty_level, levels = c("Standard","Hard","Easy")),

    decision = as.integer(decision)                     # 1=correct, 0=incorrect

  )

log_line("Data loaded. N=", nrow(dd), ", subjects=", length(unique(dd$subject_id)))

log_line(sprintf("Data load time: %.1f seconds", as.numeric(difftime(Sys.time(), tic_data, units = "secs"))))



# --- family ---

fam <- wiener(link_bs="log", link_ndt="log", link_bias="logit")



# --- formulas ---

# 1) drift: add random slope of difficulty at subject

# 2) boundary: add difficulty × task interaction (targets Easy/VDT tails)

# 3) ndt: small condition effects, no RE (stable)

# 4) bias: keep difficulty + task main effects

form <- bf(

  rt | dec(decision) ~ difficulty_level + task + effort_condition + (1 + difficulty_level | subject_id),

  bs   ~ difficulty_level * task + (1 | subject_id),

  ndt  ~ task + effort_condition,

  bias ~ difficulty_level + task + (1 | subject_id)

)



# --- priors ---

pri <- c(

  prior(normal(0, 1),               class="Intercept"),                 # drift intercept

  prior(normal(log(1.7), 0.30),     class="Intercept", dpar="bs"),      # boundary ~1.7

  prior(normal(log(0.23), 0.12),    class="Intercept", dpar="ndt"),     # ndt ~230ms

  prior(normal(0, 0.5),             class="Intercept", dpar="bias"),    # bias ~0.5 (logit)

  prior(normal(0, 0.5),             class="b"),                         # drift slopes

  prior(normal(0, 0.25),            class="b", dpar="bs"),              # tighter bs slopes

  prior(normal(0, 0.35),            class="b", dpar="bias"),

  prior(normal(0, 0.08),            class="b", dpar="ndt"),             # tiny ndt condition effects

  prior(student_t(3, 0, 0.30),      class="sd"),

  prior(lkj(2),                     class="cor")                        # for (1 + difficulty | subject)

)



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

fit_file <- file.path(OUT_DIR, "primary_vza_bsintx")

log_line("Beginning fit: primary_vza_bsintx")

log_line("Sampler settings: chains=4, iter=8000, warmup=4000, cores=4, threads=2")

log_line("HMC control: adapt_delta=0.995, max_treedepth=15")

log_line("Model features: boundary interaction (difficulty × task), random slope on drift")

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

  seed = 20251116,

  save_pars = save_pars(all = TRUE)

)

fit_elapsed_min <- as.numeric(difftime(Sys.time(), tic_fit, units = "mins"))

log_line(sprintf("Fit completed. Wall time: %.1f minutes", fit_elapsed_min))



# --- detailed engine timings (if available) ---

engine_times <- tryCatch({

  if (!is.null(fit$fit) && inherits(fit$fit, "CmdStanMCMC")) {

    tms <- fit$fit$time()

    list(total = tms$total, warmup = tms$warmup, sampling = tms$sampling)

  } else {

    NULL

  }

}, error = function(e) NULL)

if (!is.null(engine_times)) {

  log_line(sprintf("CmdStan times (seconds): total=%.1f, warmup=%.1f, sampling=%.1f",

                   engine_times$total, engine_times$warmup, engine_times$sampling))

} else {

  log_line("CmdStan timing details not available (non-CmdStan backend or structure changed).")

}



# --- save model ---

saveRDS(fit, file.path(PUBLISH_DIR, "fit_primary_vza_bsintx.rds"))

cat("✓ primary v+z+a (bs interaction + drift RE slope) saved at: ", 

    file.path(PUBLISH_DIR, "fit_primary_vza_bsintx.rds"), "\n")



# --- final summary ---

total_elapsed_min <- as.numeric(difftime(Sys.time(), tic_all, units = "mins"))

log_line(sprintf("TOTAL script runtime: %.1f minutes", total_elapsed_min))

log_line("END fit_primary_vza_bsintx.R")

log_line("================================================================================")


