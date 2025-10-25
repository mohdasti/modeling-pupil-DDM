# --- scripts/pupil/compute_phasic_features.R ---
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(purrr) })

# Config (idempotent)
PHASIC_WINDOW_LOWER <- getOption("PHASIC_WINDOW_LOWER", 200L)
PHASIC_WINDOW_UPPER <- getOption("PHASIC_WINDOW_UPPER", 900L)
RUN_SENSITIVITY     <- getOption("RUN_SENSITIVITY", FALSE)

# Expect trial-level long pupil data with columns:
# trial_id, time_ms (relative to stimulus onset), pupil, blink_flag (0/1), subj, condition, luminance
# Returns 1-row per trial with default slope + optional sensitivity features.
compute_phasic_features <- function(pupil_long_df) {
  stopifnot(all(c("trial_id","time_ms","pupil","blink_flag") %in% names(pupil_long_df)))

  # Filter to evoked window and valid samples
  w <- pupil_long_df %>%
    filter(time_ms >= PHASIC_WINDOW_LOWER,
           time_ms <= PHASIC_WINDOW_UPPER,
           blink_flag == 0)

  # --- Default feature: slope (OLS) within 200–900 ms ---
  slope_df <- w %>%
    group_by(trial_id) %>%
    summarize(
      phasic_slope = {
        if (n() < 5 || all(is.na(pupil))) NA_real_
        else coef(lm(pupil ~ time_ms))[2]
      },
      .groups = "drop"
    )

  if (!isTRUE(RUN_SENSITIVITY)) return(slope_df)

  # --- Sensitivity features (optional) ---
  sens_df <- w %>%
    group_by(trial_id) %>%
    summarize(
      phasic_peak  = if (all(is.na(pupil))) NA_real_ else max(pupil, na.rm = TRUE),
      phasic_auc   = if (all(is.na(pupil))) NA_real_ else sum(pupil, na.rm = TRUE) * mean(diff(unique(time_ms), lag=1), na.rm = TRUE),
      phasic_early = mean(pupil[time_ms >= 200 & time_ms < 500], na.rm = TRUE),
      phasic_late  = mean(pupil[time_ms >= 500 & time_ms <= 900], na.rm = TRUE),
      .groups = "drop"
    )

  dplyr::left_join(slope_df, sens_df, by = "trial_id")
}
# --- end file ---
