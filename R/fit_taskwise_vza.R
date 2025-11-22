# R/fit_taskwise_vza.R

# Fit separate models for ADT and VDT tasks
# Allows drift to calibrate independently for each task
# Formula: v ~ difficulty + effort, bs ~ difficulty, ndt ~ effort, bias ~ difficulty

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

LOG_FILE <- file.path(LOG_DIR, "fit_taskwise_vza.log")

sink(LOG_FILE, append = TRUE, split = TRUE)

on.exit(sink(NULL), add = TRUE)

log_line("================================================================================")

log_line("START fit_taskwise_vza.R")

log_line("Working directory: ", getwd())

log_line("Output dir: ", OUT_DIR, " | Publish dir: ", PUBLISH_DIR)



# --- data ---

tic_all <- Sys.time()

log_line("Loading data: ", DATA)

tic_data <- Sys.time()

dd_all <- read_csv(DATA, show_col_types = FALSE)

# Harmonize/derive decision column (1=correct, 0=incorrect)

if (!"decision" %in% names(dd_all)) {

  log_line("Column 'decision' not found; attempting to derive from alternatives...")

  if ("iscorr" %in% names(dd_all)) {

    dd_all$decision <- as.integer(dd_all$iscorr)

    log_line("Derived 'decision' from 'iscorr'.")

  } else if ("correct" %in% names(dd_all)) {

    dd_all$decision <- as.integer(dd_all$correct)

    log_line("Derived 'decision' from 'correct'.")

  } else if ("is_correct" %in% names(dd_all)) {

    dd_all$decision <- as.integer(dd_all$is_correct)

    log_line("Derived 'decision' from 'is_correct'.")

  } else if ("accuracy" %in% names(dd_all)) {

    dd_all$decision <- as.integer(dd_all$accuracy)

    log_line("Derived 'decision' from 'accuracy'.")

  } else if ("acc" %in% names(dd_all)) {

    dd_all$decision <- as.integer(dd_all$acc)

    log_line("Derived 'decision' from 'acc'.")

  } else {

    stop("ERROR: Could not find a column to derive 'decision'. Available columns: ",

         paste(names(dd_all), collapse = ", "), "\n",

         "Missing 'decision' (or equivalent).")

  }

}

dd_all <- dd_all |>

  mutate(

    subject_id = factor(subject_id),

    task = factor(task),

    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_MVC")),

    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),

    decision = as.integer(decision)

  )

toc_data <- Sys.time()

log_line(sprintf("Data loaded. N=%d rows, %d subjects. Time: %.1f sec",

                 nrow(dd_all), length(unique(dd_all$subject_id)), 

                 as.numeric(toc_data - tic_data, units = "secs")))

log_line(sprintf("Task breakdown: ADT=%d, VDT=%d",

                 sum(dd_all$task == "ADT"), sum(dd_all$task == "VDT")))



# --- fit function ---

fit_one <- function(task_tag) {

  log_line("================================================================================")

  log_line(sprintf("Fitting model for task: %s", task_tag))

  tic_task <- Sys.time()



  dd <- dd_all |> filter(task == task_tag) |> droplevels()

  log_line(sprintf("  Filtered data: N=%d rows, %d subjects",

                   nrow(dd), length(unique(dd$subject_id))))



  # Compute safe NDT for this task's data

  min_rt <- min(dd$rt, na.rm = TRUE)

  safe_ndt <- min_rt * 0.3

  log_line(sprintf("  Data check: min RT = %.3fs, safe NDT = %.3fs (log = %.3f)",

                   min_rt, safe_ndt, log(safe_ndt)))



  fam <- wiener(link_bs = "log", link_ndt = "log", link_bias = "logit")

  form <- bf(

    # DRIFT: difficulty + effort (no task term since we're fitting per-task)

    rt | dec(decision) ~ difficulty_level + effort_condition + (1 + difficulty_level | subject_id),

    # BOUNDARY: difficulty only (mains)

    bs   ~ difficulty_level + (1 | subject_id),

    # NDT: effort only (no task since per-task)

    ndt  ~ effort_condition,

    # BIAS: difficulty only (mains)

    bias ~ difficulty_level + (1 | subject_id)

  )

  log_line("  Formula:")

  log_line("    Drift: difficulty + effort + (1 + difficulty | subject)")

  log_line("    Boundary: difficulty + (1 | subject)")

  log_line("    NDT: effort")

  log_line("    Bias: difficulty + (1 | subject)")



  pri <- c(

    prior(normal(0, 1),                class = "Intercept"),

    prior(normal(log(1.7), 0.30),      class = "Intercept", dpar = "bs"),

    prior(normal(log(0.23), 0.12),    class = "Intercept", dpar = "ndt"),

    prior(normal(0, 0.5),              class = "Intercept", dpar = "bias"),

    prior(normal(0, 0.60),             class = "b"),                        # drift slopes

    prior(normal(0, 0.30),             class = "b", dpar = "bs"),

    prior(normal(0, 0.35),             class = "b", dpar = "bias"),

    prior(normal(0, 0.08),             class = "b", dpar = "ndt"),

    prior(student_t(3, 0, 0.30),      class = "sd"),

    prior(lkj(2),                      class = "cor")                        # for (1 + difficulty | subject)

  )



  # Safe init (data-aware, correct parameter names)

  safe_init <- function(chain_id = 1) {

    list(

      Intercept      = rnorm(1, 0, 0.2),                    # drift intercept

      Intercept_bs   = log(runif(1, 1.3, 1.9)),             # boundary intercept

      Intercept_ndt  = log(safe_ndt),                       # ndt intercept (task-specific)

      Intercept_bias = rnorm(1, 0, 0.1)                     # bias intercept

    )

  }



  # Sampling

  fit_file <- file.path(OUT_DIR, paste0("task_", task_tag, "_vza"))

  log_line("  Beginning fit...")

  log_line("  Sampler settings: chains=4, iter=8000, warmup=4000, cores=4, threads=2")

  log_line("  HMC control: adapt_delta=0.995, max_treedepth=15")

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

  log_line(sprintf("  Fit completed. Wall time: %.1f minutes (%.2f hours)", 

                   fit_time, fit_time / 60))



  # Save

  save_path <- file.path(PUBLISH_DIR, paste0("fit_task_", task_tag, "_vza.rds"))

  saveRDS(fit, save_path)

  log_line(sprintf("  Saved: %s", save_path))



  toc_task <- Sys.time()

  task_time <- as.numeric(toc_task - tic_task, units = "mins")

  log_line(sprintf("  Total time for %s: %.1f minutes", task_tag, task_time))



  invisible(TRUE)

}



# --- Fit both tasks ---

log_line("================================================================================")

log_line("Fitting ADT model...")

fit_one("ADT")



log_line("================================================================================")

log_line("Fitting VDT model...")

fit_one("VDT")



# --- Summary ---

toc_all <- Sys.time()

total_time <- as.numeric(toc_all - tic_all, units = "mins")

log_line("================================================================================")

log_line(sprintf("TOTAL TIME: %.1f minutes (%.2f hours)", total_time, total_time / 60))

log_line("================================================================================")

log_line("SUCCESS: fit_taskwise_vza.R completed")

log_line("Saved files:")

log_line("  - output/publish/fit_task_ADT_vza.rds")

log_line("  - output/publish/fit_task_VDT_vza.rds")

sink(NULL)

cat("✓ Saved ADT & VDT fits in output/publish/\n")

cat("✓ Next steps:\n")

cat("  1. Run: source('R/export_ppc_task_pooled.R')\n")


