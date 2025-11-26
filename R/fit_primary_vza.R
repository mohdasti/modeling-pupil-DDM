# R/fit_primary_vza.R

# Refit only the primary "difficulty maps v+z+a" model, with gentle compute use.



suppressPackageStartupMessages({

  library(brms)

  library(cmdstanr)

  library(dplyr)

  library(readr)

  library(posterior)

})



# ---------- logging helpers ----------

timestamp <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")

log_line <- function(...) {

  cat("[", timestamp(), "] ", paste0(..., collapse = ""), "\n", sep = "")

  flush.console()

}



# ---------- paths ----------

# UPDATED: Use DDM-only data file with response-side coding
# Legacy script - consider using 04_computational_modeling/drift_diffusion/fit_primary_vza.R instead
DATA_DDM_ONLY <- "data/analysis_ready/bap_ddm_only_ready.csv"
DATA_DDM_PUPIL <- "data/analysis_ready/bap_ddm_pupil_ready.csv"
DATA <- if (file.exists(DATA_DDM_ONLY)) DATA_DDM_ONLY else if (file.exists(DATA_DDM_PUPIL)) DATA_DDM_PUPIL else "data/analysis_ready/bap_ddm_ready.csv"

OUT_DIR <- "output/models"

PUBLISH_DIR <- "output/publish"

LOG_DIR <- "output/logs"

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

dir.create(PUBLISH_DIR, showWarnings = FALSE, recursive = TRUE)

dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)

LOG_FILE <- file.path(LOG_DIR, "fit_primary_vza.log")

sink(LOG_FILE, append = TRUE, split = TRUE)

on.exit(sink(NULL), add = TRUE)

log_line("================================================================================")

log_line("START fit_primary_vza.R")

log_line("Working directory: ", getwd())

log_line("Output dir: ", OUT_DIR, " | Publish dir: ", PUBLISH_DIR)



# ---------- data ----------

tic_all <- Sys.time()

log_line("Loading data: ", DATA)

tic_data <- Sys.time()

dd <- read_csv(DATA, show_col_types = FALSE)

# CRITICAL UPDATE: Use response-side coding (dec_upper) instead of accuracy coding
# Check for dec_upper column (response-side coding)
if ("dec_upper" %in% names(dd)) {
  log_line("Found 'dec_upper' column - using response-side coding")
  log_line("  Upper boundary (1) = 'Different', Lower boundary (0) = 'Same'")
  # Use dec_upper directly - no need to derive decision
  dd$decision <- dd$dec_upper
} else {
  log_line("WARNING: 'dec_upper' not found - falling back to accuracy coding", level = "WARN")
  log_line("  This script should use response-side coding. Consider using updated script:")
  log_line("  04_computational_modeling/drift_diffusion/fit_primary_vza.R")
  # Fallback to old logic (for backward compatibility only)
  if (!"decision" %in% names(dd)) {
    if ("iscorr" %in% names(dd)) {
      dd$decision <- as.integer(dd$iscorr)
      log_line("Derived 'decision' from 'iscorr' (accuracy coding - NOT RECOMMENDED)")
    } else {
      stop("Neither 'dec_upper' nor 'iscorr' found. Run data preparation scripts first.")
    }
  }
}

# Coerce types and factor encodings
dd <- dd %>%
  mutate(
    subject_id = factor(subject_id),
    task = factor(task),                        # "ADT","VDT"
    effort_condition = factor(effort_condition, levels = c("Low_5_MVC","High_MVC")),
    difficulty_level = factor(difficulty_level, levels = c("Standard","Hard","Easy")),
    decision = as.integer(decision)             # 1=correct, 0=incorrect
  )

log_line("Data loaded. N=", nrow(dd), ", subjects=", length(unique(dd$subject_id)))

log_line(sprintf("Data load time: %.1f seconds", as.numeric(difftime(Sys.time(), tic_data, units = "secs"))))



# ---------- family ----------

fam <- wiener(link_bs="log", link_ndt="log", link_bias="logit")



# ---------- formulas (primary model: difficulty -> v + bs + bias; ndt with small condition effects) ----------

form <- bf(
  rt | dec(decision) ~ difficulty_level + task + effort_condition + (1|subject_id),  # Uses dec_upper if available
  bs   ~ difficulty_level + task + (1|subject_id),
  ndt  ~ task + effort_condition,  # small condition effects, no random effects
  bias ~ difficulty_level + task + (1|subject_id)
)



# ---------- priors (OA-friendly; response-signal) ----------

pri <- c(

  prior(normal(0, 1),               class="Intercept"),                 # v intercept

  prior(normal(log(1.7), 0.30),     class="Intercept", dpar="bs"),      # a ≈ 1.7

  prior(normal(log(0.23), 0.12),    class="Intercept", dpar="ndt"),     # t0 ≈ 230ms (tighter)

  prior(normal(0, 0.08),            class="b", dpar="ndt"),             # small NDT condition effects

  prior(normal(0, 0.5),             class="Intercept", dpar="bias"),    # z ~ 0.5

  prior(normal(0, 0.5),             class="b"),                         # default b on v

  prior(normal(0, 0.35),            class="b", dpar="bs"),

  prior(normal(0, 0.35),            class="b", dpar="bias"),

  prior(student_t(3,0,0.30),        class="sd")

)



# ---------- init (safe, with correct parameter names) ----------
# brms uses Intercept_ndt (not b_ndt_Intercept) for distributional parameter intercepts
# Initialize NDT intercept to safe value; let brms handle condition effects with tight priors

min_rt <- min(dd$rt, na.rm = TRUE)
safe_ndt <- min_rt * 0.3  # Use 30% of min RT as safe NDT (well below all RTs)
log_line(sprintf("Data check: min RT = %.3fs, safe NDT = %.3fs (log = %.3f)", 
                 min_rt, safe_ndt, log(safe_ndt)))

safe_init <- function(chain_id = 1) {
  # Initialize NDT intercept to safe value (well below min RT)
  # Condition effects will be initialized by brms default, constrained by tight priors (normal(0, 0.08))
  # Even if condition effects are +0.2, total NDT = exp(log(0.075) + 0.2) ≈ 0.092s, still safe
  list(
    Intercept_ndt = log(safe_ndt),  # ~75ms (30% of 250ms min RT)
    Intercept_bs  = log(1.5),       # boundary intercept
    Intercept_bias = 0,              # bias intercept (0 on logit = 0.5 bias)
    Intercept     = 0                # drift intercept
    # Note: NDT condition effects (b_ndt_taskVDT, b_ndt_effort_conditionHigh_MVC)
    # will be initialized by brms default method, constrained by tight priors
  )
}



# ---------- light compute defaults ----------

options(mc.cores = 3)

fit_file <- file.path(OUT_DIR, "primary_vza")

log_line("Beginning fit: primary_vza")

log_line("Sampler settings: chains=4, iter=8000, warmup=4000, cores=4, threads=2")

log_line("HMC control: adapt_delta=0.995, max_treedepth=15")

tic_fit <- Sys.time()

fit <- brm(

  form,

  data = dd, family = fam, prior = pri,

  chains = 4, iter = 8000, warmup = 4000, cores = 4,

  threads = threading(2),

  control = list(adapt_delta = 0.995, max_treedepth = 15),

  backend = "cmdstanr",

  file = fit_file, file_refit = "always",

  refresh = 200,

  init = safe_init,  # init=0: all parameters start at 0 on unconstrained scale

  seed = 20251116,

  save_pars = save_pars(all = TRUE)

)

fit_elapsed_min <- as.numeric(difftime(Sys.time(), tic_fit, units = "mins"))

log_line(sprintf("Fit completed. Wall time: %.1f minutes", fit_elapsed_min))



# ---------- detailed engine timings (if available) ----------

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



# ---------- save a compact summary for quick load later ----------

saveRDS(fit, file.path(PUBLISH_DIR, "fit_primary_vza.rds"))

cat("✓ primary v+z+a refit saved at: ", file.path(PUBLISH_DIR, "fit_primary_vza.rds"), "\n")



# ---------- final summary ----------

total_elapsed_min <- as.numeric(difftime(Sys.time(), tic_all, units = "mins"))

log_line(sprintf("TOTAL script runtime: %.1f minutes", total_elapsed_min))

log_line("END fit_primary_vza.R")

log_line("================================================================================")


