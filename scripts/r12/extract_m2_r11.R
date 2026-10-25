# Extract the r11 M2 effort × difficulty interactions.
# The r11 fit is read on the VM. This script does not sample.
#   Rscript scripts/r12/extract_m2_r11.R --dry-run
#   Rscript scripts/r12/extract_m2_r11.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)
dry <- "--dry-run" %in% args
ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)

DATA_DIR <- "data/analysis_ready/r12"
MD5_FILE <- file.path(DATA_DIR, "MD5SUMS")
if (!file.exists(MD5_FILE)) stop("Missing ", MD5_FILE, call. = FALSE)
for (line in readLines(MD5_FILE, warn = FALSE)) {
  if (!nzchar(line)) next
  bits <- strsplit(line, "  ", fixed = TRUE)[[1]]
  if (length(bits) != 2L) stop("Bad MD5SUMS line: ", line, call. = FALSE)
  path <- file.path(DATA_DIR, bits[2])
  got <- unname(tools::md5sum(path))
  if (!identical(got, bits[1])) stop(sprintf("md5 mismatch for %s", bits[2]), call. = FALSE)
}
suppressPackageStartupMessages(library(brms))
M2_F <- bf(
  rt | dec(choice_binary) ~ difficulty_3 * effort_condition + (1 | subject_id),
  bs ~ difficulty_3 * effort_condition + (1 | subject_id),
  ndt ~ 1,
  bias ~ task + effort_condition + (1 | subject_id)
)
if (!inherits(M2_F, "brmsformula")) stop("M2 formula was not built.", call. = FALSE)

OUT_ROOT <- "output/ddm_refits/runs"
id_file <- file.path(OUT_ROOT, "r11_latest_run_id.txt")
run_id <- if (file.exists(id_file)) trimws(readLines(id_file, warn = FALSE)[1]) else ""
run_dir <- if (nzchar(run_id)) file.path(OUT_ROOT, run_id) else ""
if (!nzchar(run_dir) || !file.exists(file.path(run_dir, "tables", "convergence.csv"))) {
  cands <- Sys.glob(file.path(OUT_ROOT, "r11_*", "tables", "convergence.csv"))
  if (!length(cands)) stop("No r11 convergence table found.", call. = FALSE)
  run_dir <- dirname(dirname(cands[order(file.info(cands)$mtime, decreasing = TRUE)][1]))
  run_id <- basename(run_dir)
}
if (!grepl("^r11_[0-9]{8}_[0-9]{6}$", run_id)) stop("Not an r11 run id: ", run_id, call. = FALSE)
conv_path <- file.path(run_dir, "tables", "convergence.csv")
fit_path <- file.path(run_dir, "models", "M2__probe_onset_locked__thr0.20.rds")
conv <- read_csv(conv_path, show_col_types = FALSE)
m2 <- conv[conv$model == "M2", , drop = FALSE]
if (nrow(m2) != 1L) stop("r11 convergence table has no single M2 row.", call. = FALSE)
if (!isTRUE(m2$passes) || m2$max_rhat >= 1.01 || m2$min_bulk_ess < 400 ||
    m2$min_tail_ess < 400 || m2$divergences != 0) {
  stop("r11 M2 row does not pass the convergence rule.", call. = FALSE)
}
if (!file.exists(fit_path)) {
  if (dry) {
    message("dry-run ok: r11 convergence table ", conv_path, " has a passing M2 row. The fit ",
            fit_path, " is not on this machine; the provenance check runs on the VM.")
    quit(save = "no", status = 0)
  }
  stop("r11 M2 fit is missing: ", fit_path, call. = FALSE)
}

started <- as.POSIXct(strptime(sub("^r11_", "", run_id), "%Y%m%d_%H%M%S"))
if (is.na(started)) stop("Could not parse the r11 start time from ", run_id, call. = FALSE)
mtime <- file.info(fit_path)$mtime
if (is.na(mtime) || mtime <= started) {
  stop("M2 fit was written at ", format(mtime), ", which is not after the r11 start ", format(started), call. = FALSE)
}

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
})
fit <- readRDS(fit_path)
if (!inherits(fit, "brmsfit")) stop("The M2 file is not a brms fit.", call. = FALSE)
draws <- posterior::as_draws_df(fit)
s <- posterior::summarise_draws(
  fit, rhat = posterior::rhat, ess_bulk = posterior::ess_bulk, ess_tail = posterior::ess_tail
)
np <- brms::nuts_params(fit)
div <- sum(np$Parameter == "divergent__" & np$Value > 0)
got_rhat <- max(s$rhat, na.rm = TRUE)
got_bulk <- min(s$ess_bulk, na.rm = TRUE)
got_tail <- min(s$ess_tail, na.rm = TRUE)
tol_rhat <- 1e-4
tol_ess <- 1
if (abs(got_rhat - m2$max_rhat) > tol_rhat || abs(got_bulk - m2$min_bulk_ess) > tol_ess ||
    abs(got_tail - m2$min_tail_ess) > tol_ess || div != m2$divergences) {
  stop(sprintf(
    "M2 draws do not match the r11 convergence table (Rhat %.6f vs %.6f, bulk %.1f vs %.1f, tail %.1f vs %.1f, div %d vs %d).",
    got_rhat, m2$max_rhat, got_bulk, m2$min_bulk_ess, got_tail, m2$min_tail_ess, div, m2$divergences
  ), call. = FALSE)
}
n_iter <- tryCatch(brms::niterations(fit), error = function(e) NA_integer_)
if (brms::nchains(fit) != m2$chains || !(n_iter %in% c(m2$iter, m2$iter - m2$warmup))) {
  stop("M2 chain or iteration count does not match the r11 table.", call. = FALSE)
}

if (dry) {
  message("dry-run ok: r11 M2 at ", fit_path, " matches ", conv_path, ". No extract written.")
  quit(save = "no", status = 0)
}

quant <- function(name, x) {
  q <- quantile(x, c(0.025, 0.5, 0.975))
  tibble(
    quantity = name, median = unname(q[2]), q025 = unname(q[1]), q975 = unname(q[3]),
    p_positive = mean(x > 0), p_negative = mean(x < 0)
  )
}
need <- c(
  "b_difficulty_3Hard:effort_conditionhigh",
  "b_difficulty_3Easy:effort_conditionhigh",
  "b_bs_difficulty_3Hard:effort_conditionhigh",
  "b_bs_difficulty_3Easy:effort_conditionhigh"
)
missing <- setdiff(need, names(draws))
if (length(missing)) stop("M2 is missing: ", paste(missing, collapse = ", "), call. = FALSE)
drift_hard <- draws[["b_difficulty_3Hard:effort_conditionhigh"]]
drift_easy <- draws[["b_difficulty_3Easy:effort_conditionhigh"]]
bs_hard <- draws[["b_bs_difficulty_3Hard:effort_conditionhigh"]]
bs_easy <- draws[["b_bs_difficulty_3Easy:effort_conditionhigh"]]
out <- bind_rows(
  quant("drift_hard_x_high", drift_hard),
  quant("drift_easy_x_high", drift_easy),
  quant("boundary_hard_x_high", bs_hard),
  quant("boundary_easy_x_high", bs_easy),
  quant("drift_hard_minus_easy_x_high", drift_hard - drift_easy),
  quant("boundary_hard_minus_easy_x_high", bs_hard - bs_easy)
)
write_csv(out, "m2_r11_interactions.csv")
message("Wrote m2_r11_interactions.csv from ", fit_path)
