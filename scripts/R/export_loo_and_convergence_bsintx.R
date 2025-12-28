# R/export_loo_and_convergence.R

# Export LOO and convergence diagnostics for the primary v+z+a model

suppressPackageStartupMessages({

  library(brms)

  library(posterior)

  library(dplyr)

  library(readr)

  library(tidyr)

})



PUBLISH_DIR <- "output/publish"

dir.create(PUBLISH_DIR, showWarnings = FALSE, recursive = TRUE)



# ---- Logging ----

log_msg <- function(...) {

  msg <- paste(..., collapse = " ")

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  cat(sprintf("[%s] %s\n", timestamp, msg))

}



log_msg("================================================================================")

log_msg("START export_loo_and_convergence.R")

log_msg("Working directory:", getwd())



# ---- Load primary fit ----

fit_path <- file.path(PUBLISH_DIR, "fit_primary_vza_bsintx.rds")

if (!file.exists(fit_path)) {

  stop(sprintf("Model file not found: %s\nRun R/fit_primary_vza.R first.", fit_path))

}

log_msg("Loading model:", fit_path)

fit <- readRDS(fit_path)

log_msg("Model loaded successfully")



# ---- LOO for primary (will use saved pointwise if available) ----

log_msg("Computing LOO...")

loo_start <- Sys.time()



add_row <- function(name, fitobj) {

  log_msg(sprintf("  Computing LOO for: %s", name))

  lw <- loo(fitobj, moment_match = FALSE)

  tibble(

    model = name,

    elpd = lw$estimates["elpd_loo", "Estimate"],

    se   = lw$estimates["elpd_loo", "SE"],

    p_loo = lw$estimates["p_loo", "Estimate"]

  )

}



loo_rows <- list(

  add_row("v_z_a_bsintx", fit)

)

loo_time <- as.numeric(difftime(Sys.time(), loo_start, units = "secs"))

log_msg(sprintf("LOO computation completed in %.1f seconds", loo_time))



# Write LOO table

loo_tbl <- bind_rows(loo_rows) %>%

  arrange(desc(elpd)) %>%

  mutate(elpd_diff_from_best = elpd - max(elpd))



loo_csv <- file.path(PUBLISH_DIR, "table1_loo_primary_bsintx.csv")

write_csv(loo_tbl, loo_csv)

log_msg(sprintf("✓ LOO table written: %s", loo_csv))



# ---- Convergence diagnostics (primary) ----

log_msg("Extracting convergence diagnostics...")

# Use brmsfit methods directly (more reliable than converting to draws_df)

rh   <- rhat(fit)

essb <- ess_bulk(fit)

esst <- ess_tail(fit)



# Extract divergences from nuts_params

nuts <- nuts_params(fit)

n_divergences <- if (!is.null(nuts)) {

  div_param <- nuts[nuts$Parameter == "divergent__", ]

  if (nrow(div_param) > 0) {

    sum(div_param$Value == 1, na.rm = TRUE)

  } else {

    0

  }

} else {

  0

}



summ <- tibble(

  model = "v_z_a_bsintx",

  max_rhat = max(rh, na.rm = TRUE),

  min_bulk_ess = min(essb, na.rm = TRUE),

  min_tail_ess = min(esst, na.rm = TRUE),

  divergences = n_divergences

)



conv_csv <- file.path(PUBLISH_DIR, "table2_convergence_primary_bsintx.csv")

write_csv(summ, conv_csv)

log_msg(sprintf("✓ Convergence table written: %s", conv_csv))



# ---- Print summary ----

log_msg("")

log_msg("SUMMARY:")

log_msg(sprintf("  Max R-hat: %.4f %s", 

                summ$max_rhat, 

                ifelse(summ$max_rhat <= 1.01, "✓", "✗")))

# Handle Inf/NA values for ESS

bulk_ess_str <- ifelse(is.infinite(summ$min_bulk_ess) || is.na(summ$min_bulk_ess), 

                       "NA/Inf", 

                       sprintf("%.0f", summ$min_bulk_ess))

bulk_ess_check <- ifelse(is.infinite(summ$min_bulk_ess) || is.na(summ$min_bulk_ess),

                         "?", 

                         ifelse(summ$min_bulk_ess >= 400, "✓", "✗"))

log_msg(sprintf("  Min bulk ESS: %s %s", bulk_ess_str, bulk_ess_check))

tail_ess_str <- ifelse(is.infinite(summ$min_tail_ess) || is.na(summ$min_tail_ess), 

                       "NA/Inf", 

                       sprintf("%.0f", summ$min_tail_ess))

tail_ess_check <- ifelse(is.infinite(summ$min_tail_ess) || is.na(summ$min_tail_ess),

                         "?", 

                         ifelse(summ$min_tail_ess >= 400, "✓", "✗"))

log_msg(sprintf("  Min tail ESS: %s %s", tail_ess_str, tail_ess_check))

log_msg(sprintf("  Divergences: %d %s", 

                summ$divergences, 

                ifelse(summ$divergences == 0, "✓", "✗")))

log_msg("")

log_msg("================================================================================")

log_msg("COMPLETE")

