#!/usr/bin/env Rscript
# Extended demographics and neuropsych descriptives + exploratory DDM correlations
# for Chapter 3 supplement (Appendix A9).

suppressPackageStartupMessages({
  library(tidyverse)
  library(broom)
  library(brms)
})

DEMO_FILE <- "data/raw/LC Aging Subject Data master spreadsheet - demographics.csv"
NP_FILE <- "data/raw/LC Aging Subject Data master spreadsheet - neuropsych.csv"
DDM_RUN_DIR <- Sys.getenv("DDM_RUN_DIR", "output/ddm_refits/runs/20260226_092110")
DDM_FIT <- file.path(DDM_RUN_DIR, "models/additive__probe_onset_locked__thr0.20.rds")
if (!file.exists(DDM_FIT)) {
  legacy <- "output/models/primary_vza.rds"
  if (file.exists(legacy)) {
    warning("Using legacy model ", legacy, " — set DDM_RUN_DIR to the canonical refit run.")
    DDM_FIT <- legacy
  } else {
    stop("DDM model not found at ", DDM_FIT, " or ", legacy)
  }
}
OUT_DIR <- "output/neuropsych_demographics"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

normalize_subject_id <- function(id) {
  id <- as.character(id)
  num <- str_extract(str_replace(id, "^BAP", ""), "\\d+")
  ifelse(!is.na(num), sprintf("BAP%03d", as.integer(num)), id)
}

partial_cor <- function(df, x, y, covars = c("age", "sex")) {
  sub <- df %>%
    filter(!is.na(.data[[x]]), !is.na(.data[[y]]))
  for (c in covars) {
    sub <- sub %>% filter(!is.na(.data[[c]]))
  }
  if (nrow(sub) < 12) {
    return(tibble(r = NA_real_, p = NA_real_, n = nrow(sub)))
  }
  sub$y <- sub[[y]]
  sub$x <- sub[[x]]
  m_x <- lm(as.formula(paste("x ~", paste(covars, collapse = " + "))), data = sub)
  m_y <- lm(as.formula(paste("y ~", paste(covars, collapse = " + "))), data = sub)
  ct <- cor.test(resid(m_x), resid(m_y))
  tibble(r = unname(ct$estimate), p = ct$p.value, n = nrow(sub))
}

demo <- read_csv(DEMO_FILE, skip = 1, show_col_types = FALSE) %>%
  transmute(
    subject_id = normalize_subject_id(`SUBJECT NUMBER_1`),
    age = suppressWarnings(as.numeric(`AGE AT BAP SESSION 1`)),
    sex = factor(trimws(tolower(SEX))),
    edu = suppressWarnings(as.numeric(str_extract(as.character(`EDU (years)`), "[0-9]+(?:\\.[0-9]+)?"))),
    hand = trimws(HAND),
    race = trimws(RACE),
    ethnicity = trimws(ETHNICITY)
  ) %>%
  filter(!is.na(subject_id), subject_id != "NA") %>%
  distinct(subject_id, .keep_all = TRUE)

np <- read_csv(NP_FILE, skip = 1, show_col_types = FALSE) %>%
  transmute(
    subject_id = normalize_subject_id(`SUBJECT NUMBER`),
    moca = suppressWarnings(as.numeric(`MoCA (phone screen; Out of 22)`)),
    wordlist_mean = suppressWarnings(as.numeric(`Wordlist mean`)),
    wordlist_var = suppressWarnings(as.numeric(`Wordlist variability (coefficient of variation)`)),
    boston_naming = suppressWarnings(as.numeric(`Boston Naming (out of 23)`)),
    tmt_a = suppressWarnings(as.numeric(`Trail Making 1 (seconds)`)),
    tmt_b = suppressWarnings(as.numeric(`Trail Making 2 (seconds)`)),
    sils = suppressWarnings(as.numeric(`SILS (# correct, /40)`)),
    cf_copy = suppressWarnings(as.numeric(`Complex Figure Copy Final Score (Total out of 160)`)),
    cf_recall = suppressWarnings(as.numeric(`Complex Figure Recall Final Score (Total out of 160)`)),
    emq = suppressWarnings(as.numeric(`EMQ: Everyday Memory Questionnaire-13 (higher scores indicate more frequent memory problems)`)),
    gad = suppressWarnings(as.numeric(`GAD: Generalized Anziety Disorder-8 (higher value indicates more anxiety)`)),
    gds = suppressWarnings(as.numeric(`GDS: Geriatric Depression Scale-15 (higher scores suggest depression)`))
  ) %>%
  mutate(tmt_b_minus_a = tmt_b - tmt_a) %>%
  filter(!is.na(subject_id), subject_id != "NA") %>%
  distinct(subject_id, .keep_all = TRUE)

fit <- readRDS(DDM_FIT)
re <- ranef(fit)$subject_id
ddm <- tibble(
  subject_id = normalize_subject_id(rownames(re)),
  v_mean = re[, "Estimate", "Intercept"],
  a_mean = exp(fixef(fit)["bs_Intercept", "Estimate"] + re[, "Estimate", "bs_Intercept"]),
  z_mean = plogis(fixef(fit)["bias_Intercept", "Estimate"] + re[, "Estimate", "bias_Intercept"])
)

beh <- read_csv("data/raw/bap_beh_subjxtaskdata_v2.csv", show_col_types = FALSE) %>%
  filter(!is.na(task_modality)) %>%
  group_by(subject_id) %>%
  summarise(
    accuracy = mean(accuracy, na.rm = TRUE),
    rt_mean = mean(same_diff_resp_secs, na.rm = TRUE),
    accuracy_diff_abs = mean(accuracy_diff_abs, na.rm = TRUE),
    rt_diff_abs = mean(same_diff_resp_secs_diff_abs, na.rm = TRUE),
    dprime_var = sd(
      c(
        sdt_dprime_i1_across_grip, sdt_dprime_i2_across_grip,
        sdt_dprime_i3_across_grip, sdt_dprime_i4_across_grip
      ),
      na.rm = TRUE
    ),
    .groups = "drop"
  ) %>%
  mutate(subject_id = normalize_subject_id(subject_id))

dat <- ddm %>%
  left_join(demo, by = "subject_id") %>%
  left_join(np, by = "subject_id") %>%
  left_join(beh, by = "subject_id")

# --- Extended descriptives table ---
desc_specs <- tribble(
  ~measure, ~var,
  "Age (years)", "age",
  "Education (years)", "edu",
  "MoCA (telephone screen /22)", "moca",
  "Trail Making A (seconds)", "tmt_a",
  "Trail Making B (seconds)", "tmt_b",
  "TMT B − A (seconds)", "tmt_b_minus_a",
  "Boston Naming (/23)", "boston_naming",
  "SILS (/40)", "sils",
  "GDS (/15)", "gds",
  "GAD-7 (/8)", "gad",
  "EMQ-13", "emq"
)

desc_tbl <- desc_specs %>%
  rowwise() %>%
  mutate(
    vals = list(dat[[var]]),
    n = sum(!is.na(vals)),
    mean_val = if (n >= 1) mean(vals, na.rm = TRUE) else NA_real_,
    sd_val = if (n >= 2) sd(vals, na.rm = TRUE) else NA_real_,
    min_val = if (n >= 1) min(vals, na.rm = TRUE) else NA_real_,
    max_val = if (n >= 1) max(vals, na.rm = TRUE) else NA_real_
  ) %>%
  ungroup() %>%
  mutate(
    `M (SD)` = ifelse(n >= 2, sprintf("%.1f (%.1f)", mean_val, sd_val), "—"),
    Range = ifelse(n >= 1, sprintf("%.1f–%.1f", min_val, max_val), "—")
  ) %>%
  select(Measure = measure, `M (SD)`, Range, n)

# Race coding matches Table 1 / calc_demographics() in chap3_ddm_results.qmd
race_clean <- dat$race
has_white <- grepl("white", race_clean, ignore.case = TRUE)
has_black <- grepl("black|african", race_clean, ignore.case = TRUE)
has_asian <- grepl("^asian$|^asian,", race_clean, ignore.case = TRUE) & !has_white
white_count <- sum(has_white, na.rm = TRUE)
white_pct <- 100 * white_count / nrow(dat)

demo_categorical <- tibble(
  Characteristic = c(
    "Female, n (%)",
    "Right-handed, n (%)",
    "White race, n (%)",
    "Hispanic/Latino ethnicity, n (%)"
  ),
  Value = c(
    sprintf("%d (%.1f%%)", sum(dat$sex == "female", na.rm = TRUE),
            100 * mean(dat$sex == "female", na.rm = TRUE)),
    sprintf("%d (%.1f%%)", sum(grepl("^R$", dat$hand, ignore.case = TRUE), na.rm = TRUE),
            100 * mean(grepl("^R$", dat$hand, ignore.case = TRUE), na.rm = TRUE)),
    sprintf("%d (%.1f%%)", white_count, white_pct),
    sprintf(
      "%d (%.1f%%)",
      sum(dat$ethnicity == "Hispanic or Latino", na.rm = TRUE),
      100 * mean(dat$ethnicity == "Hispanic or Latino", na.rm = TRUE)
    )
  )
)

write_csv(desc_tbl, file.path(OUT_DIR, "extended_baseline_continuous.csv"))
write_csv(demo_categorical, file.path(OUT_DIR, "extended_baseline_categorical.csv"))
write_csv(dat, file.path(OUT_DIR, "neuropsych_ddm_merged.csv"))

# --- Exploratory partial correlations (age + sex) ---
np_preds <- c("moca", "tmt_b_minus_a", "tmt_a", "boston_naming", "sils", "gds", "gad", "emq", "edu")
outcomes <- c(
  "v_mean", "a_mean", "z_mean", "accuracy", "rt_mean",
  "accuracy_diff_abs", "rt_diff_abs", "dprime_var"
)

cor_tab <- crossing(predictor = np_preds, outcome = outcomes) %>%
  rowwise() %>%
  mutate(stats = list(partial_cor(dat, predictor, outcome))) %>%
  unnest(stats) %>%
  ungroup() %>%
  mutate(fdr = p.adjust(p, "fdr"))

target_tbl <- cor_tab %>%
  filter(
    (predictor == "moca" & outcome %in% c("v_mean", "rt_diff_abs", "accuracy_diff_abs")) |
      (predictor %in% c("sils", "gds", "edu") & p < 0.05)
  ) %>%
  mutate(r = round(r, 3), p = signif(p, 3), fdr = signif(fdr, 3))

write_csv(cor_tab, file.path(OUT_DIR, "neuropsych_ddm_correlations.csv"))
write_csv(target_tbl, file.path(OUT_DIR, "neuropsych_ddm_summary_correlations.csv"))

inline_stats <- list(
  n_ddm = nrow(dat),
  moca_mean = desc_tbl$`M (SD)`[desc_tbl$Measure == "MoCA (telephone screen /22)"],
  moca_n = desc_tbl$n[desc_tbl$Measure == "MoCA (telephone screen /22)"],
  female_pct = demo_categorical$Value[1],
  edu_mean = desc_tbl$`M (SD)`[desc_tbl$Measure == "Education (years)"],
  moca_v_r = cor_tab$r[cor_tab$predictor == "moca" & cor_tab$outcome == "v_mean"],
  moca_v_p = cor_tab$p[cor_tab$predictor == "moca" & cor_tab$outcome == "v_mean"],
  moca_rtcost_p = cor_tab$p[cor_tab$predictor == "moca" & cor_tab$outcome == "rt_diff_abs"],
  gds_dprimevar_r = cor_tab$r[cor_tab$predictor == "gds" & cor_tab$outcome == "dprime_var"],
  gds_dprimevar_p = cor_tab$p[cor_tab$predictor == "gds" & cor_tab$outcome == "dprime_var"]
)
saveRDS(inline_stats, file.path(OUT_DIR, "neuropsych_supplement_inline_stats.rds"))

cat("Neuropsych/demographics supplement complete.\n")
cat("  DDM sample:", nrow(dat), "\n")
cat("  Extended table rows:", nrow(desc_tbl), "\n")
cat("  Significant exploratory associations (p < .05):", sum(cor_tab$p < 0.05, na.rm = TRUE), "\n")
