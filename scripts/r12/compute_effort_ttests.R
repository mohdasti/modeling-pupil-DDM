# Grip and TEPR effort paired t-tests, and r(TEPR, RT), on the r12 sample.
# Same paired-t and Fisher-z summaries as scripts/r8/D_descriptives.R.
# The modeled TEPR is tepr_mean_465_765 (mean in the TEPR window minus the pre-probe
# baseline). The pre-squeeze contrast uses auc_b0. The slim ddm_pupil_r12_qc.csv
# omits grip_raw, so this reads the full r12 file, which is that QC sample plus
# the predictors.
#   Rscript scripts/r12/compute_effort_ttests.R --dry-run
#   Rscript scripts/r12/compute_effort_ttests.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

args <- commandArgs(trailingOnly = TRUE)
dry <- "--dry-run" %in% args
ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)

DATA_DIR <- "data/analysis_ready/r12"
MD5_FILE <- file.path(DATA_DIR, "MD5SUMS")
PUPIL_CSV <- file.path(DATA_DIR, "ddm_pupil_r12.csv")

if (!file.exists(MD5_FILE)) stop("Missing ", MD5_FILE, call. = FALSE)
for (line in readLines(MD5_FILE, warn = FALSE)) {
  if (!nzchar(line)) next
  bits <- strsplit(line, "  ", fixed = TRUE)[[1]]
  if (length(bits) != 2L) stop("Bad MD5SUMS line: ", line, call. = FALSE)
  path <- file.path(DATA_DIR, bits[2])
  got <- unname(tools::md5sum(path))
  if (!identical(got, bits[1])) stop(sprintf("md5 mismatch for %s", bits[2]), call. = FALSE)
}

qc <- read_csv(PUPIL_CSV, show_col_types = FALSE)
need <- c("subject_id", "task", "effort_condition", "tepr_mean_465_765", "auc_b0", "grip_raw", "tepr_c", "rt")
missing <- setdiff(need, names(qc))
if (length(missing)) stop("r12 file is missing: ", paste(missing, collapse = ", "), call. = FALSE)
if (nrow(qc) != 6299L) stop("Expected 6,299 r12 trials, found ", nrow(qc), call. = FALSE)

if (dry) {
  message(sprintf("dry-run ok: %d trials, %d participants. t-tests not computed.",
                  nrow(qc), dplyr::n_distinct(qc$subject_id)))
  quit(save = "no", status = 0)
}

paired_one <- function(df, value) {
  wide <- df %>%
    select(subject_id, task, effort_condition, all_of(value)) %>%
    tidyr::pivot_wider(names_from = effort_condition, values_from = all_of(value)) %>%
    filter(!is.na(high), !is.na(low))
  bind_rows(lapply(split(wide, wide$task), function(w) {
    diff <- w$high - w$low
    tt <- t.test(w$high, w$low, paired = TRUE)
    tibble(task = w$task[1], outcome = value, n_subjects = nrow(w),
           mean_high_minus_low = mean(diff), t = unname(tt$statistic),
           df = unname(tt$parameter), p = tt$p.value)
  }))
}

b1 <- qc[is.finite(qc$tepr_mean_465_765), ]
b0 <- qc[is.finite(qc$auc_b0), ]
subj_b1 <- b1 %>%
  group_by(subject_id, task, effort_condition) %>%
  summarise(tepr_mean_465_765 = mean(tepr_mean_465_765), .groups = "drop")
subj_b0 <- b0 %>%
  group_by(subject_id, task, effort_condition) %>%
  summarise(auc_b0 = mean(auc_b0), .groups = "drop")
pupil_tests <- bind_rows(
  paired_one(subj_b1, "tepr_mean_465_765"),
  paired_one(subj_b0, "auc_b0")
)

fisher_summary <- function(subject_rows) {
  z <- subject_rows$z
  k <- length(z)
  zbar <- mean(z)
  se <- if (k >= 2) sd(z) / sqrt(k) else NA_real_
  crit <- if (k >= 2) qt(0.975, k - 1) else NA_real_
  tibble(
    n_subjects = k, n_trials = sum(subject_rows$n),
    mean_r_fisher = tanh(zbar),
    ci_lo = if (is.finite(se)) tanh(zbar - crit * se) else NA_real_,
    ci_hi = if (is.finite(se)) tanh(zbar + crit * se) else NA_real_,
    mean_z = zbar, se_z = se
  )
}
subject_cor <- function(df) {
  bind_rows(lapply(split(df, df$subject_id), function(w) {
    n <- nrow(w)
    r <- if (n > 3 && sd(w$tepr_c) > 0 && sd(w$rt) > 0) cor(w$tepr_c, w$rt) else NA_real_
    tibble(subject_id = w$subject_id[1], n = n, r = r,
           z = if (is.finite(r)) atanh(pmin(pmax(r, -0.999999), 0.999999)) else NA_real_)
  }))
}
subj_all <- subject_cor(qc)
tepr_rt <- fisher_summary(subj_all[is.finite(subj_all$z), ])

grip_ok <- qc[is.finite(qc$grip_raw), ]
grip_subj <- grip_ok %>%
  group_by(subject_id, task, effort_condition) %>%
  summarise(grip_raw = mean(grip_raw), n_trials = n(), .groups = "drop")
paired_grip <- bind_rows(lapply(split(grip_subj, grip_subj$task), function(w) {
  wide <- tidyr::pivot_wider(w, id_cols = subject_id, names_from = effort_condition, values_from = grip_raw)
  wide <- wide[is.finite(wide$high) & is.finite(wide$low), ]
  tt <- t.test(wide$high, wide$low, paired = TRUE)
  tibble(task = w$task[1], outcome = "grip_raw", n_subjects = nrow(wide),
         mean_high_minus_low = mean(wide$high - wide$low),
         t = unname(tt$statistic), df = unname(tt$parameter), p = tt$p.value)
}))

OUT <- file.path(OUT_ROOT <- "output/ddm_refits/runs", "r12_effort_ttests")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
write_csv(bind_rows(paired_grip, pupil_tests), file.path(OUT, "effort_paired_t.csv"))
write_csv(tepr_rt, file.path(OUT, "tepr_rt_correlation.csv"))
message("Wrote ", OUT)
