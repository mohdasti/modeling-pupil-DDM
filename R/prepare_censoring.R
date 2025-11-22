# R/prepare_censoring.R

# Prepare right-censoring indicator for top 2% RTs per cell

suppressPackageStartupMessages({

  library(dplyr)

  library(readr)

})



PUBLISH_DIR <- "output/publish"

DATA_IN <- "data/analysis_ready/bap_ddm_ready.csv"

DATA_OUT <- "data/analysis_ready/bap_ddm_ready_censored.csv"



# ---- Logging ----

log_msg <- function(...) {

  msg <- paste(..., collapse = " ")

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  cat(sprintf("[%s] %s\n", timestamp, msg))

}



log_msg("================================================================================")

log_msg("START prepare_censoring.R")

log_msg("Right-censoring top 2% RTs per task×effort×difficulty cell")



# ---- Load data ----

log_msg("Loading data:", DATA_IN)

dd <- read_csv(DATA_IN, show_col_types = FALSE)



# Derive decision column if needed

if (!"decision" %in% names(dd)) {

  if ("iscorr" %in% names(dd)) {

    dd$decision <- as.integer(dd$iscorr)

  } else if ("correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$correct)

  } else if ("is_correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$is_correct)

  } else if ("accuracy" %in% names(dd) || "acc" %in% names(dd)) {

    col_name <- ifelse("accuracy" %in% names(dd), "accuracy", "acc")

    dd$decision <- as.integer(dd[[col_name]])

  }

}



# ---- Create censoring indicator ----

dd <- dd %>%

  mutate(

    task = factor(task),

    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_MVC")),

    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy"))

  ) %>%

  group_by(task, effort_condition, difficulty_level) %>%

  mutate(

    rt_rank = rank(rt, ties.method = "average"),

    rt_n = n(),

    rt_pctile = (rt_rank - 1) / (rt_n - 1),  # 0 to 1 percentile

    cens_flag = as.integer(rt_pctile >= 0.98)  # Top 2% flagged as right-censored

  ) %>%

  ungroup() %>%

  select(-rt_rank, -rt_n, -rt_pctile)  # Clean up temporary columns



# ---- Summary ----

cens_summary <- dd %>%

  group_by(task, effort_condition, difficulty_level) %>%

  summarise(

    n = n(),

    n_censored = sum(cens_flag, na.rm = TRUE),

    pct_censored = (n_censored / n) * 100,

    min_rt = min(rt, na.rm = TRUE),

    max_rt = max(rt, na.rm = TRUE),

    cens_threshold = if (sum(cens_flag) > 0) max(rt[cens_flag == 1], na.rm = TRUE) else NA_real_,

    .groups = "drop"

  )



log_msg("")

log_msg("Censoring summary:")

print(cens_summary)

log_msg("")

log_msg(sprintf("Total trials: %d", nrow(dd)))

log_msg(sprintf("Total censored: %d (%.2f%%)", sum(dd$cens_flag, na.rm = TRUE), 

                mean(dd$cens_flag, na.rm = TRUE) * 100))



# ---- Save censored data ----

readr::write_csv(dd, DATA_OUT)

log_msg("")

log_msg(sprintf("✓ Saved censored data: %s", DATA_OUT))

log_msg("")

log_msg("================================================================================")

log_msg("COMPLETE")


