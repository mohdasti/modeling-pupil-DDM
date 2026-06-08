#!/usr/bin/env Rscript
# Generate table_effect_contrasts.csv from run_dir fixef_link_scale.csv
# This allows the report to use run_dir data for tbl-contrasts.
#
# Usage: Rscript scripts/generate_effect_contrasts_from_run.R [run_dir]
# Default: output/ddm_refits/runs/20260226_092110

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

args <- commandArgs(trailingOnly = TRUE)
run_dir <- if (length(args) > 0) args[1] else "output/ddm_refits/runs/20260226_092110"
tables_dir <- file.path(run_dir, "tables")
fixef_path <- file.path(tables_dir, "fixef_link_scale.csv")

if (!file.exists(fixef_path)) {
  stop("fixef_link_scale.csv not found at ", fixef_path)
}

fixef <- read_csv(fixef_path, show_col_types = FALSE)

# Filter to additive, probe_onset_locked (primary model)
fx <- fixef %>%
  filter(model == "additive", rt_type == "probe_onset_locked")

if (nrow(fx) == 0) {
  stop("No additive probe_onset_locked rows in fixef_link_scale.csv")
}

# Map term to Estimate, Q2.5, Q97.5 (handle both Q2.5 and q2.5)
q2_col <- if ("Q2.5" %in% names(fx)) "Q2.5" else "q2.5"
q97_col <- if ("Q97.5" %in% names(fx)) "Q97.5" else "q97.5"
est_col <- if ("Estimate" %in% names(fx)) "Estimate" else "mean"

get_row <- function(term_pattern, exact = FALSE) {
  if (exact) {
    r <- fx %>% filter(term == term_pattern)
  } else {
    r <- fx %>% filter(grepl(term_pattern, term))
  }
  if (nrow(r) == 0) return(tibble())
  r[1, ]
}

# Build contrasts from coefficients
# ROPE: v=0.02, bs=0.05, bias=0.05, ndt=0.02
rope_v <- 0.02
rope_bs <- 0.05
rope_bias <- 0.05
rope_ndt <- 0.02

approx_p_gt0 <- function(mean_val, q2, q97) {
  if (q97 < 0) return(0)
  if (q2 > 0) return(1)
  0.5
}

approx_p_in_rope <- function(mean_val, q2, q97, rope) {
  if (max(abs(q2), abs(q97)) < rope) return(1)
  if (min(abs(q2), abs(q97)) > rope) return(0)
  0.5
}

rows <- list()

# v (drift) contrasts - Intercept is the mu/drift intercept; exclude bs_, ndt_, bias_ prefixed
int_v <- get_row("Intercept", exact = TRUE)
hard_v <- fx %>% filter(term == "difficulty_3Hard")
easy_v <- fx %>% filter(term == "difficulty_3Easy")
eff_v <- fx %>% filter(term == "effort_conditionhigh")

if (nrow(int_v) > 0 && nrow(hard_v) > 0 && nrow(easy_v) > 0) {
  # Easy (absolute) = Intercept + difficulty_3Easy
  m_easy <- int_v[[est_col]] + easy_v[[est_col]]
  q2_easy <- int_v[[q2_col]] + easy_v[[q2_col]]
  q97_easy <- int_v[[q97_col]] + easy_v[[q97_col]]
  rows[[length(rows) + 1]] <- tibble(
    contrast = "Easy (absolute)",
    parameter = "v",
    mean = m_easy,
    q2.5 = q2_easy,
    q97.5 = q97_easy,
    p_gt0 = approx_p_gt0(m_easy, q2_easy, q97_easy),
    p_lt0 = 1 - approx_p_gt0(m_easy, q2_easy, q97_easy),
    p_in_rope = approx_p_in_rope(m_easy, q2_easy, q97_easy, rope_v)
  )

  # Hard (absolute) = Intercept + difficulty_3Hard
  m_hard <- int_v[[est_col]] + hard_v[[est_col]]
  q2_hard <- int_v[[q2_col]] + hard_v[[q2_col]]
  q97_hard <- int_v[[q97_col]] + hard_v[[q97_col]]
  rows[[length(rows) + 1]] <- tibble(
    contrast = "Hard (absolute)",
    parameter = "v",
    mean = m_hard,
    q2.5 = q2_hard,
    q97.5 = q97_hard,
    p_gt0 = approx_p_gt0(m_hard, q2_hard, q97_hard),
    p_lt0 = 1 - approx_p_gt0(m_hard, q2_hard, q97_hard),
    p_in_rope = approx_p_in_rope(m_hard, q2_hard, q97_hard, rope_v)
  )

  # Easy - Hard = difficulty_3Easy - difficulty_3Hard (CI: lower = easy_q2.5 - hard_q97.5, upper = easy_q97.5 - hard_q2.5)
  m_eh <- easy_v[[est_col]] - hard_v[[est_col]]
  q2_eh <- easy_v[[q2_col]] - hard_v[[q97_col]]
  q97_eh <- easy_v[[q97_col]] - hard_v[[q2_col]]
  rows[[length(rows) + 1]] <- tibble(
    contrast = "Easy - Hard",
    parameter = "v",
    mean = m_eh,
    q2.5 = q2_eh,
    q97.5 = q97_eh,
    p_gt0 = approx_p_gt0(m_eh, q2_eh, q97_eh),
    p_lt0 = 1 - approx_p_gt0(m_eh, q2_eh, q97_eh),
    p_in_rope = approx_p_in_rope(m_eh, q2_eh, q97_eh, rope_v)
  )

  # Easy - Standard = difficulty_3Easy
  rows[[length(rows) + 1]] <- tibble(
    contrast = "Easy - Standard",
    parameter = "v",
    mean = easy_v[[est_col]],
    q2.5 = easy_v[[q2_col]],
    q97.5 = easy_v[[q97_col]],
    p_gt0 = approx_p_gt0(easy_v[[est_col]], easy_v[[q2_col]], easy_v[[q97_col]]),
    p_lt0 = 1 - approx_p_gt0(easy_v[[est_col]], easy_v[[q2_col]], easy_v[[q97_col]]),
    p_in_rope = approx_p_in_rope(easy_v[[est_col]], easy_v[[q2_col]], easy_v[[q97_col]], rope_v)
  )

  # Hard - Standard = difficulty_3Hard
  rows[[length(rows) + 1]] <- tibble(
    contrast = "Hard - Standard",
    parameter = "v",
    mean = hard_v[[est_col]],
    q2.5 = hard_v[[q2_col]],
    q97.5 = hard_v[[q97_col]],
    p_gt0 = approx_p_gt0(hard_v[[est_col]], hard_v[[q2_col]], hard_v[[q97_col]]),
    p_lt0 = 1 - approx_p_gt0(hard_v[[est_col]], hard_v[[q2_col]], hard_v[[q97_col]]),
    p_in_rope = approx_p_in_rope(hard_v[[est_col]], hard_v[[q2_col]], hard_v[[q97_col]], rope_v)
  )
}

if (nrow(eff_v) > 0) {
  rows[[length(rows) + 1]] <- tibble(
    contrast = "High - Low",
    parameter = "v",
    mean = eff_v[[est_col]],
    q2.5 = eff_v[[q2_col]],
    q97.5 = eff_v[[q97_col]],
    p_gt0 = approx_p_gt0(eff_v[[est_col]], eff_v[[q2_col]], eff_v[[q97_col]]),
    p_lt0 = 1 - approx_p_gt0(eff_v[[est_col]], eff_v[[q2_col]], eff_v[[q97_col]]),
    p_in_rope = approx_p_in_rope(eff_v[[est_col]], eff_v[[q2_col]], eff_v[[q97_col]], rope_v)
  )
}

# bs (boundary) contrasts
bs_hard <- fx %>% filter(term == "bs_difficulty_3Hard")
bs_easy <- fx %>% filter(term == "bs_difficulty_3Easy")
bs_eff  <- fx %>% filter(term == "bs_effort_conditionhigh")

if (nrow(bs_easy) > 0) {
  rows[[length(rows) + 1]] <- tibble(
    contrast = "difficulty_levelEasy",
    parameter = "bs",
    mean = bs_easy[[est_col]],
    q2.5 = bs_easy[[q2_col]],
    q97.5 = bs_easy[[q97_col]],
    p_gt0 = approx_p_gt0(bs_easy[[est_col]], bs_easy[[q2_col]], bs_easy[[q97_col]]),
    p_lt0 = 1 - approx_p_gt0(bs_easy[[est_col]], bs_easy[[q2_col]], bs_easy[[q97_col]]),
    p_in_rope = approx_p_in_rope(bs_easy[[est_col]], bs_easy[[q2_col]], bs_easy[[q97_col]], rope_bs)
  )
}
if (nrow(bs_hard) > 0) {
  rows[[length(rows) + 1]] <- tibble(
    contrast = "difficulty_levelHard",
    parameter = "bs",
    mean = bs_hard[[est_col]],
    q2.5 = bs_hard[[q2_col]],
    q97.5 = bs_hard[[q97_col]],
    p_gt0 = approx_p_gt0(bs_hard[[est_col]], bs_hard[[q2_col]], bs_hard[[q97_col]]),
    p_lt0 = 1 - approx_p_gt0(bs_hard[[est_col]], bs_hard[[q2_col]], bs_hard[[q97_col]]),
    p_in_rope = approx_p_in_rope(bs_hard[[est_col]], bs_hard[[q2_col]], bs_hard[[q97_col]], rope_bs)
  )
}

if (nrow(bs_eff) > 0) {
  rows[[length(rows) + 1]] <- tibble(
    contrast = "High - Low",
    parameter = "bs",
    mean = bs_eff[[est_col]],
    q2.5 = bs_eff[[q2_col]],
    q97.5 = bs_eff[[q97_col]],
    p_gt0 = approx_p_gt0(bs_eff[[est_col]], bs_eff[[q2_col]], bs_eff[[q97_col]]),
    p_lt0 = 1 - approx_p_gt0(bs_eff[[est_col]], bs_eff[[q2_col]], bs_eff[[q97_col]]),
    p_in_rope = approx_p_in_rope(bs_eff[[est_col]], bs_eff[[q2_col]], bs_eff[[q97_col]], rope_bs)
  )
}

# bias and ndt
bias_eff <- fx %>% filter(term == "bias_effort_conditionhigh")
ndt_eff <- fx %>% filter(grepl("^ndt_", term), grepl("effort|high", term, ignore.case = TRUE))

if (nrow(bias_eff) > 0) {
  rows[[length(rows) + 1]] <- tibble(
    contrast = "effort_conditionHigh_40_MVC",
    parameter = "bias",
    mean = bias_eff[[est_col]],
    q2.5 = bias_eff[[q2_col]],
    q97.5 = bias_eff[[q97_col]],
    p_gt0 = approx_p_gt0(bias_eff[[est_col]], bias_eff[[q2_col]], bias_eff[[q97_col]]),
    p_lt0 = 1 - approx_p_gt0(bias_eff[[est_col]], bias_eff[[q2_col]], bias_eff[[q97_col]]),
    p_in_rope = approx_p_in_rope(bias_eff[[est_col]], bias_eff[[q2_col]], bias_eff[[q97_col]], rope_bias)
  )
}

# ndt effort (if model has it - primary has ndt intercept only, so this may be empty)
if (nrow(ndt_eff) > 0 && any(grepl("effort|high", ndt_eff$term, ignore.case = TRUE))) {
  ndt_eff_row <- ndt_eff %>% filter(grepl("effort|high", term, ignore.case = TRUE)) %>% slice(1)
  rows[[length(rows) + 1]] <- tibble(
    contrast = "effort_conditionHigh_40_MVC",
    parameter = "ndt",
    mean = ndt_eff_row[[est_col]],
    q2.5 = ndt_eff_row[[q2_col]],
    q97.5 = ndt_eff_row[[q97_col]],
    p_gt0 = approx_p_gt0(ndt_eff_row[[est_col]], ndt_eff_row[[q2_col]], ndt_eff_row[[q97_col]]),
    p_lt0 = 1 - approx_p_gt0(ndt_eff_row[[est_col]], ndt_eff_row[[q2_col]], ndt_eff_row[[q97_col]]),
    p_in_rope = approx_p_in_rope(ndt_eff_row[[est_col]], ndt_eff_row[[q2_col]], ndt_eff_row[[q97_col]], rope_ndt)
  )
}

out <- bind_rows(rows)
if (nrow(out) == 0) {
  stop("No contrasts could be built from fixef. Check factor structure.")
}

out <- out %>% mutate(credible = if_else(p_gt0 > 0.95 | p_lt0 > 0.95, "credible", "not_credible"))

write_csv(out, file.path(tables_dir, "table_effect_contrasts.csv"))
cat("✓ Saved:", file.path(tables_dir, "table_effect_contrasts.csv"), "\n")
cat("  Rows:", nrow(out), "\n")
