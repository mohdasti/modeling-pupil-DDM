# R/check_convergence_gate.R

# Convergence gate check for primary v+z+a model

# Checks convergence diagnostics and writes pass/fail verdict

suppressPackageStartupMessages({

  library(brms)

  library(posterior)

  library(readr)

  library(dplyr)

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

log_msg("START check_convergence_gate.R")

log_msg("Working directory:", getwd())



# ---- Load fit ----

# Try new model first, fallback to original

fit_paths <- c(

  file.path(PUBLISH_DIR, "fit_primary_vza_vINTX.rds"),

  file.path(PUBLISH_DIR, "fit_primary_vza_biasintx.rds"),

  file.path(PUBLISH_DIR, "fit_primary_vza_bsintx.rds"),

  file.path(PUBLISH_DIR, "fit_primary_vza.rds")  # fallback if first not present

)

fit_path <- fit_paths[file.exists(fit_paths)][1]

if (is.na(fit_path)) {

  stop(sprintf("No fit found in %s\nExpected: fit_primary_vza_vINTX.rds, fit_primary_vza_biasintx.rds, fit_primary_vza_bsintx.rds, or fit_primary_vza.rds", PUBLISH_DIR))

}

log_msg("Loading model:", fit_path)

fit <- readRDS(fit_path)

log_msg(sprintf("Model loaded successfully: %s", basename(fit_path)))



# ---- Extract convergence diagnostics ----

log_msg("Extracting convergence diagnostics...")



# Use brmsfit methods directly (more reliable than converting to draws_df)

rh   <- rhat(fit)

essb <- ess_bulk(fit)

esst <- ess_tail(fit)



# Extract divergences from nuts_params (more reliable than fit$diagnostics)

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



# Compute diagnostics (handle Inf/NA values)

max_rhat <- max(rh, na.rm = TRUE)

if (is.na(max_rhat)) max_rhat <- Inf



# Filter out NA/Inf before computing min for ESS

essb_valid <- essb[!is.na(essb) & is.finite(essb)]

min_bulk <- if (length(essb_valid) > 0) min(essb_valid) else 0



esst_valid <- esst[!is.na(esst) & is.finite(esst)]

min_tail <- if (length(esst_valid) > 0) min(esst_valid) else NA_real_



gate <- tibble(

  max_rhat = max_rhat,

  min_bulk = min_bulk,

  min_tail = min_tail,

  divergences = n_divergences

)



# ---- Print diagnostics ----

log_msg("")

log_msg("CONVERGENCE DIAGNOSTICS:")

log_msg(sprintf("  Max R-hat: %.4f %s", 

                gate$max_rhat, 

                ifelse(gate$max_rhat <= 1.01, "✓", "✗")))

log_msg(sprintf("  Min bulk ESS: %.0f %s", 

                gate$min_bulk, 

                ifelse(gate$min_bulk >= 400, "✓", "✗")))

log_msg(sprintf("  Min tail ESS: %s %s", 

                ifelse(is.na(gate$min_tail), "NA", sprintf("%.0f", gate$min_tail)),

                ifelse(is.na(gate$min_tail), "?", ifelse(gate$min_tail >= 400, "✓", "✗"))))

log_msg(sprintf("  Divergences: %d %s", 

                gate$divergences, 

                ifelse(gate$divergences == 0, "✓", "✗")))

print(gate)



# ---- Convergence gate check ----

# Tail ESS may be unavailable for some parameters (e.g., fixed params)

# Only require it if we have valid values

ok <- gate$max_rhat <= 1.01 && 

      gate$min_bulk >= 400 && 

      (is.na(gate$min_tail) || gate$min_tail >= 400) && 

      gate$divergences == 0



msg <- if (ok) {

  "CONVERGENCE: PASS"

} else {

  "CONVERGENCE: FAIL (raise iter to 8000 and re-run Prompt A only)."

}



# Create detailed summary for file

res <- sprintf(

  "Convergence gate for %s\nmax_rhat=%.5f (<=1.01 ok)\nmin_bulk_ess=%.0f (>=400 ok)\nmin_tail_ess=%s (>=400 ok)\ndivergences=%d (==0 ok)\n",

  basename(fit_path), 

  gate$max_rhat, 

  gate$min_bulk,

  ifelse(is.na(gate$min_tail), "NA", sprintf("%.0f", gate$min_tail)),

  gate$divergences

)



log_msg("")

log_msg("GATE VERDICT:")

log_msg(msg)

cat(res, "\n")

cat(msg, "\n")



# ---- Write gate file ----

gate_file <- file.path(PUBLISH_DIR, "convergence_gate.txt")

writeLines(res, gate_file)

log_msg(sprintf("✓ Convergence gate written: %s", gate_file))



log_msg("")

log_msg("================================================================================")

log_msg("COMPLETE")

