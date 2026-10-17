# Part T. Tables for the final Chapter 3 export.
# Run from the repo root: Rscript scripts/final/T_export_tables.R
# Reads models only through MANIFEST.csv. Does not fit a brms model.

options(warn = 1, scipen = 999)
suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(loo)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(tibble)
  library(lme4)
  library(broom.mixed)
  library(stringr)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
FINAL <- "output/ddm_refits/runs/final_20261016"
TAB <- file.path(FINAL, "tables", "final")
INV <- "output/diagnostics/final_exports"
dir.create(TAB, recursive = TRUE, showWarnings = FALSE)
dir.create(INV, recursive = TRUE, showWarnings = FALSE)

ROPE <- list(v = 0.02, a = 0.05, z = 0.05)
NOTES <- list()
note <- function(step, msg) {
  NOTES[[length(NOTES) + 1]] <<- data.frame(step = step, note = msg, stringsAsFactors = FALSE)
  message("NOTE [", step, "] ", msg)
}
stop_at <- function(step, msg) {
  writeLines(c(paste("# Stopped at", step), "", msg), file.path(INV, "STOPPED.md"))
  stop(step, ": ", msg, call. = FALSE)
}

man <- read.csv(file.path(FINAL, "MANIFEST.csv"), stringsAsFactors = FALSE)
man_row <- function(id) {
  hit <- man[man$model_id == id, , drop = FALSE]
  if (nrow(hit) != 1) stop_at("T", paste("MANIFEST rows for", id, "=", nrow(hit)))
  hit
}
model_path <- function(id) man_row(id)$final_path

# Convergence row written on the VM; the download archive did not include it.
sub_row <- man_row("M4_subchance")
write.csv(sub_row, file.path(INV, "M4_subchance_convergence.csv"), row.names = FALSE)

must_load_role <- function(role) {
  grepl("primary|comparison|robustness|pupil", role) &&
    !grepl("obsolete|legacy|superseded", role)
}

qsum <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) {
    return(list(median = NA_real_, q2.5 = NA_real_, q97.5 = NA_real_,
                p_lt0 = NA_real_, p_gt0 = NA_real_))
  }
  list(
    median = stats::median(x),
    q2.5 = as.numeric(stats::quantile(x, 0.025)),
    q97.5 = as.numeric(stats::quantile(x, 0.975)),
    p_lt0 = mean(x < 0),
    p_gt0 = mean(x > 0)
  )
}
rope_pct <- function(x, half) mean(abs(x) < half) * 100

family_of <- function(term) {
  if (grepl("^b_bs_|^bs_", term)) return("a")
  if (grepl("bias", term)) return("z")
  "v"
}
rope_for <- function(term) ROPE[[family_of(term)]]

read_draws <- function(id) {
  csv <- file.path(FINAL, "draws", paste0("draws_", id, ".csv"))
  if (file.exists(csv)) return(read.csv(csv, check.names = FALSE))
  fit <- readRDS(model_path(id))
  on.exit({ rm(fit); gc(verbose = FALSE) }, add = TRUE)
  as.data.frame(as_draws_df(fit, variable = "^b_|^Intercept_ndt$", regex = TRUE))
}

effort_rows <- function(draws, source_model, tier) {
  d <- draws
  spec <- tibble::tribble(
    ~term, ~label, ~link,
    "b_effort_conditionhigh", "drift criterion (High - Low)", "identity",
    "b_effort_x_stim", "evidence quality (high x stimulus)", "identity",
    "b_bs_effort_conditionhigh", "boundary (High - Low)", "log",
    "b_bias_effort_conditionhigh", "bias (High - Low)", "logit",
    "drift_different", "drift change, different trials (criterion + quality)", "identity",
    "drift_same", "drift change, same trials (criterion - quality)", "identity"
  )
  d$drift_different <- d$b_effort_conditionhigh + d$b_effort_x_stim
  d$drift_same <- d$b_effort_conditionhigh - d$b_effort_x_stim
  bias_int <- d$b_bias_Intercept
  rows <- lapply(seq_len(nrow(spec)), function(i) {
    term <- spec$term[i]
    x <- d[[term]]
    s <- qsum(x)
    half <- rope_for(term)
    nat <- list(median = NA_real_, q2.5 = NA_real_, q97.5 = NA_real_)
    if (term == "b_bs_effort_conditionhigh") {
      nat <- qsum(100 * (exp(x) - 1))
    } else if (term == "b_bias_effort_conditionhigh") {
      nat <- qsum(plogis(bias_int + x) - plogis(bias_int))
    } else {
      nat <- s
    }
    data.frame(
      term = term, label = spec$label[i], link = spec$link[i],
      median = s$median, q2.5 = s$q2.5, q97.5 = s$q97.5,
      p_lt0 = s$p_lt0, p_gt0 = s$p_gt0,
      pct_in_rope = rope_pct(x, half), rope_halfwidth = half,
      natural_scale_median = nat$median,
      natural_scale_q2.5 = nat$q2.5, natural_scale_q97.5 = nat$q97.5,
      source_model = source_model, tier = tier,
      stringsAsFactors = FALSE
    )
  })
  bind_rows(rows)
}

one_term <- function(x, term, source_model, tier, link = "identity") {
  s <- qsum(x)
  half <- rope_for(term)
  data.frame(
    term = term, median = s$median, q2.5 = s$q2.5, q97.5 = s$q97.5,
    p_lt0 = s$p_lt0, p_gt0 = s$p_gt0,
    pct_in_rope = rope_pct(x, half), rope_halfwidth = half,
    source_model = source_model, tier = tier, link = link,
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# T1 demographics, same construction as the chapter Table 1
# ---------------------------------------------------------------------------
message("T1")
t1_ok <- TRUE
tryCatch({
  included <- read_csv("output/publish/qa_subject_inclusion.csv", show_col_types = FALSE)
  included_ids <- included$subject_id
  demo_path <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/LC Aging Subject Data master spreadsheet - demographics.csv"
  demo <- read_csv(
    demo_path, skip = 1, show_col_types = FALSE,
    col_names = c(
      "study", "subject_id", "subject_id2", "demo_comments", "completion",
      "bap_ses1_date", "bap_ses2_date", "bap_ses3_date", "bap_ses_order",
      "bap_tablet_date", "blank1", "bam_ses1", "bam_ses2", "bam_ses3", "bam_order",
      "bam_tablet", "blank2", "dob", "age", "sex", "edu", "hand", "race",
      "ethnicity", "first_lang", "blank3", "vision", "prescription", "blank4",
      "neuropsych_comments", "adt_comments", "vdt_comments", "stx_comments",
      "future_contact", "blank5", "days_ses1_2", "days_ses2_3"
    )
  )
  demo_filtered <- demo %>%
    filter(subject_id %in% included_ids) %>%
    mutate(
      age = as.numeric(age),
      sex = trimws(tolower(sex)),
      edu = case_when(edu %in% c("<12", "less than 12") ~ "11", TRUE ~ as.character(edu)),
      edu = as.numeric(edu),
      race = trimws(race),
      ethnicity = trimws(ethnicity)
    ) %>%
    filter(!is.na(age))
  neuropsych <- read_csv(
    "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/LC Aging Subject Data master spreadsheet - neuropsych.csv",
    skip = 1, show_col_types = FALSE
  )
  moca_col <- grep("MoCA|moca", names(neuropsych), ignore.case = TRUE, value = TRUE)[1]
  neuropsych <- neuropsych %>%
    mutate(subject_id = `SUBJECT NUMBER`, moca = as.numeric(.data[[moca_col]])) %>%
    select(subject_id, moca)
  full_demo <- demo_filtered %>% left_join(neuropsych, by = "subject_id")
  n <- nrow(full_demo)
  pct <- function(k) sprintf("%d (%.1f%%)", k, round(100 * k / n, 1))
  race_clean <- full_demo$race
  has_white <- grepl("white", race_clean, ignore.case = TRUE)
  has_black <- grepl("black|african", race_clean, ignore.case = TRUE)
  has_asian <- grepl("^asian$|^asian,", race_clean, ignore.case = TRUE) & !has_white
  has_other <- grepl("other", race_clean, ignore.case = TRUE) & !has_white & !has_black & !has_asian
  race_cat <- rep(NA_character_, length(race_clean))
  race_cat[has_white] <- "White/Caucasian"
  race_cat[has_black & !has_white] <- "Black/African American"
  race_cat[has_asian & !has_white & !has_black] <- "Asian"
  race_cat[has_other & !has_white & !has_black & !has_asian] <- "Other"
  hispanic_count <- sum(
    grepl("hispanic|latino", full_demo$ethnicity, ignore.case = TRUE) &
      !grepl("not hispanic|not latino", full_demo$ethnicity, ignore.case = TRUE),
    na.rm = TRUE
  )
  t1 <- tibble(
    Characteristic = c(
      "N", "Age (SD)", "Gender, female (%)", "Education, years (SD)", "MoCA, score (SD)",
      "Race, count (%)", "  White/Caucasian", "  Black/African American", "  Asian", "  Other",
      "Hispanic/Latino"
    ),
    Full_Sample = c(
      as.character(n),
      sprintf("%.1f (%.1f)", mean(full_demo$age), stats::sd(full_demo$age)),
      pct(sum(full_demo$sex == "female", na.rm = TRUE)),
      sprintf("%.1f (%.1f)", mean(full_demo$edu, na.rm = TRUE), stats::sd(full_demo$edu, na.rm = TRUE)),
      sprintf("%.1f (%.1f)", mean(full_demo$moca, na.rm = TRUE), stats::sd(full_demo$moca, na.rm = TRUE)),
      "",
      pct(sum(race_cat == "White/Caucasian", na.rm = TRUE)),
      pct(sum(race_cat == "Black/African American", na.rm = TRUE)),
      pct(sum(race_cat == "Asian", na.rm = TRUE)),
      pct(sum(race_cat == "Other", na.rm = TRUE)),
      pct(hispanic_count)
    ),
    source_model = "qa_subject_inclusion + demographics spreadsheet",
    tier = "main"
  )
  if (n != 67) note("T1", paste("Table 1 reconstruction has N =", n, ", not 67."))
  write_csv(t1, file.path(TAB, "T1_demographics.csv"))
}, error = function(e) {
  t1_ok <<- FALSE
  note("T1", paste("Demographics table could not be built:", conditionMessage(e)))
  write_csv(tibble(
    Characteristic = NA_character_, Full_Sample = NA_character_,
    source_model = NA_character_, tier = "main"
  ), file.path(TAB, "T1_demographics.csv"))
})

# ---------------------------------------------------------------------------
# T2, T4 summaries from M4 draws; T6a; T6b; pupil slopes
# ---------------------------------------------------------------------------
message("T2 T4 T6")
m4 <- read_draws("M4")
t2 <- effort_rows(m4, "M4", "main")
write_csv(t2, file.path(TAB, "T2_effort_effects_M4.csv"))

sum_fixef <- function(draws, id) {
  bcols <- grep("^b_", names(draws), value = TRUE)
  bind_rows(lapply(bcols, function(term) {
    one_term(draws[[term]], term, id, "ms_supp",
             link = if (grepl("^b_bs_", term)) "log" else if (grepl("bias", term)) "logit" else if (grepl("ndt", term)) "log" else "identity")
  }))
}
t4_est <- sum_fixef(m4, "M4")

# M4b task-specific criterion, saved so Part V can copy it
m4b <- read_draws("M4b")
m4b$crit_adt <- m4b$b_effort_conditionhigh
m4b$crit_vdt <- m4b$b_effort_conditionhigh + m4b[["b_taskVDT:effort_conditionhigh"]]
t4b <- bind_rows(
  one_term(m4b$b_effort_conditionhigh, "b_effort_conditionhigh", "M4b", "ms_supp"),
  one_term(m4b[["b_taskVDT:effort_conditionhigh"]], "b_taskVDT:effort_conditionhigh", "M4b", "ms_supp"),
  one_term(m4b[["b_taskVDT:effort_x_stim"]], "b_taskVDT:effort_x_stim", "M4b", "ms_supp"),
  one_term(m4b$crit_adt, "criterion_ADT", "M4b", "ms_supp"),
  one_term(m4b$crit_vdt, "criterion_VDT", "M4b", "ms_supp"),
  one_term(m4b$b_effort_x_stim, "b_effort_x_stim", "M4b", "ms_supp")
)
write_csv(t4b, file.path(TAB, "T4b_M4b_task_effort.csv"))

robust_ids <- c("M4", "M4r", "M4_thr0.15", "M4_thr0.25", "M4_subchance")
t6_list <- lapply(robust_ids, function(id) {
  dr <- if (id == "M4") m4 else read_draws(id)
  info <- man_row(id)
  er <- effort_rows(dr, id, "ms_supp")
  t0 <- qsum(exp(dr$b_ndt_Intercept))
  er$model <- id
  er$n_trials <- info$n_trials
  er$n_subjects <- info$n_subjects
  er$max_rhat <- info$max_rhat
  er$passes_convergence_rule <- info$passes_convergence_rule
  er$t0_median <- t0$median
  er$t0_q2.5 <- t0$q2.5
  er$t0_q97.5 <- t0$q97.5
  er
})
t6a <- bind_rows(t6_list)
write_csv(t6a, file.path(TAB, "T6a_robustness_effort_terms.csv"))

m4r <- read_draws("M4r")
sd_terms <- c(
  "sd_subject_id__effort_conditionhigh",
  "sd_subject_id__bs_effort_conditionhigh",
  "cor_subject_id__Intercept__effort_conditionhigh",
  "cor_subject_id__bs_Intercept__bs_effort_conditionhigh"
)
t6b <- bind_rows(lapply(sd_terms, function(term) {
  if (!term %in% names(m4r)) {
    note("T6b", paste("Missing", term))
    return(one_term(NA_real_, term, "M4r", "ms_supp"))
  }
  one_term(m4r[[term]], term, "M4r", "ms_supp", link = if (grepl("^cor_", term)) "correlation" else "sd")
}))
write_csv(t6b, file.path(TAB, "T6b_M4r_random_slopes.csv"))

# ---------------------------------------------------------------------------
# T5 model comparison
# ---------------------------------------------------------------------------
message("T5")
cmp_ids <- c("M0", "M1", "M2", "M3", "M4", "M4b")
load_loo <- function(id) readRDS(file.path(FINAL, "loo", paste0("loo_", id, ".rds")))
loos <- lapply(stats::setNames(cmp_ids, cmp_ids), load_loo)
elpd_of <- function(obj) obj$estimates["elpd_loo", "Estimate"]
se_of <- function(obj) obj$estimates["elpd_loo", "SE"]
ploo_of <- function(obj) obj$estimates["p_loo", "Estimate"]
pareto_of <- function(obj) {
  pk <- obj$diagnostics$pareto_k
  if (is.null(pk)) pk <- obj$pareto_k
  pk
}
delta_vs <- function(a, b) {
  d <- loos[[a]]$pointwise[, "elpd_loo"] - loos[[b]]$pointwise[, "elpd_loo"]
  c(delta = sum(d), se = stats::sd(d) * sqrt(length(d)))
}
t5 <- bind_rows(lapply(cmp_ids, function(id) {
  info <- man_row(id)
  dv <- delta_vs(id, "M4")
  data.frame(
    model = id,
    elpd_loo = elpd_of(loos[[id]]),
    se_elpd_loo = se_of(loos[[id]]),
    p_loo = ploo_of(loos[[id]]),
    delta_elpd_vs_M4 = unname(dv["delta"]),
    se_delta_elpd_vs_M4 = unname(dv["se"]),
    n_k_gt_0.7 = sum(pareto_of(loos[[id]]) > 0.7, na.rm = TRUE),
    max_rhat = info$max_rhat,
    min_bulk_ess = info$min_bulk_ess,
    passes_convergence_rule = info$passes_convergence_rule,
    formula = info$formula,
    rhat_footnote = if (id %in% c("M1", "M2")) "Fails the convergence rule (max R-hat >= 1.01)." else "",
    source_model = id, tier = "ms_supp",
    stringsAsFactors = FALSE
  )
}))
write_csv(t5, file.path(TAB, "T5_model_comparison.csv"))
# also the M0 vs M1 contrast used inline
d01 <- delta_vs("M0", "M1")
write_csv(tibble(
  contrast = "M0_vs_M1", delta_elpd = unname(d01["delta"]), se = unname(d01["se"]),
  source_model = "M0,M1", tier = "ms_supp"
), file.path(TAB, "T5_delta_M0_vs_M1.csv"))

# ---------------------------------------------------------------------------
# T7 and T8 pupil
# ---------------------------------------------------------------------------
message("T7 T8")
pupil_spec <- tibble::tribble(
  ~model, ~baseline, ~term, ~predictor, ~precedes, ~group,
  "P3", "P0", "b_bs_tepr_c", "current-trial TEPR", FALSE, "within current trial",
  "P3_rt", "P0_rt", "b_bs_tepr_c", "current-trial TEPR, fastest 80% of RTs", FALSE, "within current trial",
  "P5", "P0", "b_bs_base_c", "prestimulus baseline", TRUE, "precedes current decision",
  "P6", "P0_lag", "b_bs_lag_tepr_c", "previous-trial TEPR", TRUE, "precedes current decision",
  "P7", "P0_pre", "b_bs_prechoice_c", "0.5 s before the response", FALSE, "within current trial",
  "P8", "P0_grip", "b_bs_grip_c", "grip period before the probe", TRUE, "precedes current decision"
)
slope_row <- function(id, term, baseline) {
  dr <- read_draws(id)
  x <- dr[[term]]
  s <- qsum(x)
  pct <- qsum(100 * (exp(x) - 1))
  info <- man_row(id)
  binfo <- man_row(baseline)
  dv <- {
    la <- load_loo(id); lb <- load_loo(baseline)
    d <- la$pointwise[, "elpd_loo"] - lb$pointwise[, "elpd_loo"]
    c(sum(d), stats::sd(d) * sqrt(length(d)))
  }
  data.frame(
    model = id, baseline = baseline, term = term,
    median = s$median, q2.5 = s$q2.5, q97.5 = s$q97.5,
    p_lt0 = s$p_lt0, p_gt0 = s$p_gt0,
    pct_change_median = pct$median, pct_change_q2.5 = pct$q2.5, pct_change_q97.5 = pct$q97.5,
    delta_elpd_vs_baseline = dv[1], se_delta_elpd = dv[2],
    n_trials = info$n_trials, n_subjects = info$n_subjects,
    max_rhat = info$max_rhat, passes_convergence_rule = info$passes_convergence_rule,
    elpd_loo = elpd_of(load_loo(id)),
    stringsAsFactors = FALSE
  )
}
# P0-P4 added terms
p_added <- list(
  P0 = character(0),
  P1 = "b_bias_tepr_c",
  P2 = c("b_tepr_c", "b_tepr_c:stim_sign"),
  P3 = "b_bs_tepr_c",
  P4 = "b_bias_base_c"
)
delta_vs_loo <- function(a, b) {
  la <- load_loo(a); lb <- load_loo(b)
  d <- la$pointwise[, "elpd_loo"] - lb$pointwise[, "elpd_loo"]
  c(sum(d), stats::sd(d) * sqrt(length(d)))
}

message("T3 condition cells and T4 convergence columns from M4")
fit4 <- readRDS(model_path("M4"))
grid <- expand.grid(
  task = c("ADT", "VDT"),
  difficulty_3 = c("Standard", "Hard", "Easy"),
  effort_condition = c("low", "high"),
  stringsAsFactors = FALSE
)
grid$stim_sign <- ifelse(grid$difficulty_3 == "Standard", -1, 1)
grid$effort_x_stim <- ifelse(grid$effort_condition == "high", grid$stim_sign, 0)
grid$subject_id <- fit4$data$subject_id[1]
for (col in c("task", "difficulty_3", "effort_condition")) {
  if (is.factor(fit4$data[[col]])) grid[[col]] <- factor(grid[[col]], levels = levels(fit4$data[[col]]))
}
lp_v <- posterior_linpred(fit4, newdata = grid, re_formula = NA)
lp_a <- posterior_linpred(fit4, newdata = grid, re_formula = NA, dpar = "bs", transform = TRUE)
lp_z <- posterior_linpred(fit4, newdata = grid, re_formula = NA, dpar = "bias", transform = TRUE)
lp_t <- posterior_linpred(fit4, newdata = grid, re_formula = NA, dpar = "ndt", transform = TRUE)
cell_part <- function(mat, quantity) {
  bind_rows(lapply(seq_len(ncol(mat)), function(j) {
    s <- qsum(mat[, j])
    data.frame(
      task = grid$task[j], difficulty_3 = grid$difficulty_3[j],
      effort_condition = grid$effort_condition[j], quantity = quantity,
      median = s$median, q2.5 = s$q2.5, q97.5 = s$q97.5,
      stringsAsFactors = FALSE
    )
  }))
}
t3 <- bind_rows(
  cell_part(lp_v, "v"), cell_part(lp_a, "a"),
  cell_part(lp_z, "z"), cell_part(lp_t, "t0")
)
t3$source_model <- "M4"
t3$tier <- "ms_supp"
write_csv(t3, file.path(TAB, "T3_condition_cells_M4.csv"))

s4 <- as.data.frame(summarise_draws(as_draws_df(fit4, variable = "^b_", regex = TRUE), "rhat", "ess_bulk", "ess_tail"))
t4 <- t4_est %>%
  left_join(s4 %>% select(variable, rhat, ess_bulk, ess_tail), by = c("term" = "variable"))
t4$source_model <- "M4"
t4$tier <- "ms_supp"
write_csv(t4, file.path(TAB, "T4_fixef_M4.csv"))

# Subject-level intercepts for T14, while M4 is loaded
message("T14 subject intercepts")
cf <- coef(fit4, summary = FALSE)$subject_id
subj_names <- dimnames(cf)[[2]]
par_names <- dimnames(cf)[[3]]
need_par <- c("Intercept", "bs_Intercept", "bias_Intercept")
if (!all(need_par %in% par_names)) stop_at("T14", paste("Missing coef parameters:", paste(setdiff(need_par, par_names), collapse = ", ")))
med_par <- function(par) apply(cf[, , par, drop = TRUE], 2, stats::median)
ddm_subj <- tibble(
  subject_id = subj_names,
  v_intercept = med_par("Intercept"),
  a_intercept_log = med_par("bs_Intercept"),
  z_intercept_logit = med_par("bias_Intercept")
) %>%
  mutate(
    v_mean = v_intercept,
    a_mean = exp(a_intercept_log),
    z_mean = plogis(z_intercept_logit),
    ddm_source = "M4 posterior median of fixed + random intercept"
  )
rm(fit4, cf); gc(verbose = FALSE)
saveRDS(ddm_subj, file.path(INV, "m4_subject_intercepts.rds"))

message("T7 assemble")
# Redefine the P0 row without the forward reference that the first draft used.
# The lapply above called delta_vs_loo before it existed if P0 was first.
# Rebuild T7 cleanly.
t7 <- bind_rows(lapply(names(p_added), function(id) {
  info <- man_row(id)
  terms <- p_added[[id]]
  if (!length(terms)) {
    dv <- delta_vs_loo(id, "P0")
    row <- data.frame(
      model = id, baseline = "P0", term = "none (baseline)",
      median = NA_real_, q2.5 = NA_real_, q97.5 = NA_real_,
      p_lt0 = NA_real_, p_gt0 = NA_real_,
      pct_change_median = NA_real_, pct_change_q2.5 = NA_real_, pct_change_q97.5 = NA_real_,
      delta_elpd_vs_baseline = 0, se_delta_elpd = 0,
      n_trials = info$n_trials, n_subjects = info$n_subjects,
      max_rhat = info$max_rhat, passes_convergence_rule = info$passes_convergence_rule,
      elpd_loo = elpd_of(load_loo(id)),
      added_terms = "", source_model = id, tier = "ms_supp",
      stringsAsFactors = FALSE
    )
    return(row)
  }
  bind_rows(lapply(terms, function(term) {
    row <- slope_row(id, term, "P0")
    row$added_terms <- paste(terms, collapse = "; ")
    row$source_model <- id
    row$tier <- "ms_supp"
    row
  }))
}))
p0_draws <- read_draws("P0")
p0_eff <- effort_rows(p0_draws, "P0", "ms_supp")
p0_eff$record <- "P0_effort_term"
t7$record <- "pupil_model"
write_csv(t7, file.path(TAB, "T7_pupil_models.csv"))
write_csv(p0_eff, file.path(TAB, "T7_P0_effort_terms.csv"))

t8 <- bind_rows(lapply(seq_len(nrow(pupil_spec)), function(i) {
  sp <- pupil_spec[i, ]
  row <- slope_row(sp$model, sp$term, sp$baseline)
  row$predictor <- sp$predictor
  row$precedes_current_decision <- sp$precedes
  row$group <- sp$group
  row$source_model <- sp$model
  row$tier <- "main"
  row
}))
write_csv(t8, file.path(TAB, "T8_pupil_ordering.csv"))

# ---------------------------------------------------------------------------
# T9 descriptives, copied
# ---------------------------------------------------------------------------
message("T9")
qc <- read_csv(file.path(FINAL, "qc/qc_gate_counts.csv"), show_col_types = FALSE) %>%
  mutate(block = "qc_gate", source_model = "r5 Part A", tier = "main")
cor_tepr <- read_csv(file.path(FINAL, "pupil_descriptives/d1_tepr_rt_correlation.csv"), show_col_types = FALSE) %>%
  mutate(block = "tepr_rt_correlation", source_model = "r6 D1", tier = "main")
raw_means <- read_csv(file.path(FINAL, "qc/raw_means_by_task_effort.csv"), show_col_types = FALSE) %>%
  mutate(block = "raw_means", source_model = "r5 Part A", tier = "ms_supp")
paired <- read_csv(file.path(FINAL, "qc/paired_high_minus_low.csv"), show_col_types = FALSE) %>%
  mutate(block = "paired_high_minus_low", source_model = "r5 Part A", tier = "main")
grip_means <- read_csv(file.path(FINAL, "pupil_descriptives/grip_means_by_task_effort.csv"), show_col_types = FALSE) %>%
  mutate(block = "grip_means", source_model = "r6 grip", tier = "ms_supp")
grip_paired <- read_csv(file.path(FINAL, "pupil_descriptives/grip_paired_high_minus_low.csv"), show_col_types = FALSE) %>%
  mutate(block = "grip_paired", source_model = "r6 grip", tier = "main")
t9 <- bind_rows(qc, cor_tepr, raw_means, paired, grip_means, grip_paired)
write_csv(t9, file.path(TAB, "T9_pupil_descriptives.csv"))

# ---------------------------------------------------------------------------
# T10 convergence, one model at a time
# ---------------------------------------------------------------------------
message("T10")
t10_ids <- man$model_id[!grepl("legacy_not_refit|obsolete", man$role)]
t10_rows <- lapply(t10_ids, function(id) {
  info <- man_row(id)
  path <- info$final_path
  empty <- data.frame(
    model = id, role = info$role, chains = info$chains, iter = info$iter, warmup = info$warmup,
    max_rhat = NA_real_, max_rhat_b = NA_real_, min_bulk_ess = NA_real_, min_bulk_ess_b = NA_real_,
    min_tail_ess = NA_real_, min_tail_ess_b = NA_real_,
    divergences = NA_real_, treedepth_hits = NA_real_, n_k_gt_0.7 = info$n_k_gt_0.7,
    passes_convergence_rule = info$passes_convergence_rule,
    source_model = id, tier = "ms_supp", note = "", stringsAsFactors = FALSE
  )
  if (!nzchar(path) || !file.exists(path)) {
    empty$note <- "No model file in the final run (not copied)."
    if (must_load_role(info$role)) stop_at("T10", paste(id, "is missing at", path))
    return(empty)
  }
  message("  load ", id)
  fit <- tryCatch(readRDS(path), error = function(e) e)
  if (inherits(fit, "error")) {
    if (must_load_role(info$role)) stop_at("T10", paste(id, "failed to load:", conditionMessage(fit)))
    empty$note <- conditionMessage(fit)
    return(empty)
  }
  s <- as.data.frame(summarise_draws(as_draws_df(fit), "rhat", "ess_bulk", "ess_tail"))
  b <- s[grepl("^b_", s$variable), , drop = FALSE]
  sp <- rstan::get_sampler_params(fit$fit, inc_warmup = FALSE)
  n_div <- sum(vapply(sp, function(x) sum(x[, "divergent__"]), numeric(1)))
  n_td <- sum(vapply(sp, function(x) sum(x[, "treedepth__"] >= 12), numeric(1)))
  nk <- info$n_k_gt_0.7
  loo_file <- file.path(FINAL, "loo", paste0("loo_", id, ".rds"))
  if (file.exists(loo_file)) nk <- sum(pareto_of(readRDS(loo_file)) > 0.7, na.rm = TRUE)
  rm(fit); gc(verbose = FALSE)
  i_r <- which.max(s$rhat); i_b <- which.min(s$ess_bulk); i_t <- which.min(s$ess_tail)
  empty$max_rhat <- s$rhat[i_r]
  empty$min_bulk_ess <- s$ess_bulk[i_b]
  empty$min_tail_ess <- s$ess_tail[i_t]
  empty$max_rhat_b <- if (nrow(b)) max(b$rhat) else NA_real_
  empty$min_bulk_ess_b <- if (nrow(b)) min(b$ess_bulk) else NA_real_
  empty$min_tail_ess_b <- if (nrow(b)) min(b$ess_tail) else NA_real_
  empty$divergences <- n_div
  empty$treedepth_hits <- n_td
  empty$n_k_gt_0.7 <- nk
  empty$passes_convergence_rule <- isTRUE(empty$max_rhat < 1.01 && empty$min_bulk_ess > 400 && n_div == 0)
  empty$note <- paste("max R-hat parameter", s$variable[i_r])
  empty
})
t10 <- bind_rows(t10_rows)
write_csv(t10, file.path(TAB, "T10_convergence_all.csv"))

# ---------------------------------------------------------------------------
# T11 PPC, copied
# ---------------------------------------------------------------------------
message("T11")
inside <- function(obs, lo, hi) !is.na(obs) & obs >= lo & obs <= hi
ppc_m4 <- read_csv("output/diagnostics/r4_extract/ppc_M4.csv", show_col_types = FALSE) %>%
  mutate(inside = inside(observed, pred_q2.5, pred_q97.5), source_model = "M4", tier = "ms_supp")
ppc_p3 <- read_csv("output/diagnostics/r5_extract/ppc_P3.csv", show_col_types = FALSE) %>%
  mutate(inside = inside(observed, pred_q2.5, pred_q97.5), source_model = "P3", tier = "ms_supp")
t11a <- bind_rows(
  ppc_m4 %>% filter(quantity == "p_different"),
  ppc_p3 %>% filter(quantity == "p_different")
)
t11b <- ppc_m4 %>% filter(grepl("^rt_q", quantity))
write_csv(t11a, file.path(TAB, "T11a_ppc_choice.csv"))
write_csv(t11b, file.path(TAB, "T11b_ppc_rt_quantiles.csv"))
med_rows <- t11b %>% filter(quantity == "rt_q0.5")
ppc_summary <- tibble(
  ppc_choice_inside_M4 = sum(t11a$inside[t11a$source_model == "M4"]),
  ppc_choice_cells_M4 = sum(t11a$source_model == "M4"),
  ppc_rt_inside_pct_M4 = 100 * mean(t11b$inside),
  ppc_rt_median_bias_ms_M4 = mean(med_rows$observed - med_rows$pred_median) * 1000,
  source_model = "M4", tier = "ms_supp"
)
write_csv(ppc_summary, file.path(TAB, "T11_ppc_summary.csv"))

# ---------------------------------------------------------------------------
# T12 counts and flow
# ---------------------------------------------------------------------------
message("T12")
beh <- read_csv(file.path(FINAL, "data/ddm_behavioral_r5_full17857.csv"), show_col_types = FALSE)
beh <- beh %>% mutate(correct = as.integer(
  (difficulty_3 == "Standard" & choice_binary == 0) |
    (difficulty_3 != "Standard" & choice_binary == 1)
))
t12a <- beh %>%
  group_by(task, difficulty_3, effort_condition) %>%
  summarise(
    n_trials = n(), n_subjects = n_distinct(subject_id),
    trials_per_subject = n_trials / n_subjects, .groups = "drop"
  ) %>%
  mutate(source_model = "primary 0.20 s data", tier = "ms_supp")
task_n <- beh %>% group_by(task) %>% summarise(n_subjects = n_distinct(subject_id), n_trials = n(), .groups = "drop")
write_csv(t12a, file.path(TAB, "T12a_trial_counts.csv"))
write_csv(task_n %>% mutate(source_model = "primary 0.20 s data", tier = "ms_supp"),
          file.path(TAB, "T12a_n_per_task.csv"))

unthr_path <- "data/ddm_ready_data_unthresholded.csv"
unthr <- read_csv(unthr_path, show_col_types = FALSE)
n_collected <- nrow(unthr)
n_ge_020 <- sum(!is.na(unthr$rt_probe_onset_locked) & unthr$rt_probe_onset_locked >= 0.20)
if (n_ge_020 != 17857) {
  note("T12b", paste0(
    "Unthresholded trials with probe-onset RT >= 0.20 s: ", n_ge_020,
    ". The primary analysis file has 17857. The difference is recorded, not forced."
  ))
}
flow <- tibble::tribble(
  ~node, ~n_subjects, ~n_trials, ~detail,
  "enrolled", 69, NA_integer_, "Chapter enrollment constant",
  "excluded_after_enrollment", 2, NA_integer_, "One suspected MCI, one possible essential tremor",
  "analytic_sample", 67, NA_integer_, "Enrolled minus the two exclusions",
  "task_ADT", task_n$n_subjects[task_n$task == "ADT"], task_n$n_trials[task_n$task == "ADT"], "Primary 0.20 s file",
  "task_VDT", task_n$n_subjects[task_n$task == "VDT"], task_n$n_trials[task_n$task == "VDT"], "Primary 0.20 s file",
  "behavioral_trials_collected", NA_integer_, n_collected, "Unthresholded trial file",
  "probe_rt_below_0.20_or_missing", NA_integer_, n_collected - n_ge_020, "Within the unthresholded file",
  "primary_analysis_trials", 67, 17857, "final_20261016 primary behavioral file",
  "cutoff_0.15_trials", man_row("M4_thr0.15")$n_subjects, man_row("M4_thr0.15")$n_trials, "Cue-locked 0.15 s refit data",
  "cutoff_0.25_trials", man_row("M4_thr0.25")$n_subjects, man_row("M4_thr0.25")$n_trials, "Cue-locked 0.25 s refit data"
)
qc_flow <- qc %>% transmute(
  node = paste0("pupil_", gate),
  n_subjects = n_subjects, n_trials = n_trials,
  detail = paste0("subject x task cells: ", n_subject_task)
)
t12b <- bind_rows(flow, qc_flow) %>%
  mutate(source_model = "enrollment constants + primary data + r5 QC gates", tier = "ms_supp")
write_csv(t12b, file.path(TAB, "T12b_participant_flow.csv"))

# ---------------------------------------------------------------------------
# T13 behavior
# ---------------------------------------------------------------------------
message("T13")
cell_desc <- beh %>%
  group_by(subject_id, task, difficulty_3, effort_condition) %>%
  summarise(accuracy = mean(correct), median_rt = stats::median(rt), n_trials = n(), .groups = "drop")
t13a_cells <- cell_desc %>%
  group_by(task, difficulty_3, effort_condition) %>%
  summarise(
    n_subjects = n(), mean_accuracy = mean(accuracy), mean_median_rt = mean(median_rt),
    .groups = "drop"
  ) %>%
  mutate(record = "cell_mean", source_model = "primary 0.20 s data", tier = "diss_supp")

paired_acc <- lapply(c("Standard", "Hard", "Easy"), function(diff) {
  wide <- cell_desc %>%
    filter(difficulty_3 == diff) %>%
    group_by(subject_id, effort_condition) %>%
    summarise(accuracy = mean(accuracy), .groups = "drop") %>%
    pivot_wider(names_from = effort_condition, values_from = accuracy)
  wide <- wide %>% filter(!is.na(high), !is.na(low))
  diff_v <- wide$high - wide$low
  tt <- t.test(wide$high, wide$low, paired = TRUE)
  data.frame(
    difficulty_3 = diff, n_subjects = nrow(wide),
    mean_high_minus_low = mean(diff_v), se = stats::sd(diff_v) / sqrt(nrow(wide)),
    t = unname(tt$statistic), df = unname(tt$parameter), p = tt$p.value,
    record = "paired_accuracy", source_model = "primary 0.20 s data", tier = "main",
    stringsAsFactors = FALSE
  )
})
t13a <- bind_rows(t13a_cells, bind_rows(paired_acc))
write_csv(t13a, file.path(TAB, "T13a_accuracy_rt_descriptives.csv"))

beh_m <- beh %>% mutate(
  difficulty_3 = factor(difficulty_3, levels = c("Standard", "Hard", "Easy")),
  effort_condition = factor(effort_condition, levels = c("low", "high")),
  task = factor(task, levels = c("ADT", "VDT"))
)
# superseded phase1c: random-intercept GLMM, High vs Low at the Standard reference, p = .068
# acc_fit <- glmer(
#   correct ~ difficulty_3 * effort_condition + task + (1 | subject_id),
#   data = beh_m, family = binomial,
#   control = glmerControl(optimizer = "bobyqa")
# )
# superseded phase1c: random-intercept LMM of cell-median RT, no Satterthwaite p
# rt_cell <- beh_m %>%
#   group_by(subject_id, task, difficulty_3, effort_condition) %>%
#   summarise(rt_med = stats::median(rt), .groups = "drop")
# rt_fit <- lmer(rt_med ~ difficulty_3 * effort_condition + task + (1 | subject_id), data = rt_cell)
# t13b <- tidy(acc_fit, effects = "fixed", conf.int = TRUE) %>%
#   mutate(source_model = "lme4 binomial GLMM", tier = "diss_supp")
# t13c <- tidy(rt_fit, effects = "fixed", conf.int = TRUE) %>%
#   mutate(source_model = "lme4 median-RT LMM", tier = "diss_supp")
# write_csv(t13b, file.path(TAB, "T13b_accuracy_glmm.csv"))
# write_csv(t13c, file.path(TAB, "T13c_rt_lmm.csv"))

suppressPackageStartupMessages({
  library(emmeans)
  library(lmerTest)
})
beh_m$effort_c <- ifelse(beh_m$effort_condition == "high", 0.5, -0.5)
glmer_ctrl <- glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))

fit_failed <- function(fit, warnings) {
  singular <- isTRUE(lme4::isSingular(fit, tol = 1e-4))
  opt <- fit@optinfo$conv$opt
  opt_bad <- !is.null(opt) && length(opt) > 0 && any(opt != 0)
  msg <- paste(warnings, collapse = " | ")
  msg_bad <- grepl("singular|failed to converge|convergence", msg, ignore.case = TRUE)
  list(failed = singular || isTRUE(opt_bad) || msg_bad, singular = singular, opt_bad = isTRUE(opt_bad), message = msg)
}

fit_with_warnings <- function(expr) {
  caught <- character(0)
  fit <- withCallingHandlers(
    eval(expr, envir = parent.frame()),
    warning = function(w) {
      caught <<- c(caught, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(fit = fit, warnings = caught, check = fit_failed(fit, caught))
}

acc_try <- fit_with_warnings(quote(lme4::glmer(
  correct ~ difficulty_3 * effort_condition + task + (1 + effort_condition | subject_id),
  family = binomial, data = beh_m, control = glmer_ctrl
)))
acc_re <- "(1 + effort_condition | subject_id)"
if (acc_try$check$failed) {
  note("T13", paste(
    "Correlated accuracy random slope was not used.",
    if (acc_try$check$singular) "Singular." else "Did not converge.",
    acc_try$check$message
  ))
  acc_re <- "(1 | subject_id) + (0 + effort_c | subject_id); effort_c is -0.5/+0.5"
  acc_try <- fit_with_warnings(quote(lme4::glmer(
    correct ~ difficulty_3 * effort_condition + task + (1 | subject_id) + (0 + effort_c | subject_id),
    family = binomial, data = beh_m, control = glmer_ctrl
  )))
  if (acc_try$check$failed) {
    stop_at("T13", paste(
      "Accuracy model failed after dropping the random-slope correlation.",
      "Not falling back to a random intercept only.",
      "singular:", acc_try$check$singular,
      "optimizer flagged:", acc_try$check$opt_bad,
      "warnings:", if (nzchar(acc_try$check$message)) acc_try$check$message else "(none)"
    ))
  }
}
m_acc <- acc_try$fit

emm_acc <- emmeans(
  m_acc, ~ effort_condition | difficulty_3,
  type = "response", weights = "equal"
)
pp_df <- as.data.frame(summary(pairs(regrid(emm_acc), reverse = TRUE), infer = TRUE))
or_df <- as.data.frame(summary(pairs(emm_acc, type = "response", reverse = TRUE), infer = TRUE))
if (!all(grepl("^high - low$", pp_df$contrast))) {
  stop_at("T13", paste("Probability contrasts are not High - Low:", paste(pp_df$contrast, collapse = ", ")))
}
if (!all(grepl("^high / low$", or_df$contrast))) {
  stop_at("T13", paste("Odds-ratio contrasts are not high / low:", paste(or_df$contrast, collapse = ", ")))
}
pp_df <- pp_df[match(c("Standard", "Hard", "Easy"), pp_df$difficulty_3), , drop = FALSE]
or_df <- or_df[match(pp_df$difficulty_3, or_df$difficulty_3), , drop = FALSE]
t13d <- data.frame(
  difficulty_3 = pp_df$difficulty_3,
  contrast = "High - Low",
  pp = 100 * pp_df$estimate,
  pp_lo = 100 * pp_df$lower.CL,
  pp_hi = 100 * pp_df$upper.CL,
  or = or_df$odds.ratio,
  or_lo = or_df$lower.CL,
  or_hi = or_df$upper.CL,
  z = or_df$z.ratio,
  p = or_df$p.value,
  re_structure = acc_re,
  source_model = "m_acc emmeans, equal task weights",
  tier = "main",
  stringsAsFactors = FALSE
)
write_csv(t13d, file.path(TAB, "T13d_accuracy_effort_contrasts.csv"))

tidy_parts <- function(fit, re_structure, source_model) {
  fixed <- tidy(fit, effects = "fixed", conf.int = TRUE)
  ran <- tidy(fit, effects = "ran_pars", conf.int = TRUE)
  bind_rows(fixed, ran) %>%
    mutate(re_structure = re_structure, source_model = source_model, tier = "diss_supp")
}
t13b <- tidy_parts(m_acc, acc_re, "binomial GLMM, by-subject effort slope")

rt_cell <- beh_m %>%
  group_by(subject_id, task, difficulty_3, effort_condition) %>%
  summarise(rt_med = stats::median(rt), effort_c = effort_c[1], .groups = "drop")
rt_try <- fit_with_warnings(quote(lmerTest::lmer(
  rt_med ~ difficulty_3 * effort_condition + task + (1 + effort_condition | subject_id),
  data = rt_cell
)))
rt_re <- "(1 + effort_condition | subject_id)"
if (rt_try$check$failed) {
  note("T13", paste(
    "Correlated RT random slope was not used.",
    if (rt_try$check$singular) "Singular." else "Did not converge.",
    rt_try$check$message
  ))
  rt_re <- "(1 | subject_id) + (0 + effort_c | subject_id); effort_c is -0.5/+0.5"
  rt_try <- fit_with_warnings(quote(lmerTest::lmer(
    rt_med ~ difficulty_3 * effort_condition + task + (1 | subject_id) + (0 + effort_c | subject_id),
    data = rt_cell
  )))
  if (rt_try$check$failed) {
    stop_at("T13", paste(
      "RT model failed after dropping the random-slope correlation.",
      "Not falling back to a random intercept only.",
      "singular:", rt_try$check$singular,
      "optimizer flagged:", rt_try$check$opt_bad,
      "warnings:", if (nzchar(rt_try$check$message)) rt_try$check$message else "(none)"
    ))
  }
}
t13c <- tidy_parts(rt_try$fit, rt_re, "lmerTest median-RT LMM, Satterthwaite df")
write_csv(t13b, file.path(TAB, "T13b_accuracy_glmm.csv"))
write_csv(t13c, file.path(TAB, "T13c_rt_lmm.csv"))
note("T13", paste("Accuracy random effects:", acc_re))
note("T13", paste("RT random effects:", rt_re))
if (length(acc_try$warnings)) note("T13", paste("Accuracy warnings:", paste(acc_try$warnings, collapse = " | ")))
if (length(rt_try$warnings)) note("T13", paste("RT warnings:", paste(rt_try$warnings, collapse = " | ")))

# ---------------------------------------------------------------------------
# T14 LC and neuropsych, DDM outcomes replaced
# ---------------------------------------------------------------------------
message("T14")
norm_id <- function(id) {
  id <- as.character(id)
  num <- stringr::str_extract(stringr::str_replace(id, "^BAP", ""), "\\d+")
  ifelse(!is.na(num), sprintf("BAP%03d", as.integer(num)), id)
}
partial_cor <- function(df, x, y, covars = c("age", "sex")) {
  sub <- df %>% filter(!is.na(.data[[x]]), !is.na(.data[[y]]))
  for (cv in covars) sub <- sub %>% filter(!is.na(.data[[cv]]))
  if (nrow(sub) < 12) return(tibble(r = NA_real_, p = NA_real_, n = nrow(sub)))
  sub$x <- sub[[x]]; sub$y <- sub[[y]]
  m_x <- lm(as.formula(paste("x ~", paste(covars, collapse = " + "))), data = sub)
  m_y <- lm(as.formula(paste("y ~", paste(covars, collapse = " + "))), data = sub)
  ct <- cor.test(stats::resid(m_x), stats::resid(m_y))
  tibble(r = unname(ct$estimate), p = ct$p.value, n = nrow(sub))
}
ddm_subj <- ddm_subj %>% mutate(subject_id = norm_id(subject_id))

lc_raw <- read_csv("data/raw/bap_beh_subjxtaskdata_v2.csv", show_col_types = FALSE)
lc <- lc_raw %>%
  distinct(subject_id, .keep_all = TRUE) %>%
  transmute(
    subject_id = norm_id(subject_id), age, sex = factor(sex),
    LC_CNR_max, LC_fICVF, LC_fISO, LC_Composite_v2, PC1_v2
  )
beh_lc <- lc_raw %>%
  filter(!is.na(task_modality)) %>%
  group_by(subject_id) %>%
  summarise(
    accuracy = mean(accuracy, na.rm = TRUE),
    dprime_mean = mean(sdt_dprime_i1_across_grip, na.rm = TRUE),
    dprime_variability = stats::sd(c(
      sdt_dprime_i1_across_grip, sdt_dprime_i2_across_grip,
      sdt_dprime_i3_across_grip, sdt_dprime_i4_across_grip
    ), na.rm = TRUE),
    rt_mean = mean(same_diff_resp_secs, na.rm = TRUE),
    rt_diff_abs = mean(same_diff_resp_secs_diff_abs, na.rm = TRUE),
    grip_sd = mean(grip_force_sd_runmean, na.rm = TRUE),
    tepr_mean = mean(rpf_auc_t2AUC_mean, na.rm = TRUE),
    pf_slope = mean(pf_slope_scaled_linear_across_grip, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(subject_id = norm_id(subject_id))
lc_dat <- lc %>% inner_join(beh_lc, by = "subject_id") %>% inner_join(ddm_subj, by = "subject_id")
lc_old <- read_csv("output/lc_integrity/lc_partial_correlations.csv", show_col_types = FALSE)
ddm_outcomes <- c("v_mean", "a_mean", "z_mean")
lc_new_ddm <- lc_old %>%
  filter(outcome %in% ddm_outcomes) %>%
  distinct(predictor, outcome) %>%
  rowwise() %>%
  mutate(stats = list(partial_cor(lc_dat, predictor, outcome))) %>%
  unnest(stats) %>%
  ungroup()
lc_keep <- lc_old %>%
  filter(!outcome %in% ddm_outcomes) %>%
  select(predictor, outcome, r, p, n, outcome_type)
lc_new_ddm <- lc_new_ddm %>%
  mutate(outcome_type = "ddm_baseline") %>%
  select(predictor, outcome, r, p, n, outcome_type)
lc_cor <- bind_rows(lc_keep, lc_new_ddm) %>%
  mutate(fdr = p.adjust(p, "fdr"), analysis = "lc", ddm_source = ifelse(outcome %in% ddm_outcomes, "M4", "copied"))
# restore original FDR for the copied rows alongside the recomputed one
lc_cor <- lc_cor %>%
  left_join(lc_old %>% select(predictor, outcome, fdr_original = fdr), by = c("predictor", "outcome"))

demo_np <- read_csv("data/raw/LC Aging Subject Data master spreadsheet - demographics.csv", skip = 1, show_col_types = FALSE) %>%
  transmute(
    subject_id = norm_id(`SUBJECT NUMBER_1`),
    age = suppressWarnings(as.numeric(`AGE AT BAP SESSION 1`)),
    sex = factor(trimws(tolower(SEX))),
    edu = suppressWarnings(as.numeric(stringr::str_extract(as.character(`EDU (years)`), "[0-9]+(?:\\.[0-9]+)?")))
  ) %>%
  filter(!is.na(subject_id), subject_id != "NA") %>%
  distinct(subject_id, .keep_all = TRUE)
np <- read_csv("data/raw/LC Aging Subject Data master spreadsheet - neuropsych.csv", skip = 1, show_col_types = FALSE) %>%
  transmute(
    subject_id = norm_id(`SUBJECT NUMBER`),
    moca = suppressWarnings(as.numeric(`MoCA (phone screen; Out of 22)`)),
    boston_naming = suppressWarnings(as.numeric(`Boston Naming (out of 23)`)),
    tmt_a = suppressWarnings(as.numeric(`Trail Making 1 (seconds)`)),
    tmt_b = suppressWarnings(as.numeric(`Trail Making 2 (seconds)`)),
    sils = suppressWarnings(as.numeric(`SILS (# correct, /40)`)),
    emq = suppressWarnings(as.numeric(`EMQ: Everyday Memory Questionnaire-13 (higher scores indicate more frequent memory problems)`)),
    gad = suppressWarnings(as.numeric(`GAD: Generalized Anziety Disorder-8 (higher value indicates more anxiety)`)),
    gds = suppressWarnings(as.numeric(`GDS: Geriatric Depression Scale-15 (higher scores suggest depression)`))
  ) %>%
  mutate(tmt_b_minus_a = tmt_b - tmt_a) %>%
  filter(!is.na(subject_id), subject_id != "NA") %>%
  distinct(subject_id, .keep_all = TRUE)
beh_np <- lc_raw %>%
  filter(!is.na(task_modality)) %>%
  group_by(subject_id) %>%
  summarise(
    accuracy = mean(accuracy, na.rm = TRUE),
    rt_mean = mean(same_diff_resp_secs, na.rm = TRUE),
    accuracy_diff_abs = mean(accuracy_diff_abs, na.rm = TRUE),
    rt_diff_abs = mean(same_diff_resp_secs_diff_abs, na.rm = TRUE),
    dprime_var = stats::sd(c(
      sdt_dprime_i1_across_grip, sdt_dprime_i2_across_grip,
      sdt_dprime_i3_across_grip, sdt_dprime_i4_across_grip
    ), na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(subject_id = norm_id(subject_id))
np_dat <- ddm_subj %>%
  left_join(demo_np, by = "subject_id") %>%
  left_join(np, by = "subject_id") %>%
  left_join(beh_np, by = "subject_id")
np_old <- read_csv("output/neuropsych_demographics/neuropsych_ddm_correlations.csv", show_col_types = FALSE)
np_new_ddm <- np_old %>%
  filter(outcome %in% ddm_outcomes) %>%
  distinct(predictor, outcome) %>%
  rowwise() %>%
  mutate(stats = list(partial_cor(np_dat, predictor, outcome))) %>%
  unnest(stats) %>%
  ungroup()
np_keep <- np_old %>% filter(!outcome %in% ddm_outcomes) %>% select(predictor, outcome, r, p, n)
np_cor <- bind_rows(np_keep, np_new_ddm %>% select(predictor, outcome, r, p, n)) %>%
  mutate(fdr = p.adjust(p, "fdr"), analysis = "neuropsych",
         ddm_source = ifelse(outcome %in% ddm_outcomes, "M4", "copied"),
         outcome_type = NA_character_) %>%
  left_join(np_old %>% select(predictor, outcome, fdr_original = fdr), by = c("predictor", "outcome"))

# Copied baseline descriptives, unchanged
base_cont <- read_csv("output/neuropsych_demographics/extended_baseline_continuous.csv", show_col_types = FALSE) %>%
  mutate(analysis = "neuropsych_baseline_continuous", ddm_source = "copied", predictor = Measure,
         outcome = "descriptive", r = NA_real_, p = NA_real_, n = n, fdr = NA_real_,
         fdr_original = NA_real_, outcome_type = `M (SD)`, copied_range = Range)
base_cat <- read_csv("output/neuropsych_demographics/extended_baseline_categorical.csv", show_col_types = FALSE) %>%
  mutate(analysis = "neuropsych_baseline_categorical", ddm_source = "copied", predictor = Characteristic,
         outcome = "descriptive", r = NA_real_, p = NA_real_, n = NA_real_, fdr = NA_real_,
         fdr_original = NA_real_, outcome_type = Value, copied_range = NA_character_)

t14 <- bind_rows(
  lc_cor %>% mutate(copied_value = NA_character_),
  np_cor %>% mutate(copied_value = NA_character_),
  base_cont %>% transmute(
    predictor = Measure, outcome = "descriptive", r = NA_real_, p = NA_real_, n = n,
    outcome_type = NA_character_, fdr = NA_real_, analysis, ddm_source, fdr_original = NA_real_,
    copied_value = `M (SD)`
  ),
  base_cat %>% transmute(
    predictor = Characteristic, outcome = "descriptive", r = NA_real_, p = NA_real_, n = NA_real_,
    outcome_type = NA_character_, fdr = NA_real_, analysis, ddm_source, fdr_original = NA_real_,
    copied_value = Value
  )
) %>%
  mutate(source_model = "M4 subject intercepts for DDM outcomes; existing tables otherwise", tier = "diss_supp")
write_csv(t14, file.path(TAB, "T14_lc_neuropsych_ddm.csv"))
note("T14", "DDM outcomes use the posterior median of the M4 fixed plus random intercept. a_mean is exp() of the log-boundary median; z_mean is plogis() of the logit-bias median. Non-DDM r, p, and n are copied. FDR is recomputed on the combined p-values; fdr_original keeps the saved value.")

# ---------------------------------------------------------------------------
# T15 legacy
# ---------------------------------------------------------------------------
message("T15")
hist <- read_csv("output/publish/exploratory_choice_history_posterior_summary.csv", show_col_types = FALSE)
fat <- read_csv("output/publish/exploratory_fatigue_trajectory_posterior_summary.csv", show_col_types = FALSE)
t15 <- bind_rows(hist, fat) %>%
  mutate(
    caveat = "fit on pre-revision model structure (no task on drift); not refit",
    source_model = model, tier = "diss_supp"
  )
write_csv(t15, file.path(TAB, "T15_legacy_temporal_dynamics.csv"))

if (length(NOTES)) write_csv(bind_rows(NOTES), file.path(INV, "table_notes.csv"))
message("Part T finished: ", TAB)
