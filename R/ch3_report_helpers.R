# Chapter 3 report helpers.
# Formatters return character strings. The minus sign is Unicode U+2212.

.minus <- "\u2212"

if (!exists(".keys_used", inherits = TRUE)) {
  .keys_used <- character(0)
}

ch3_design_keys <- c(
  "tepr_window_start",
  "tepr_window_end",
  "tepr_baseline_start",
  "tepr_baseline_end",
  "rope_v",
  "rope_a",
  "rope_z"
)

.stop_value <- function(...) {
  stop(paste0(...), call. = FALSE)
}

# v() never returns a missing, NULL, or NA value. Every successful call is logged.
v <- function(key, field = NULL) {
  if (!is.character(key) || length(key) != 1L || !nzchar(key)) {
    .stop_value("v() expects a single key name")
  }
  if (is.null(field) && !key %in% names(iv) && grepl(".", key, fixed = TRUE)) {
    bits <- strsplit(key, ".", fixed = TRUE)[[1]]
    field <- bits[[length(bits)]]
    key <- paste(bits[-length(bits)], collapse = ".")
  }
  if (!key %in% names(iv)) {
    .stop_value("inline value key not found: ", key)
  }
  obj <- iv[[key]]
  if (is.null(obj)) {
    .stop_value("inline value is NULL: ", key)
  }
  if (is.null(field)) {
    if (is.atomic(obj) && anyNA(obj)) {
      .stop_value("inline value is NA: ", key)
    }
    .keys_used <<- c(.keys_used, key)
    return(obj)
  }
  if (!is.list(obj) || is.null(names(obj)) || !field %in% names(obj)) {
    .stop_value("inline value field not found: ", key, "$", field)
  }
  val <- obj[[field]]
  if (is.null(val) || (is.atomic(val) && anyNA(val))) {
    .stop_value("inline value is NULL or NA: ", key, "$", field)
  }
  .keys_used <<- c(.keys_used, key)
  val
}

.as_single_number <- function(x, what) {
  if (length(x) != 1L || !is.numeric(x) || is.na(x)) {
    .stop_value(what, " expects a single non-NA number")
  }
  x
}

fmt_num <- function(x, d) {
  x <- .as_single_number(x, "fmt_num")
  if (length(d) != 1L || !is.numeric(d) || is.na(d) || d < 0) {
    .stop_value("fmt_num expects a non-negative digit count")
  }
  s <- sprintf(paste0("%.", as.integer(d), "f"), x)
  # A formatted zero is unsigned, including a negative zero such as -0.0.
  if (!is.na(suppressWarnings(as.numeric(s))) && as.numeric(s) == 0) {
    s <- sub("^-", "", s)
  } else {
    s <- sub("-", .minus, s, fixed = TRUE)
  }
  s
}

.drop_lead0 <- function(s) {
  sub(paste0("^(", .minus, ")?0\\."), "\\1.", s)
}

fmt_int <- function(x) {
  x <- .as_single_number(x, "fmt_int")
  rounded <- round(x)
  sign <- if (rounded < 0) .minus else ""
  paste0(sign, prettyNum(abs(rounded), big.mark = ",", scientific = FALSE, trim = TRUE))
}

fmt_signed_comma <- function(x, d) {
  x <- .as_single_number(x, "fmt_signed_comma")
  if (length(d) != 1L || !is.numeric(d) || is.na(d) || d < 0) {
    .stop_value("fmt_signed_comma expects a non-negative digit count")
  }
  s <- sprintf(paste0("%.", as.integer(d), "f"), x)
  if (!is.na(suppressWarnings(as.numeric(s))) && as.numeric(s) == 0) {
    s <- sub("^-", "", s)
  }
  neg <- grepl("^-", s)
  s <- sub("^-", "", s)
  parts <- strsplit(s, ".", fixed = TRUE)[[1]]
  int <- prettyNum(parts[[1]], big.mark = ",", scientific = FALSE, trim = TRUE)
  out <- if (length(parts) == 2L) paste0(int, ".", parts[[2]]) else int
  if (neg) paste0(.minus, out) else out
}

.number_words <- c(
  "zero", "one", "two", "three", "four",
  "five", "six", "seven", "eight", "nine"
)

nw <- function(x) {
  x <- .as_single_number(x, "nw")
  rounded <- round(x)
  if (abs(x - rounded) > 1e-8) {
    .stop_value("nw expects an integer")
  }
  if (rounded >= 0 && rounded <= 9) {
    return(.number_words[[rounded + 1L]])
  }
  fmt_int(rounded)
}

Nw <- function(x) {
  s <- nw(x)
  paste0(toupper(substr(s, 1, 1)), substr(s, 2, nchar(s)))
}

fmt_ci <- function(lo, hi, d) {
  paste0("[", fmt_num(lo, d), ", ", fmt_num(hi, d), "]")
}

fmt_est <- function(key, d = 3) {
  paste0(fmt_num(v(key, "median"), d), " ", fmt_ci(v(key, "lo"), v(key, "hi"), d))
}

.fmt_pct_point <- function(x, d) {
  if (x > 0) {
    paste0("+", sprintf(paste0("%.", as.integer(d), "f"), x))
  } else {
    fmt_num(x, d)
  }
}

.fmt_pct_triplet <- function(est, lo, hi, d) {
  paste0(.fmt_pct_point(est, d), "% [", fmt_num(lo, d), ", ", fmt_num(hi, d), "]")
}

fmt_pct <- function(key, d = 1) {
  obj <- v(key)
  if (!is.list(obj)) {
    .stop_value("fmt_pct expects a list for key: ", key)
  }
  pct_ok <- all(c("pct", "pct_lo", "pct_hi") %in% names(obj)) &&
    is.numeric(obj$pct) && is.numeric(obj$pct_lo) && is.numeric(obj$pct_hi) &&
    !anyNA(c(obj$pct, obj$pct_lo, obj$pct_hi))
  if (pct_ok) {
    est <- obj$pct
    lo <- obj$pct_lo
    hi <- obj$pct_hi
  } else if (all(c("median", "lo", "hi") %in% names(obj))) {
    med <- v(key, "median")
    lo_l <- v(key, "lo")
    hi_l <- v(key, "hi")
    est <- 100 * (exp(med) - 1)
    lo <- 100 * (exp(lo_l) - 1)
    hi <- 100 * (exp(hi_l) - 1)
  } else {
    .stop_value("fmt_pct cannot find pct/pct_lo/pct_hi or median/lo/hi for key: ", key)
  }
  .fmt_pct_triplet(est, lo, hi, d)
}

fmt_prob <- function(p, d = 3) {
  p <- .as_single_number(p, "fmt_prob")
  if (length(d) != 1L || !is.numeric(d) || is.na(d) || d < 1) {
    .stop_value("fmt_prob expects a positive digit count")
  }
  d <- as.integer(d)
  thresh <- 10^(-d)
  if (p > 1 - thresh) {
    return(paste0("> ", .drop_lead0(fmt_num(1 - thresh, d))))
  }
  if (p < thresh) {
    return(paste0("< ", .drop_lead0(fmt_num(thresh, d))))
  }
  .drop_lead0(fmt_num(p, d))
}

fmt_p <- function(p) {
  p <- .as_single_number(p, "fmt_p")
  if (p < 0.001) {
    return("p < .001")
  }
  paste0("p = ", .drop_lead0(fmt_num(p, 3)))
}

fmt_r <- function(r, lo, hi) {
  paste0(
    "r = ", .drop_lead0(fmt_num(r, 2)),
    " [", .drop_lead0(fmt_num(lo, 2)),
    ", ", .drop_lead0(fmt_num(hi, 2)), "]"
  )
}

fmt_elpd <- function(key) {
  delta <- v(key, "delta")
  se <- v(key, "se")
  paste0("\u0394ELPD = ", fmt_num(delta, 1), " \u00b1 ", fmt_num(se, 1))
}

fmt_t <- function(t, df, p) {
  df <- .as_single_number(df, "fmt_t df")
  df_s <- if (abs(df - round(df)) < 1e-8) {
    as.character(as.integer(round(df)))
  } else {
    fmt_num(df, 2)
  }
  paste0("t(", df_s, ") = ", fmt_num(t, 2), ", ", fmt_p(p))
}

fmt_rope <- function(key) {
  obj <- v(key)
  if (!is.list(obj) || !"pct_rope" %in% names(obj)) {
    .stop_value("fmt_rope cannot find pct_rope for key: ", key)
  }
  pct <- obj[["pct_rope"]]
  pct <- .as_single_number(pct, "fmt_rope")
  paste0(as.integer(round(pct)), "% in ROPE")
}

report_effect <- function(key, scale = c("drift", "log", "logit")) {
  scale <- match.arg(scale)
  med <- v(key, "median")
  lo <- v(key, "lo")
  hi <- v(key, "hi")
  if (med < 0) {
    plab <- "P(\u03b2 < 0)"
    prob <- v(key, "p_lt0")
  } else {
    plab <- "P(\u03b2 > 0)"
    prob <- v(key, "p_gt0")
  }
  prob_s <- fmt_prob(prob)
  prob_join <- if (startsWith(prob_s, ">") || startsWith(prob_s, "<")) " " else " = "
  out <- paste0(
    fmt_num(med, 3), ", 95% CrI ", fmt_ci(lo, hi, 3),
    ", ", plab, prob_join, prob_s,
    ", ", fmt_rope(key)
  )
  if (scale == "log") {
    out <- paste0(
      out, " (",
      .fmt_pct_triplet(
        100 * (exp(med) - 1),
        100 * (exp(lo) - 1),
        100 * (exp(hi) - 1),
        1
      ),
      ")"
    )
  }
  out
}

.direction_clause <- function(key) {
  med <- v(key, "median")
  if (med < 0) {
    plab <- "P(\u03b2 < 0)"
    prob <- v(key, "p_lt0")
  } else {
    plab <- "P(\u03b2 > 0)"
    prob <- v(key, "p_gt0")
  }
  prob_s <- fmt_prob(prob)
  join <- if (startsWith(prob_s, ">") || startsWith(prob_s, "<")) " " else " = "
  paste0(plab, join, prob_s)
}

.pct_from_log <- function(med, lo, hi) {
  .fmt_pct_triplet(
    100 * (exp(med) - 1),
    100 * (exp(lo) - 1),
    100 * (exp(hi) - 1),
    1
  )
}

.signed_1 <- function(x) {
  if (x > 0) paste0("+", sprintf("%.1f", x)) else fmt_num(x, 1)
}

eff <- function(key, rope = FALSE, pct = FALSE, d = 3) {
  med <- v(key, "median")
  lo <- v(key, "lo")
  hi <- v(key, "hi")
  out <- paste0(
    "\u03b2 = ", fmt_num(med, d), ", 95% CrI ", fmt_ci(lo, hi, d),
    ", ", .direction_clause(key)
  )
  if (isTRUE(rope)) {
    obj <- iv[[key]]
    pct_rope <- if (is.list(obj)) obj[["pct_rope"]] else NULL
    if (is.null(pct_rope) || (is.atomic(pct_rope) && anyNA(pct_rope))) {
      .stop_value("eff() rope = TRUE but pct_rope is missing for key: ", key)
    }
    out <- paste0(out, ", ", fmt_rope(key))
  }
  if (isTRUE(pct)) {
    out <- paste0(out, "; ", .pct_from_log(med, lo, hi))
  }
  out
}

pct_s <- function(key) {
  .pct_from_log(v(key, "median"), v(key, "lo"), v(key, "hi"))
}

est_s <- function(key, d = 3) {
  paste0(fmt_num(v(key, "median"), d), ", 95% CrI ", fmt_ci(v(key, "lo"), v(key, "hi"), d))
}

cell_s <- function(key, d = 3) {
  paste0("v = ", fmt_num(v(key, "median"), d), ", 95% CrI ", fmt_ci(v(key, "lo"), v(key, "hi"), d))
}

prob_s <- function(key) {
  paste0(
    .drop_lead0(fmt_num(v(key, "median"), 3)), " ",
    .drop_lead0_ci(v(key, "lo"), v(key, "hi"), 3)
  )
}

# Proportions and probabilities print without a leading zero. Link-scale
# DDM coefficients keep the zero, because they are not proportions.
.drop_lead0_ci <- function(lo, hi, d) {
  paste0("[", .drop_lead0(fmt_num(lo, d)), ", ", .drop_lead0(fmt_num(hi, d)), "]")
}

ch3_pending <- function(marker) {
  if (!is.character(marker) || length(marker) != 1L || !grepl("^\\[PENDING r12(\\]|:)", marker)) {
    .stop_value("ch3_pending expects a [PENDING r12] or [PENDING r12: ...] marker")
  }
  if (isTRUE(knitr::is_latex_output())) {
    return(paste0("\\textcolor{red}{\\textbf{", marker, "}}"))
  }
  to <- tryCatch(knitr::pandoc_to(), error = function(e) NA_character_)
  if (isTRUE(to %in% c("docx", "odt"))) {
    safe <- gsub("&", "&amp;", marker, fixed = TRUE)
    safe <- gsub("<", "&lt;", safe, fixed = TRUE)
    xml <- paste0(
      "<w:r><w:rPr><w:b/><w:color w:val=\"B00000\"/></w:rPr>",
      "<w:t xml:space=\"preserve\">", safe, "</w:t></w:r>"
    )
    return(paste0("`", xml, "`{=openxml}"))
  }
  paste0("<span style=\"color:#b00000;font-weight:700;\">", marker, "</span>")
}

.model_display <- c(
  "M4_thr0.15" = "M4, 0.15-s cutoff",
  "M4_thr0.25" = "M4, 0.25-s cutoff",
  "M4_subchance" = "M4, near-chance excluded",
  "P0_base" = "Baseline for P4\u2013P5",
  "P0_rt" = "Baseline for P3 without slowest trials",
  "P0_lag" = "Baseline for P6",
  "P0_pre" = "Baseline for P7",
  "P0_grip" = "Baseline for P8",
  "P3_rt" = "P3 without slowest trials"
)

ch3_model_label <- function(x) {
  x <- as.character(x)
  hit <- x %in% names(.model_display)
  x[hit] <- unname(.model_display[x[hit]])
  x
}

.italic_stat_header <- function(label) {
  gsub(
    "\\b(b|SE|z|t|p|M|SD|n|N)\\b",
    "*\\1*",
    label,
    perl = TRUE
  )
}

elpd_s <- function(delta_key, se_key, flip = FALSE) {
  delta <- v(delta_key)
  se <- v(se_key)
  if (isTRUE(flip)) delta <- -delta
  paste0("\u0394ELPD = ", fmt_num(delta, 1), " \u00b1 ", fmt_num(se, 1))
}

acc_s <- function(key) {
  paste0(
    .signed_1(v(key, "pp")), " percentage points, 95% CI ",
    fmt_ci(v(key, "pp_lo"), v(key, "pp_hi"), 1),
    ", OR = ", fmt_num(v(key, "or"), 2),
    ", ", fmt_p(v(key, "p"))
  )
}

pt_s <- function(key) {
  paste0(
    "*M*~diff~ = ", fmt_num(v(key, "diff"), 2), ", ",
    fmt_t(v(key, "t"), v(key, "df"), v(key, "p"))
  )
}

.require_rope_match <- function() {
  if (!isTRUE(all.equal(v("rope_a"), v("rope_z")))) {
    dir.create("output/diagnostics/qmd_phase2a", recursive = TRUE, showWarnings = FALSE)
    writeLines(
      sprintf("rope_a (%s) != rope_z (%s).", v("rope_a"), v("rope_z")),
      "output/diagnostics/qmd_phase2a/STOPPED.md"
    )
    stop("rope_a != rope_z", call. = FALSE)
  }
}

cap_fig_design <- function() paste0(
  "Task and model. (A) Trial timeline from squeeze onset: grip gauge (low effort, 5% MVC; high effort, 40% MVC), standard and probe stimuli, ",
  "response cue and response window. (B) Diffusion model with response coding: evidence accumulates from the starting point (z) toward the ",
  "\u201cdifferent\u201d (upper) or \u201csame\u201d (lower) boundary, separated by a, at drift rate v; t\u2080 is non-decision time. ",
  "(C) Predictors of each parameter in the primary model (M4).")

cap_fig_condition_params <- function() paste0(
  "Posterior drift rate (top) and boundary separation (bottom) by task, stimulus type and effort in the primary model (M4). ",
  "Points are posterior medians and bars 95% credible intervals. Drift is signed toward the \u201cdifferent\u201d boundary, ",
  "so negative drift on Standard trials accumulates toward the correct \u201csame\u201d response. ",
  "Starting point and non-decision time did not vary by stimulus type and are not shown.")

cap_fig_effort_forest <- function() {
  .require_rope_match()
  paste0(
    "Effects of high versus low effort in the primary model (M4, filled) and four robustness variants (open). ",
    "Points are posterior medians and bars 95% credible intervals. Shaded bands mark the region of practical equivalence ",
    "(drift \u00b1", fmt_num(v("rope_v"), 2), "; log boundary and logit starting point \u00b1", fmt_num(v("rope_a"), 2), "). ",
    "Drift criterion is the effort effect common to all trials (negative values favor \u201csame\u201d); evidence quality is the effort effect ",
    "on the separation between identical and different stimuli.",
    if (!isTRUE(v("pass_M4_thr015"))) " \u2021 Did not meet the convergence criterion (R\u0302 < 1.01)." else "")
}

cap_fig_pupil_boundary <- function() paste0(
  "Pupil measures and boundary separation. Each row is a separate model. Points are posterior median percentage changes in boundary ",
  "separation per within-person SD of the pupil predictor, and bars are 95% credible intervals. \u0394ELPD \u00b1 SE compares each model ",
  "with a baseline model fit to the same trials. Upper rows: measures from the current trial; lower rows: measures preceding the current decision.")

note_tbl_effort_effects <- function() {
  .require_rope_match()
  paste0(
    "Estimates are posterior medians with 95% credible intervals (CrI) on the link scale: drift, identity; boundary separation, log; ",
    "starting point, logit. Direction is the posterior probability that the effect has the sign of its median. ",
    "Change in a is the percentage change in boundary separation. ROPE = region of practical equivalence (drift \u00b1",
    fmt_num(v("rope_v"), 2), "; boundary and starting point \u00b1", fmt_num(v("rope_a"), 2), "). ",
    "DDM coefficients are given to three decimals because the effects are small relative to the region of practical equivalence.")
}

note_tbl_pupil_ordering <- function() paste0(
  "Each row is a separate model. Estimates are slopes on log boundary separation per within-person SD of the predictor, ",
  "with the percentage change in a. \u0394ELPD \u00b1 SE is relative to a baseline model without the pupil predictor, fit to the same trials. ",
      "Trial counts differ across predictors, and each predictor requires its own valid window.")

load_ch3_design <- function() {
  vals <- lapply(ch3_design_keys, function(k) {
    if (!k %in% names(iv)) {
      .stop_value("design constant missing from inline values: ", k)
    }
    v(k)
  })
  stats::setNames(vals, ch3_design_keys)
}

ch3_map_labels <- function(x, map, what) {
  missing <- unique(x[!x %in% names(map)])
  if (length(missing)) {
    stop(what, " has unmapped labels: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  unname(map[x])
}

ch3_fmt_cells <- function(x, fun) {
  vapply(seq_along(x), function(i) {
    v <- x[[i]]
    if (length(v) != 1L || is.na(v)) {
      ""
    } else {
      fun(v)
    }
  }, character(1))
}

ch3_posterior_cols <- function(median, lo, hi, digits = 3) {
  data.frame(
    Estimate = ch3_fmt_cells(median, function(v) fmt_num(v, digits)),
    `95% CrI` = mapply(function(a, b) {
      if (is.na(a) || is.na(b)) "" else fmt_ci(a, b, digits)
    }, lo, hi, USE.NAMES = FALSE),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

ch3_direction_col <- function(median, p_lt0, p_gt0) {
  mapply(function(med, plt, pgt) {
    if (is.na(med) || is.na(plt) || is.na(pgt)) {
      return("")
    }
    if (med < 0) {
      paste0("P(\u03b2 < 0) ", if (plt > 0.999) "> .999" else paste0("= ", fmt_prob(plt)))
    } else {
      prob <- fmt_prob(pgt)
      paste0("P(\u03b2 > 0) ", if (startsWith(prob, ">") || startsWith(prob, "<")) prob else paste0("= ", prob))
    }
  }, median, p_lt0, p_gt0, USE.NAMES = FALSE)
}

ch3_rope_col <- function(pct) {
  ch3_fmt_cells(pct, function(v) paste0(as.integer(round(v)), "%"))
}

ch3_pct_change_col <- function(est, lo, hi) {
  mapply(function(e, a, b) {
    if (is.na(e) || is.na(a) || is.na(b)) "" else .fmt_pct_triplet(e, a, b, 1)
  }, est, lo, hi, USE.NAMES = FALSE)
}

.effort_label_map <- c(
  "b_effort_conditionhigh" = "Drift criterion",
  "b_effort_x_stim" = "Evidence quality",
  "b_bs_effort_conditionhigh" = "Boundary separation",
  "b_bias_effort_conditionhigh" = "Starting point",
  "drift_different" = "Drift on Hard and Easy trials",
  "drift_same" = "Drift on Standard trials",
  "criterion_ADT" = "Drift criterion, auditory",
  "criterion_VDT" = "Drift criterion, visual",
  "b_taskVDT:effort_conditionhigh" = "Drift criterion \u00d7 task",
  "b_taskVDT:effort_x_stim" = "Evidence quality \u00d7 task"
)

.fixef_label_map <- c(
  .effort_label_map,
  "b_Intercept" = "Drift intercept",
  "b_bs_Intercept" = "Boundary separation intercept",
  "b_ndt_Intercept" = "Non-decision time intercept",
  "b_bias_Intercept" = "Starting point intercept",
  "b_difficulty_3Hard" = "Hard (drift)",
  "b_difficulty_3Easy" = "Easy (drift)",
  "b_taskVDT" = "Visual task (drift)",
  "b_difficulty_3Hard:taskVDT" = "Hard \u00d7 visual (drift)",
  "b_difficulty_3Easy:taskVDT" = "Easy \u00d7 visual (drift)",
  "b_bs_difficulty_3Hard" = "Hard (boundary separation)",
  "b_bs_difficulty_3Easy" = "Easy (boundary separation)",
  "b_bs_taskVDT" = "Visual task (boundary separation)",
  "b_bias_taskVDT" = "Visual task (starting point)"
)

.quantity_map <- c(
  v = "Drift",
  a = "Boundary separation",
  z = "Starting point",
  t0 = "Non-decision time"
)

.glmm_label_map <- c(
  "(Intercept)" = "Intercept",
  "difficulty_3Hard" = "Hard",
  "difficulty_3Easy" = "Easy",
  "effort_conditionhigh" = "High effort",
  "taskVDT" = "Visual task",
  "difficulty_3Hard:effort_conditionhigh" = "Hard \u00d7 high effort",
  "difficulty_3Easy:effort_conditionhigh" = "Easy \u00d7 high effort"
)

.pupil_term_map <- c(
  "none (baseline)" = "Baseline (no pupil slope)",
  "b_bias_tepr_c" = "Current-trial TEPR on starting point",
  "b_tepr_c" = "Current-trial TEPR on drift",
  "b_tepr_c:stim_sign" = "Current-trial TEPR \u00d7 stimulus",
  "b_bs_tepr_c" = "Current-trial TEPR on boundary separation",
  "b_bias_base_c" = "Pre-squeeze baseline on starting point"
)

.random_slope_map <- c(
  "sd_subject_id__effort_conditionhigh" = "SD, drift criterion",
  "sd_subject_id__bs_effort_conditionhigh" = "SD, boundary separation",
  "cor_subject_id__Intercept__effort_conditionhigh" = "Correlation, drift intercept and drift criterion",
  "cor_subject_id__bs_Intercept__bs_effort_conditionhigh" = "Correlation, boundary intercept and boundary slope"
)

.temporal_label_map <- c(
  "b_bias_Intercept" = "Starting-point intercept",
  "b_bias_effort_conditionLow_5_MVC" = "Starting point, low effort",
  "b_bias_prev_choice" = "Starting point, previous choice",
  "b_bias_prev_choice:effort_conditionLow_5_MVC" = "Starting point, previous choice \u00d7 low effort",
  "b_prev_choice" = "Drift, previous choice",
  "b_bias_prev_choice:prev_correct" = "Starting point, previous choice \u00d7 previous correct",
  "b_bias_prev_correct" = "Starting point, previous correct",
  "b_bs_age_z" = "Boundary separation, age",
  "b_bs_block_halfSecond_Half" = "Boundary separation, second half",
  "b_bs_effort_conditionHigh_40_MVC" = "Boundary separation, high effort",
  "b_bs_effort_conditionHigh_40_MVC:block_halfSecond_Half" = "Boundary separation, high effort \u00d7 second half",
  "b_age_z" = "Drift, age",
  "b_block_halfSecond_Half" = "Drift, second half",
  "b_block_halfSecond_Half:age_z" = "Drift, second half \u00d7 age",
  "b_effort_conditionHigh_40_MVC" = "Drift, high effort",
  "b_effort_conditionHigh_40_MVC:age_z" = "Drift, high effort \u00d7 age",
  "b_effort_conditionHigh_40_MVC:block_halfSecond_Half" = "Drift, high effort \u00d7 second half",
  "b_effort_conditionHigh_40_MVC:block_halfSecond_Half:age_z" = "Drift, high effort \u00d7 second half \u00d7 age"
)

ch3_effort_block <- function(df, what) {
  if (!"term" %in% names(df)) {
    stop(what, " has no term column", call. = FALSE)
  }
  data.frame(
    Parameter = ch3_map_labels(df$term, .effort_label_map, what),
    ch3_posterior_cols(df$median, df$q2.5, df$q97.5, 3),
    Direction = ch3_direction_col(df$median, df$p_lt0, df$p_gt0),
    `In ROPE` = ch3_rope_col(df$pct_in_rope),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

make_table <- function(df, cols, col_labels, digits_map = NULL, footnote = NULL) {
  if (nrow(df) == 0L) {
    who <- tryCatch(deparse(sys.call(-1)[[1]]), error = function(e) "unknown caller")
    stop("make_table received 0 rows from ", who, call. = FALSE)
  }
  missing_cols <- setdiff(cols, names(df))
  if (length(missing_cols)) {
    stop("make_table missing columns: ", paste(missing_cols, collapse = ", "), call. = FALSE)
  }
  if (length(col_labels) != length(cols)) {
    stop("make_table col_labels length does not match cols", call. = FALSE)
  }
  shown <- df[, cols, drop = FALSE]
  if (!is.null(digits_map)) {
    for (cn in names(digits_map)) {
      if (!cn %in% names(shown)) {
        stop("digits_map column not selected: ", cn, call. = FALSE)
      }
      spec <- digits_map[[cn]]
      shown[[cn]] <- ch3_fmt_cells(shown[[cn]], function(v) {
        if (identical(spec, "p")) {
          fmt_prob(v)
        } else if (identical(spec, "prob")) {
          fmt_prob(v)
        } else if (identical(spec, "int")) {
          fmt_int(v)
        } else if (is.numeric(spec)) {
          fmt_num(v, spec)
        } else {
          stop("unknown digits_map spec for ", cn, call. = FALSE)
        }
      })
    }
  }
  for (cn in names(shown)) {
    if (is.numeric(shown[[cn]])) {
      stop("numeric column lacks digits_map: ", cn, call. = FALSE)
    }
    shown[[cn]] <- ifelse(is.na(shown[[cn]]), "", as.character(shown[[cn]]))
  }
  names(shown) <- vapply(col_labels, .italic_stat_header, character(1))
  kb <- knitr::kable(
    shown,
    format = "pipe",
    align = c("l", rep("r", max(0, ncol(shown) - 1)))
  )
  # as.character() is one string per line. paste0() would recycle a footnote onto every line.
  body <- paste(as.character(kb), collapse = "\n")
  note <- ""
  if (!is.null(footnote) && length(footnote) == 1L && !is.na(footnote) && nzchar(footnote)) {
    note <- paste0("\n\n*Note.* ", footnote)
  }
  knitr::asis_output(paste0(body, note, "\n"))
}

ch3_tbl_priors <- function() {
  out <- data.frame(
    Parameter = c(
      "Drift intercept",
      "Drift slopes",
      "Boundary separation intercept",
      "Boundary separation slopes",
      "Non-decision time intercept",
      "Starting point intercept and slopes",
      "Random-effect SDs"
    ),
    Prior = c(
      "Normal(0, 1)",
      "Normal(0, 0.5)",
      "Normal(log 1.3, 0.25)",
      "Normal(0, 0.2)",
      "Normal(log 0.35, 0.15)",
      "Normal(0, 0.5)",
      "Exponential(5), drift and starting point; Exponential(10), boundary separation"
    ),
    Bounds = c(
      "\u2014",
      "\u2014",
      "log 0.3 to log 5",
      "\u2014",
      "log 0.02 to log(shortest RT \u2212 0.01)",
      "\u2014",
      "\u2014"
    ),
    stringsAsFactors = FALSE
  )
  make_table(
    out,
    cols = names(out),
    col_labels = c("Parameter", "Prior", "Bounds"),
    footnote = "Pupil slopes used the class priors of the parameter they entered."
  )
}

ch3_tbl_formulas <- function() {
  # One brms formula per reported model. P0_* copies use the P0 formula.
  f <- function(...) paste(c(...), collapse = "; ")
  m0_v <- "rt | dec(choice_binary) ~ difficulty_3 + (1 | subject_id)"
  m0_bs <- "bs ~ difficulty_3 + (1 | subject_id)"
  m1_v <- "rt | dec(choice_binary) ~ difficulty_3 + effort_condition + (1 | subject_id)"
  m1_bs <- "bs ~ difficulty_3 + effort_condition + (1 | subject_id)"
  m2_v <- "rt | dec(choice_binary) ~ difficulty_3 * effort_condition + (1 | subject_id)"
  m2_bs <- "bs ~ difficulty_3 * effort_condition + (1 | subject_id)"
  m3_v <- "rt | dec(choice_binary) ~ difficulty_3 + effort_condition + effort_x_stim + (1 | subject_id)"
  m4_v <- "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id)"
  m4b_v <- "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + effort_condition:task + effort_x_stim:task + (1 | subject_id)"
  m4r_v <- "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 + effort_condition | subject_id)"
  m4_bs <- "bs ~ difficulty_3 + task + effort_condition + (1 | subject_id)"
  m4r_bs <- "bs ~ difficulty_3 + task + effort_condition + (1 + effort_condition | subject_id)"
  ndt <- "ndt ~ 1"
  bias <- "bias ~ task + effort_condition + (1 | subject_id)"
  p0 <- f(m4_v, m4_bs, ndt, bias)
  rows <- list(
    M0 = f(m0_v, m0_bs, ndt, bias),
    M1 = f(m1_v, m1_bs, ndt, bias),
    M2 = f(m2_v, m2_bs, ndt, bias),
    M3 = f(m3_v, m1_bs, ndt, bias),
    M4 = p0,
    M4b = f(m4b_v, m4_bs, ndt, bias),
    M4r = f(m4r_v, m4r_bs, ndt, bias),
    P0 = p0,
    P1 = f(m4_v, m4_bs, ndt, "bias ~ task + effort_condition + tepr_c + (1 | subject_id)"),
    P2 = f(
      "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + tepr_c + tepr_c:stim_sign + (1 | subject_id)",
      m4_bs, ndt, bias
    ),
    P3 = f(m4_v, "bs ~ difficulty_3 + task + effort_condition + tepr_c + (1 | subject_id)", ndt, bias),
    P3_rt = f(m4_v, "bs ~ difficulty_3 + task + effort_condition + tepr_c + (1 | subject_id)", ndt, bias),
    P4 = f(m4_v, m4_bs, ndt, "bias ~ task + effort_condition + base_c + (1 | subject_id)"),
    P5 = f(m4_v, "bs ~ difficulty_3 + task + effort_condition + base_c + (1 | subject_id)", ndt, bias),
    P6 = f(m4_v, "bs ~ difficulty_3 + task + effort_condition + lag_tepr_c + (1 | subject_id)", ndt, bias),
    P7 = f(m4_v, "bs ~ difficulty_3 + task + effort_condition + prechoice_c + (1 | subject_id)", ndt, bias),
    P8 = f(m4_v, "bs ~ difficulty_3 + task + effort_condition + grip_c + (1 | subject_id)", ndt, bias),
    P0_base = p0,
    P0_lag = p0,
    P0_pre = p0,
    P0_grip = p0,
    P0_rt = p0
  )
  formula <- sprintf("`%s`", unname(unlist(rows)))
  model <- ch3_model_label(names(rows))
  width_m <- max(nchar(c("Model", model)))
  width_f <- max(nchar(c("Formula", formula)))
  pad <- function(x, w) sprintf(paste0("%-", w, "s"), x)
  line <- function(a, b) paste(pad(a, width_m), pad(b, width_f), sep = "  ")
  body <- vapply(seq_along(model), function(i) line(model[[i]], formula[[i]]), character(1))
  knitr::asis_output(paste(c(
    line("Model", "Formula"),
    line(strrep("-", width_m), strrep("-", width_f)),
    body,
    ""
  ), collapse = "\n"))
}

ch3_tbl_demographics <- function(df) {
  char <- df$Characteristic
  value <- df$Full_Sample
  char[char == "MoCA, score (SD)"] <- "MoCA-telephone, score /22 (SD)"
  n <- as.integer(value[char == "N"])
  if (length(n) != 1L || is.na(n)) {
    stop("T1 has no N row", call. = FALSE)
  }
  race_rows <- c(
    "  White/Caucasian",
    "  Black/African American",
    "  Asian",
    "  Other"
  )
  race_counts <- vapply(race_rows, function(lab) {
    cell <- value[char == lab]
    if (length(cell) != 1L) stop("T1 is missing race row: ", lab, call. = FALSE)
    as.integer(sub("^([0-9]+).*", "\\1", cell))
  }, integer(1))
  n_missing <- n - sum(race_counts)
  if (n_missing < 0) stop("T1 race counts exceed N", call. = FALSE)
  missing_cell <- sprintf("%d (%.1f%%)", n_missing, round(100 * n_missing / n, 1))
  # The two unclassified source rows are blank race fields, so the label is Not reported.
  out_char <- character(0)
  out_val <- character(0)
  for (i in seq_along(char)) {
    out_char <- c(out_char, char[[i]])
    out_val <- c(out_val, value[[i]])
    if (char[[i]] == "  Other") {
      out_char <- c(out_char, "  Not reported")
      out_val <- c(out_val, missing_cell)
    }
    if (char[[i]] == "Hispanic/Latino") {
      out_char[length(out_char)] <- "  Hispanic/Latino"
    }
  }
  hisp <- which(out_char == "  Hispanic/Latino")
  if (length(hisp) != 1L) stop("T1 has no Hispanic/Latino row", call. = FALSE)
  out_char <- append(out_char, "Ethnicity, count (%)", after = hisp - 1L)
  out_val <- append(out_val, "", after = hisp - 1L)
  out_char <- gsub("^  ", "\u00a0\u00a0", out_char)
  out <- data.frame(Characteristic = out_char, `Full sample` = out_val, check.names = FALSE, stringsAsFactors = FALSE)
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_effort_effects <- function(df, footnote = NULL) {
  order_terms <- c(
    "b_effort_conditionhigh",
    "b_effort_x_stim",
    "b_bs_effort_conditionhigh",
    "b_bias_effort_conditionhigh",
    "drift_different",
    "drift_same"
  )
  df <- df[match(order_terms, df$term), , drop = FALSE]
  if (anyNA(df$term)) {
    stop("T2 is missing an expected effort row", call. = FALSE)
  }
  out <- ch3_effort_block(df, "T2")
  out$`Change in a` <- ifelse(
    df$link == "log",
    ch3_pct_change_col(df$natural_scale_median, df$natural_scale_q2.5, df$natural_scale_q97.5),
    ""
  )
  make_table(
    out,
    cols = names(out),
    col_labels = names(out),
    footnote = footnote
  )
}

ch3_tbl_pupil_ordering <- function(df, footnote = NULL) {
  # T8 stores these rows as tier "ms_supp". The six models are the Figure 5 set.
  order_models <- c("P3", "P3_rt", "P7", "P6", "P5", "P8")
  missing <- setdiff(order_models, df$model)
  if (length(missing)) {
    stop("T8 is missing ", paste(missing, collapse = ", "), call. = FALSE)
  }
  df <- df[match(order_models, df$model), , drop = FALSE]
  tepr_post <- as.character(v("tepr_window_post_probe"))
  tepr_after <- sub(" s$", " s after probe", tepr_post)
  # Same names as F5 in scripts/final/F_figures.R.
  labels <- c(
    P3 = paste0("Post-probe TEPR (", tepr_after, ")"),
    P3_rt = "Post-probe TEPR, slowest 20% removed",
    P7 = "Pre-response window (0.5 s)",
    P6 = "Previous-trial TEPR",
    P5 = "Pre-squeeze baseline pupil",
    P8 = "Grip-period pupil"
  )
  out <- data.frame(
    Model = ch3_model_label(df$model),
    Predictor = unname(labels[df$model]),
    Estimate = mapply(function(med, lo, hi) {
      paste(fmt_num(med, 3), fmt_ci(lo, hi, 3))
    }, df$median, df$q2.5, df$q97.5, USE.NAMES = FALSE),
    Change = ch3_pct_change_col(df$pct_change_median, df$pct_change_q2.5, df$pct_change_q97.5),
    ELPD = mapply(function(d, s) {
      if (is.na(d) || is.na(s)) "" else paste0(fmt_num(d, 1), " \u00b1 ", fmt_num(s, 1))
    }, df$delta_elpd_vs_baseline, df$se_delta_elpd, USE.NAMES = FALSE),
    Trials = ch3_fmt_cells(df$n_trials, fmt_int),
    Participants = ch3_fmt_cells(df$n_subjects, fmt_int),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(
    out,
    cols = names(out),
    col_labels = c(
      "Model", "Predictor", "Estimate [95% CrI]", "Change in a",
      "\u0394ELPD \u00b1 SE", "Trials", "Participants"
    ),
    footnote = footnote
  )
}

ch3_tbl_trial_counts <- function(df) {
  out <- data.frame(
    Task = df$task,
    Difficulty = df$difficulty_3,
    Effort = tools::toTitleCase(df$effort_condition),
    Trials = ch3_fmt_cells(df$n_trials, fmt_int),
    Participants = ch3_fmt_cells(df$n_subjects, fmt_int),
    `Trials per participant` = ch3_fmt_cells(df$trials_per_subject, function(v) fmt_num(v, 1)),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_model_comparison <- function(df) {
  notes <- as.character(df$rhat_footnote)
  ok <- !is.na(df$rhat_footnote) & nzchar(trimws(notes))
  footnote <- if (any(ok)) paste(df$model[ok], notes[ok], collapse = " ") else NULL
  out <- data.frame(
    Model = df$model,
    ELPD = ch3_fmt_cells(df$elpd_loo, function(v) fmt_signed_comma(v, 1)),
    SE = ch3_fmt_cells(df$se_elpd_loo, function(v) fmt_num(v, 1)),
    delta = ch3_fmt_cells(df$delta_elpd_vs_M4, function(v) fmt_signed_comma(v, 1)),
    se_delta = ch3_fmt_cells(df$se_delta_elpd_vs_M4, function(v) fmt_num(v, 1)),
    k = ch3_fmt_cells(df$n_k_gt_0.7, fmt_int),
    rhat = ch3_fmt_cells(df$max_rhat, function(v) fmt_num(v, 3)),
    ess = ch3_fmt_cells(df$min_bulk_ess, fmt_int),
    Pass = ifelse(df$passes_convergence_rule, "Yes", "No"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(
    out,
    cols = names(out),
    col_labels = c(
      "Model", "ELPD", "SE",
      "\u0394ELPD vs. M4", "SE of \u0394",
      "*k* > 0.7", "Max *R\u0302*", "Min bulk ESS", "Pass"
    ),
    footnote = footnote
  )
}

ch3_tbl_convergence <- function(df) {
  drop_models <- c("P0_r6", "M3_thr0.15", "M3_thr0.25")
  df <- df[!df$model %in% drop_models, , drop = FALSE]
  behavioral_models <- c(
    "M4",
    "M0", "M1", "M2", "M3", "M4b",
    "M4r", "M4_thr0.15", "M4_thr0.25", "M4_subchance"
  )
  pupil_models <- c(
    "P0", "P0_base", "P0_rt", "P0_lag", "P0_pre", "P0_grip",
    "P1", "P2", "P3", "P3_rt", "P4", "P5", "P6", "P7", "P8"
  )
  # Pupil rows are absent until the r12 fits replace the quarantined r10 rows.
  if (setequal(df$model, c(behavioral_models, pupil_models))) {
    order_models <- c(behavioral_models, pupil_models)
  } else if (setequal(df$model, behavioral_models)) {
    order_models <- behavioral_models
  } else {
    order_models <- character(0)
  }
  if (!length(order_models)) {
    stop(
      "convergence display models do not match the expected set: ",
      paste(setdiff(union(df$model, order_models), intersect(df$model, order_models)), collapse = ", "),
      call. = FALSE
    )
  }
  df <- df[match(order_models, df$model), , drop = FALSE]
  pass <- df$max_rhat < 1.01 & df$min_bulk_ess >= 400 & df$min_tail_ess >= 400 & df$divergences == 0
  fail <- df$model[!pass]
  footnote <- paste0(
    "A model passes when max R-hat < 1.01, bulk ESS and tail ESS are at least 400, and there are 0 divergences. ",
    if (length(fail)) paste0("Fails: ", paste(ch3_model_label(fail), collapse = ", "), ".") else "Every displayed model passes."
  )
  out <- data.frame(
    Model = ch3_model_label(df$model),
    Role = df$role,
    `Max R-hat` = ch3_fmt_cells(df$max_rhat, function(v) fmt_num(v, 3)),
    `Min bulk ESS` = ch3_fmt_cells(df$min_bulk_ess, fmt_int),
    `Min tail ESS` = ch3_fmt_cells(df$min_tail_ess, fmt_int),
    Divergences = ch3_fmt_cells(df$divergences, fmt_int),
    Pass = ifelse(pass, "Yes", "No"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out), footnote = footnote)
}

ch3_tbl_fixef <- function(df) {
  effort_terms <- c(
    "b_effort_conditionhigh",
    "b_effort_x_stim",
    "b_bs_effort_conditionhigh",
    "b_bias_effort_conditionhigh"
  )
  scale_word <- c(identity = "identity", log = "log", logit = "logit")
  labels <- ch3_map_labels(df$term, .fixef_label_map, "T4")
  labels[df$term == "b_bs_effort_conditionhigh"] <- "High effort (boundary separation)"
  labels[df$term == "b_bias_effort_conditionhigh"] <- "High effort (starting point)"
  if (!all(df$link %in% names(scale_word))) {
    stop("T4 has an unknown link scale", call. = FALSE)
  }
  scale <- unname(scale_word[df$link])
  labels <- vapply(seq_along(labels), function(i) {
    if (grepl("\\)$", labels[[i]])) {
      sub("\\)$", paste0(", ", scale[[i]], ")"), labels[[i]])
    } else {
      paste0(labels[[i]], " (", scale[[i]], ")")
    }
  }, character(1))
  keep <- df$term %in% effort_terms
  out <- data.frame(
    Parameter = labels,
    ch3_posterior_cols(df$median, df$q2.5, df$q97.5, 3),
    Direction = ifelse(keep, ch3_direction_col(df$median, df$p_lt0, df$p_gt0), ""),
    `In ROPE` = ifelse(keep, ch3_rope_col(df$pct_in_rope), ""),
    `R-hat` = ch3_fmt_cells(df$rhat, function(v) fmt_num(v, 3)),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

.cell_est <- function(med, lo, hi) {
  if (is.na(med) || is.na(lo) || is.na(hi)) "" else paste(fmt_num(med, 3), fmt_ci(lo, hi, 3))
}

ch3_tbl_condition_cells <- function(df) {
  # Wide layout: task x difficulty rows; drift and boundary at each effort.
  # Starting point depends only on task x effort, and non-decision time is one value.
  pick <- function(task, difficulty, effort, quantity) {
    hit <- df$task == task & df$difficulty_3 == difficulty &
      df$effort_condition == effort & df$quantity == quantity
    df[hit, , drop = FALSE]
  }
  tasks <- c("ADT", "VDT")
  diffs <- c("Standard", "Easy", "Hard")
  rows <- list()
  for (task in tasks) {
    for (difficulty in diffs) {
      cell <- function(effort, quantity) {
        hit <- pick(task, difficulty, effort, quantity)
        if (nrow(hit) != 1L) {
          stop("T3 expected one ", quantity, " cell for ", task, " ", difficulty, " ", effort, call. = FALSE)
        }
        .cell_est(hit$median, hit$q2.5, hit$q97.5)
      }
      rows[[length(rows) + 1L]] <- data.frame(
        Task = task,
        Difficulty = difficulty,
        `Drift, low` = cell("low", "v"),
        `Drift, high` = cell("high", "v"),
        `Boundary, low` = cell("low", "a"),
        `Boundary, high` = cell("high", "a"),
        check.names = FALSE,
        stringsAsFactors = FALSE
      )
    }
  }
  z_bits <- character(0)
  for (task in tasks) {
    for (effort in c("low", "high")) {
      hits <- df[df$task == task & df$effort_condition == effort & df$quantity == "z", , drop = FALSE]
      if (!nrow(hits)) stop("T3 is missing starting point for ", task, " ", effort, call. = FALSE)
      if (length(unique(round(hits$median, 8))) != 1L) {
        stop("T3 starting point is not constant across difficulty for ", task, " ", effort, call. = FALSE)
      }
      z_bits <- c(z_bits, paste0(task, " ", effort, " ", .cell_est(hits$median[1], hits$q2.5[1], hits$q97.5[1])))
    }
  }
  t0 <- df[df$quantity == "t0", , drop = FALSE]
  if (!nrow(t0) || length(unique(round(t0$median, 8))) != 1L) {
    stop("T3 non-decision time is not a single value", call. = FALSE)
  }
  footnote <- paste0(
    "Starting point varies by task and effort only: ",
    paste(z_bits, collapse = "; "),
    ". Non-decision time is ",
    .cell_est(t0$median[1], t0$q2.5[1], t0$q97.5[1]),
    " in every cell. These note values are the condition-cell summaries, not the link-scale coefficients."
  )
  out <- do.call(rbind, rows)
  make_table(out, cols = names(out), col_labels = names(out), footnote = footnote)
}

ch3_tbl_ppc_choice <- function(df) {
  df <- df[df$model == "M4", , drop = FALSE]
  out <- data.frame(
    Task = df$task,
    Difficulty = df$difficulty_3,
    Effort = tools::toTitleCase(df$effort_condition),
    Observed = ch3_fmt_cells(df$observed, function(v) .drop_lead0(fmt_num(v, 3))),
    Predicted = ch3_fmt_cells(df$pred_median, function(v) .drop_lead0(fmt_num(v, 3))),
    `95% PI` = mapply(function(a, b) {
      if (is.na(a) || is.na(b)) "" else .drop_lead0_ci(a, b, 3)
    }, df$pred_q2.5, df$pred_q97.5, USE.NAMES = FALSE),
    Inside = ifelse(df$inside, "Yes", "No"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_robustness <- function(df) {
  fail <- df$max_rhat >= 1.01
  out <- data.frame(
    Model = ch3_model_label(df$model),
    Parameter = ch3_map_labels(df$term, .effort_label_map, "T6a"),
    ch3_posterior_cols(df$median, df$q2.5, df$q97.5, 3),
    `In ROPE` = ch3_rope_col(df$pct_in_rope),
    Trials = ch3_fmt_cells(df$n_trials, fmt_int),
    Participants = ch3_fmt_cells(df$n_subjects, fmt_int),
    Pass = ifelse(fail, paste0("No", "\u2021"), "Yes"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  footnote <- if (any(fail)) {
    paste0(
      "\u2021 did not meet the R-hat < 1.01 criterion. ",
      paste(unique(df$model[fail]), collapse = ", "),
      "."
    )
  } else {
    NULL
  }
  make_table(out, cols = names(out), col_labels = names(out), footnote = footnote)
}

ch3_tbl_random_slopes <- function(df) {
  is_cor <- df$link == "correlation"
  estimate <- mapply(function(v, cor_row) {
    if (is.na(v)) {
      ""
    } else if (cor_row) {
      paste0("r = ", .drop_lead0(fmt_num(v, 2)))
    } else {
      fmt_num(v, 3)
    }
  }, df$median, is_cor, USE.NAMES = FALSE)
  out <- data.frame(
    Parameter = ch3_map_labels(df$term, .random_slope_map, "T6b"),
    Estimate = estimate,
    `95% CrI` = mapply(function(a, b, cor_row) {
      if (is.na(a) || is.na(b)) {
        ""
      } else if (cor_row) {
        paste0("[", .drop_lead0(fmt_num(a, 2)), ", ", .drop_lead0(fmt_num(b, 2)), "]")
      } else {
        fmt_ci(a, b, 3)
      }
    }, df$q2.5, df$q97.5, is_cor, USE.NAMES = FALSE),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_m4b <- function(df) {
  out <- ch3_effort_block(df, "T4b")
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_pupil_models <- function(slopes, effort) {
  delta <- mapply(function(d, s) {
    if (is.na(d) || is.na(s)) "" else paste0(fmt_num(d, 1), " \u00b1 ", fmt_num(s, 1))
  }, slopes$delta_elpd_vs_baseline, slopes$se_delta_elpd, USE.NAMES = FALSE)
  # The interaction row repeats the model-level ELPD. Show it once, on the first P2 row.
  interaction <- slopes$term == "b_tepr_c:stim_sign"
  delta[interaction] <- ""
  slope_out <- data.frame(
    Block = "Pupil slope",
    Model = ch3_model_label(slopes$model),
    Parameter = ch3_map_labels(slopes$term, .pupil_term_map, "T7"),
    ch3_posterior_cols(slopes$median, slopes$q2.5, slopes$q97.5, 3),
    `Change in a` = ch3_pct_change_col(
      slopes$pct_change_median, slopes$pct_change_q2.5, slopes$pct_change_q97.5
    ),
    `Delta ELPD` = delta,
    Trials = ch3_fmt_cells(slopes$n_trials, fmt_int),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  effort_out <- data.frame(
    Block = "Effort effects in the pupil subsample (P0)",
    Model = ch3_model_label(effort$model),
    Parameter = ch3_map_labels(effort$term, .effort_label_map, "T7 P0"),
    ch3_posterior_cols(effort$median, effort$q2.5, effort$q97.5, 3),
    `Change in a` = ch3_pct_change_col(
      effort$pct_change_a_median, effort$pct_change_a_q2.5, effort$pct_change_a_q97.5
    ),
    `Delta ELPD` = "",
    Trials = ch3_fmt_cells(effort$n_trials, fmt_int),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  out <- rbind(slope_out, effort_out)
  make_table(
    out,
    cols = names(out),
    col_labels = names(out),
    footnote = paste(
      "P1, P2, and P3 are compared with P0.",
      "P4 and P5 are compared with the baseline for P4\u2013P5.",
      "P3 without the slowest trials is compared with its own baseline.",
      "P6 is compared with the baseline for P6, P7 with the baseline for P7, and P8 with the baseline for P8.",
      "P5, P3 without the slowest trials, P6, P7, and P8 are in the ordering table rather than this slope table."
    )
  )
}

ch3_ms_sd <- function(mean, sd) {
  if (is.na(mean) || is.na(sd)) "" else paste0(fmt_num(mean, 3), " (", fmt_num(sd, 3), ")")
}

ch3_tbl_pupil_descriptives <- function(df) {
  gate <- df$n_subjects[!is.na(df$gate) & df$gate == "subject_task_ge_20"]
  if (length(gate) != 1L || is.na(gate)) {
    stop("T9 is missing the subject_task_ge_20 gate count", call. = FALSE)
  }
  measures <- list(
    list(block_mean = "raw_means", block_pair = "paired_high_minus_low", outcome = "tepr_raw",
         label = "TEPR (B1 baseline)", mean_col = "mean", sd_col = "sd"),
    list(block_mean = "raw_means", block_pair = "paired_high_minus_low", outcome = "auc_b0",
         label = "Mean TEPR (pre-squeeze baseline)", mean_col = "mean", sd_col = "sd"),
    list(block_mean = "grip_means", block_pair = "grip_paired", outcome = NA_character_,
         label = "Grip-period pupil", mean_col = "mean_grip", sd_col = "sd_grip")
  )
  rows <- list()
  for (spec in measures) {
    for (task in c("ADT", "VDT")) {
      means <- df[df$block == spec$block_mean & df$task == task, , drop = FALSE]
      if (!is.na(spec$outcome)) means <- means[means$outcome == spec$outcome, , drop = FALSE]
      high <- means[means$effort_condition == "high", , drop = FALSE]
      low <- means[means$effort_condition == "low", , drop = FALSE]
      paired <- df[df$block == spec$block_pair & df$task == task, , drop = FALSE]
      if (!is.na(spec$outcome)) paired <- paired[paired$outcome == spec$outcome, , drop = FALSE]
      if (nrow(high) != 1L || nrow(low) != 1L || nrow(paired) != 1L) {
        stop("T9 is missing a pupil effort row for ", spec$label, " ", task, call. = FALSE)
      }
      row <- data.frame(
        Measure = spec$label,
        Task = task,
        n = fmt_int(paired$n_subjects),
        high = ch3_ms_sd(high[[spec$mean_col]], high[[spec$sd_col]]),
        low = ch3_ms_sd(low[[spec$mean_col]], low[[spec$sd_col]]),
        diff = fmt_num(paired$mean_high_minus_low, 3),
        tstat = {
          df_s <- if (abs(paired$df - round(paired$df)) < 1e-8) as.character(as.integer(round(paired$df))) else fmt_num(paired$df, 2)
          paste0("t(", df_s, ") = ", fmt_num(paired$t, 2))
        },
        p = fmt_prob(paired$p),
        check.names = FALSE,
        stringsAsFactors = FALSE
      )
      names(row) <- c(
        "Measure", "Task", "n", "High M (SD)", "Low M (SD)",
        paste0("High ", .minus, " Low"), "t (df)", "p"
      )
      rows[[length(rows) + 1L]] <- row
    }
  }
  out <- do.call(rbind, rows)
  make_table(
    out,
    cols = names(out),
    col_labels = names(out),
    footnote = paste0(
      "n is the number of participants with both effort levels for that task. ",
      "The paired test drops anyone missing one level. ",
      "The final pupil sample is ", fmt_int(gate), " participants."
    )
  )
}

ch3_tbl_m2_interactions <- function(df) {
  order_qty <- c(
    "drift_hard_x_high",
    "drift_easy_x_high",
    "drift_hard_minus_easy_x_high",
    "boundary_hard_x_high",
    "boundary_easy_x_high",
    "boundary_hard_minus_easy_x_high"
  )
  labels <- c(
    "Drift, Hard \u00d7 high",
    "Drift, Easy \u00d7 high",
    "Drift, Hard \u2212 Easy",
    "Boundary, Hard \u00d7 high",
    "Boundary, Easy \u00d7 high",
    "Boundary, Hard \u2212 Easy"
  )
  if (!setequal(df$quantity, order_qty)) {
    stop("M2 interaction table is missing a term", call. = FALSE)
  }
  df <- df[match(order_qty, df$quantity), , drop = FALSE]
  p_lt <- if ("p_lt0" %in% names(df)) df$p_lt0 else df$p_negative
  out <- data.frame(
    Term = labels,
    Estimate = mapply(function(med, lo, hi) {
      paste(fmt_num(med, 3), fmt_ci(lo, hi, 3))
    }, df$median, df$q025, df$q975, USE.NAMES = FALSE),
    `P(< 0)` = vapply(p_lt, fmt_prob, character(1)),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  names(out) <- c("Term", "Estimate [95% CrI]", "P(< 0)")
  make_table(
    out,
    cols = names(out),
    col_labels = names(out),
    footnote = paste(
      "Terms are deviations of the high-effort effect from its value on Standard trials.",
      "Hard \u2212 Easy is the difference between the two deviations.",
      "Estimates are on the link scale."
    )
  )
}

ch3_tbl_glmm <- function(df, what) {
  out <- data.frame(
    Effect = ch3_map_labels(df$term, .glmm_label_map, what),
    Estimate = ch3_fmt_cells(df$estimate, function(v) fmt_num(v, 3)),
    SE = ch3_fmt_cells(df$std.error, function(v) fmt_num(v, 3)),
    stringsAsFactors = FALSE
  )
  if ("df" %in% names(df)) {
    out$df <- ch3_fmt_cells(df$df, function(v) fmt_num(v, 1))
  }
  stat_name <- if (identical(what, "T13b")) {
    "z"
  } else if (identical(what, "T13c")) {
    "t"
  } else {
    "Statistic"
  }
  out[[stat_name]] <- ch3_fmt_cells(df$statistic, function(v) fmt_num(v, 2))
  if ("p.value" %in% names(df)) {
    out$p <- ch3_fmt_cells(df$p.value, fmt_prob)
  }
  if (all(c("conf.low", "conf.high") %in% names(df))) {
    out$`95% CI` <- mapply(function(a, b) {
      if (is.na(a) || is.na(b)) "" else fmt_ci(a, b, 3)
    }, df$conf.low, df$conf.high, USE.NAMES = FALSE)
  }
  footnote <- if (identical(what, "T13b")) {
    paste(
      "Binomial GLMM. Coefficients are on the logit scale. The statistic is a Wald z; lme4 does not report denominator df.",
      "The High-effort coefficient is the Standard contrast on the logit scale. Cell contrasts are in the observed-accuracy table.",
      "Random slopes for effort were singular, so the model keeps a random intercept only (Barr et al., 2013; Bates et al., 2015; Brauer & Curtin, 2018).",
      "Reference levels: Standard difficulty, low effort, auditory task (ADT)."
    )
  } else if (identical(what, "T13c")) {
    paste(
      "The outcome is the median RT in each participant x task x difficulty x effort cell, in seconds, not log RT.",
      "df and p use the Satterthwaite approximation. Cell contrasts, in milliseconds, are in the median-RT contrast table.",
      "Random slopes for effort were singular, so the model keeps a random intercept only (Barr et al., 2013; Bates et al., 2015; Brauer & Curtin, 2018).",
      "Reference levels: Standard difficulty, low effort, auditory task (ADT)."
    )
  } else {
    NULL
  }
  make_table(out, cols = names(out), col_labels = names(out), footnote = footnote)
}

ch3_tbl_reduction <- function(df) {
  out <- data.frame(
    Outcome = ifelse(df$outcome == "rt", "Median RT", "Accuracy"),
    Step = df$step,
    `Random effects` = df$formula_re,
    Singular = ifelse(df$singular %in% c(TRUE, "TRUE"), "Yes", "No"),
    slope_sd = vapply(df$slope_sd, function(v) if (is.na(v)) "" else fmt_num(v, 3), character(1)),
    intercept_sd = vapply(df$intercept_sd, function(v) fmt_num(v, 3), character(1)),
    Used = ifelse(df$used %in% c(TRUE, "TRUE"), "Yes", "No"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  names(out)[names(out) == "slope_sd"] <- "Slope SD"
  names(out)[names(out) == "intercept_sd"] <- "Intercept SD"
  make_table(
    out, cols = names(out), col_labels = names(out),
    footnote = "Singular random slopes were dropped in the order in Barr et al. (2013), Bates et al. (2015), and Brauer and Curtin (2018). The intercept-only model is the one used."
  )
}

ch3_tbl_acc_contrasts <- function(df) {
  out <- data.frame(
    Difficulty = df$difficulty,
    pp = ch3_fmt_cells(df$pp, function(v) fmt_num(v, 2)),
    ci_pp = mapply(function(a, b) fmt_ci(a, b, 2), df$pp_lo, df$pp_hi, USE.NAMES = FALSE),
    or = ch3_fmt_cells(df$or, function(v) fmt_num(v, 2)),
    ci_or = mapply(function(a, b) fmt_ci(a, b, 2), df$or_lo, df$or_hi, USE.NAMES = FALSE),
    z = ch3_fmt_cells(df$z, function(v) fmt_num(v, 2)),
    p = ch3_fmt_cells(df$p, fmt_prob),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  names(out) <- c(
    "Difficulty", paste0("High ", .minus, " low (pp)"), "95% CI (pp)",
    "Odds ratio", "95% CI (OR)", "z", "p"
  )
  make_table(
    out, cols = names(out), col_labels = names(out),
    footnote = "High minus low, averaged over task with equal weights. Percentage points are 100 times the probability difference. The odds ratio, z, and p are the logit-scale contrast. df is asymptotic."
  )
}

ch3_tbl_rt_contrasts <- function(df) {
  out <- data.frame(
    Difficulty = df$difficulty,
    ms = ch3_fmt_cells(df$ms, function(v) fmt_num(v, 1)),
    ci = mapply(function(a, b) fmt_ci(a, b, 1), df$ms_lo, df$ms_hi, USE.NAMES = FALSE),
    t = ch3_fmt_cells(df$t, function(v) fmt_num(v, 2)),
    df = ch3_fmt_cells(df$df, function(v) fmt_num(v, 1)),
    p = ch3_fmt_cells(df$p, fmt_prob),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  names(out) <- c(
    "Difficulty", paste0("High ", .minus, " low (ms)"), "95% CI (ms)", "t", "df", "p"
  )
  make_table(
    out, cols = names(out), col_labels = names(out),
    footnote = "High minus low, in milliseconds, averaged over task with equal weights. df and p use the Satterthwaite approximation."
  )
}

.assoc_predictor_map <- c(
  LC_CNR_max = "LC contrast-to-noise (max)",
  LC_Composite_v2 = "LC composite",
  LC_fICVF = "LC neurite density (fICVF)",
  LC_fISO = "LC free-water fraction (fISO)",
  PC1_v2 = "LC principal component 1",
  boston_naming = "Boston Naming",
  sils = "Shipley vocabulary (SILS)",
  tmt_a = "Trail Making A",
  tmt_b_minus_a = "TMT B \u2212 A",
  emq = "EMQ-13",
  gds = "GDS",
  gad = "GAD-7",
  edu = "education",
  moca = "MoCA-telephone, score /22"
)

.assoc_outcome_map <- c(
  rt_mean = "mean RT",
  rt_diff_abs = "|RT effort difference|",
  grip_sd = "grip force variability",
  tepr_mean = "mean TEPR",
  pf_slope = "psychometric slope",
  a_mean = "subject-level boundary (M4 random intercept)",
  v_mean = "subject-level drift (M4 random intercept)",
  z_mean = "subject-level starting point (M4 random intercept)",
  accuracy = "mean accuracy",
  accuracy_diff_abs = "|accuracy difference|",
  dprime_mean = "d\u2032 (descriptive)",
  dprime_variability = "d\u2032 (descriptive)",
  dprime_var = "d\u2032 (descriptive)"
)

.ddm_outcomes <- c("a_mean", "v_mean", "z_mean")

ch3_assoc_table <- function(df, family_name) {
  if (!nrow(df)) stop(family_name, " has no rows", call. = FALSE)
  df$p_fdr <- stats::p.adjust(df$p, method = "BH")
  out <- data.frame(
    Predictor = ch3_map_labels(df$predictor, .assoc_predictor_map, family_name),
    Outcome = ch3_map_labels(df$outcome, .assoc_outcome_map, family_name),
    r = ch3_fmt_cells(df$r, function(v) paste0("r = ", .drop_lead0(fmt_num(v, 2)))),
    p = ch3_fmt_cells(df$p, fmt_prob),
    `p (FDR)` = ch3_fmt_cells(df$p_fdr, fmt_prob),
    n = ch3_fmt_cells(df$n, fmt_int),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  out
}

ch3_tbl_lc <- function(df) {
  df <- df[df$analysis == "lc", , drop = FALSE]
  beh <- df[!df$outcome %in% .ddm_outcomes, , drop = FALSE]
  ddm <- df[df$outcome %in% .ddm_outcomes, , drop = FALSE]
  out <- rbind(
    ch3_assoc_table(beh, "LC x behavioral"),
    ch3_assoc_table(ddm, "LC x DDM")
  )
  make_table(
    out, cols = names(out), col_labels = names(out),
    footnote = paste0(
      "Benjamini-Hochberg FDR is computed within family. ",
      "LC x behavioral outcomes: ", nrow(beh), " tests. ",
      "LC x DDM parameters: ", nrow(ddm), " tests. ",
      "d\u2032 rows are descriptive. The LC table has no accuracy column, so they were not replaced."
    )
  )
}

ch3_tbl_neuropsych <- function(df) {
  df <- df[df$analysis == "neuropsych", , drop = FALSE]
  beh <- df[!df$outcome %in% .ddm_outcomes, , drop = FALSE]
  ddm <- df[df$outcome %in% .ddm_outcomes, , drop = FALSE]
  out <- rbind(
    ch3_assoc_table(beh, "neuropsych x behavioral"),
    ch3_assoc_table(ddm, "neuropsych x DDM")
  )
  make_table(
    out, cols = names(out), col_labels = names(out),
    footnote = paste0(
      "Benjamini-Hochberg FDR is computed within family. ",
      "Neuropsych x behavioral outcomes: ", nrow(beh), " tests. ",
      "Neuropsych x DDM parameters: ", nrow(ddm), " tests. ",
      "d\u2032 (descriptive) is the SD of d\u2032 across grip conditions. ",
      "No SD of accuracy across conditions is in the source table."
    )
  )
}

ch3_tbl_baseline <- function() {
  cont_path <- "output/neuropsych_demographics/extended_baseline_continuous.csv"
  cat_path <- "output/neuropsych_demographics/extended_baseline_categorical.csv"
  if (!file.exists(cont_path) || !file.exists(cat_path)) {
    stop("July S9 baseline files are missing", call. = FALSE)
  }
  cont <- utils::read.csv(cont_path, check.names = FALSE, stringsAsFactors = FALSE)
  cat <- utils::read.csv(cat_path, check.names = FALSE, stringsAsFactors = FALSE)
  range <- gsub("(^|–)-", paste0("\\1", .minus), cont$Range, perl = TRUE)
  cont_out <- data.frame(
    Measure = cont$Measure,
    n = ch3_fmt_cells(cont$n, fmt_int),
    `M (SD) or n (%)` = cont[["M (SD)"]],
    Range = range,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  cat_out <- data.frame(
    Measure = cat$Characteristic,
    n = "",
    `M (SD) or n (%)` = cat$Value,
    Range = "",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  out <- rbind(cont_out, cat_out)
  make_table(
    out, cols = names(out), col_labels = names(out),
    footnote = paste(
      "Values are from output/neuropsych_demographics/extended_baseline_continuous.csv",
      "and extended_baseline_categorical.csv, the July S9 source.",
      "T14 stored the means but dropped the ranges."
    )
  )
}

ch3_tbl_temporal <- function(df) {
  model <- as.character(df$model)
  # The fatigue posterior file has no model column. Those rows are the within-run model.
  model[is.na(model) | !nzchar(model)] <- "within_run"
  labels <- c(
    M_hist = "Choice history",
    M_wsls = "Win-stay/lose-shift",
    within_run = "Within-run trend"
  )
  unknown <- setdiff(unique(model), names(labels))
  if (length(unknown)) {
    stop("T15 has an unlabeled model code: ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  out <- data.frame(
    Model = unname(labels[model]),
    Parameter = ch3_map_labels(df$parameter, .temporal_label_map, "T15"),
    Estimate = ch3_fmt_cells(df$median, function(v) fmt_num(v, 3)),
    SD = ch3_fmt_cells(df$sd, function(v) fmt_num(v, 3)),
    p_pos = ch3_fmt_cells(df$p_gt_0, fmt_prob),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(
    out,
    cols = names(out),
    col_labels = c("Model", "Parameter", "Estimate", "SD", "P(\u03b2 > 0)"),
    footnote = "Fit on the pre-revision model structure. The within-run rows come from the fatigue-trajectory file, which has no model column. P(\u03b2 > 0) is the posterior probability that the coefficient is positive."
  )
}

if (exists("iv", inherits = TRUE)) {
  design <- load_ch3_design()
}
