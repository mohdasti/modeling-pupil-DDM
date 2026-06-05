# manuscript_paths.R — canonical paths for main manuscript figures (master setup)
# Source at top of every fig1–fig5 script:
#   source(here::here("06_visualization", "publication_figures", "manuscript_paths.R"))

suppressPackageStartupMessages(library(here))

repo_root <- here::here()

# ── Model RDS (read-only; do not re-fit) ──────────────────────────────────────
PATH_PRIMARY_MODEL <- file.path(
  repo_root,
  "output/ddm_refits/runs/20260226_092110/models",
  "additive__probe_onset_locked__thr0.20.rds"
)
PATH_FATIGUE_MODEL <- file.path(repo_root, "output/publish/fit_exploratory_fatigue_trajectory.rds")
PATH_HISTORY_MODEL <- file.path(repo_root, "output/publish/fit_exploratory_choice_history_hist.rds")
PATH_WSLS_MODEL    <- file.path(repo_root, "output/publish/fit_exploratory_choice_history_wsls.rds")

# ── Behavioral trial-level data ─────────────────────────────────────────────
PATH_BEHAVIORAL_DATA <- file.path(repo_root, "data/ddm_ready_data_unthresholded.csv")

# ── Figure output directory ───────────────────────────────────────────────────
PATH_FIG_OUT <- file.path(repo_root, "output/figures/manuscript")

stopifnot(
  file.exists(PATH_PRIMARY_MODEL),
  file.exists(PATH_FATIGUE_MODEL),
  file.exists(PATH_HISTORY_MODEL),
  file.exists(PATH_WSLS_MODEL),
  file.exists(PATH_BEHAVIORAL_DATA)
)
dir.create(PATH_FIG_OUT, recursive = TRUE, showWarnings = FALSE)
