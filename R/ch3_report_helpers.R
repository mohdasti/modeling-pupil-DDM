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
  if (grepl("^-(0+(\\.0+)?)$", s)) {
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
  "drift_different" = "Drift on different trials",
  "drift_same" = "Drift on same trials",
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
          fmt_p(v)
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
  names(shown) <- col_labels
  kb <- knitr::kable(
    shown,
    format = "pipe",
    align = c("l", rep("r", max(0, ncol(shown) - 1)))
  )
  note <- ""
  if (!is.null(footnote) && length(footnote) == 1L && !is.na(footnote) && nzchar(footnote)) {
    note <- paste0("\n\n*Note.* ", footnote)
  }
  knitr::asis_output(paste0(as.character(kb), note, "\n"))
}

ch3_tbl_demographics <- function(df) {
  make_table(
    df,
    cols = c("Characteristic", "Full_Sample"),
    col_labels = c("Characteristic", "Full sample")
  )
}

ch3_tbl_effort_effects <- function(df) {
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
    col_labels = names(out)
  )
}

ch3_tbl_pupil_ordering <- function(df) {
  df <- df[df$tier == "main", , drop = FALSE]
  out <- data.frame(
    Model = df$model,
    Predictor = df$predictor,
    ch3_posterior_cols(df$median, df$q2.5, df$q97.5, 3),
    `Change in a` = ch3_pct_change_col(df$pct_change_median, df$pct_change_q2.5, df$pct_change_q97.5),
    `Delta ELPD` = mapply(function(d, s) {
      if (is.na(d) || is.na(s)) "" else paste0(fmt_num(d, 1), " \u00b1 ", fmt_num(s, 1))
    }, df$delta_elpd_vs_baseline, df$se_delta_elpd, USE.NAMES = FALSE),
    Trials = ch3_fmt_cells(df$n_trials, fmt_int),
    Subjects = ch3_fmt_cells(df$n_subjects, fmt_int),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_trial_counts <- function(df) {
  out <- data.frame(
    Task = df$task,
    Difficulty = df$difficulty_3,
    Effort = tools::toTitleCase(df$effort_condition),
    Trials = ch3_fmt_cells(df$n_trials, fmt_int),
    Subjects = ch3_fmt_cells(df$n_subjects, fmt_int),
    `Trials per subject` = ch3_fmt_cells(df$trials_per_subject, function(v) fmt_num(v, 1)),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_model_comparison <- function(df) {
  flagged <- df$model[nzchar(df$rhat_footnote)]
  notes <- df$rhat_footnote[nzchar(df$rhat_footnote)]
  footnote <- if (length(flagged)) paste(flagged, notes, collapse = " ") else NULL
  out <- data.frame(
    Model = df$model,
    ELPD = ch3_fmt_cells(df$elpd_loo, function(v) fmt_num(v, 1)),
    SE = ch3_fmt_cells(df$se_elpd_loo, function(v) fmt_num(v, 1)),
    `Delta ELPD vs M4` = ch3_fmt_cells(df$delta_elpd_vs_M4, function(v) fmt_num(v, 1)),
    `SE of delta` = ch3_fmt_cells(df$se_delta_elpd_vs_M4, function(v) fmt_num(v, 1)),
    `k > 0.7` = ch3_fmt_cells(df$n_k_gt_0.7, fmt_int),
    `Max R-hat` = ch3_fmt_cells(df$max_rhat, function(v) fmt_num(v, 3)),
    `Min bulk ESS` = ch3_fmt_cells(df$min_bulk_ess, fmt_int),
    Pass = ifelse(df$passes_convergence_rule, "Yes", "No"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out), footnote = footnote)
}

ch3_tbl_convergence <- function(df) {
  df <- df[df$model != "P0_r6", , drop = FALSE]
  out <- data.frame(
    Model = df$model,
    Role = df$role,
    `Max R-hat` = ch3_fmt_cells(df$max_rhat, function(v) fmt_num(v, 3)),
    `Min bulk ESS` = ch3_fmt_cells(df$min_bulk_ess, fmt_int),
    `Min tail ESS` = ch3_fmt_cells(df$min_tail_ess, fmt_int),
    Divergences = ch3_fmt_cells(df$divergences, fmt_int),
    Pass = ifelse(df$passes_convergence_rule, "Yes", "No"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_fixef <- function(df) {
  out <- data.frame(
    Parameter = ch3_map_labels(df$term, .fixef_label_map, "T4"),
    ch3_posterior_cols(df$median, df$q2.5, df$q97.5, 3),
    Direction = ch3_direction_col(df$median, df$p_lt0, df$p_gt0),
    `In ROPE` = ch3_rope_col(df$pct_in_rope),
    `R-hat` = ch3_fmt_cells(df$rhat, function(v) fmt_num(v, 3)),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_condition_cells <- function(df) {
  out <- data.frame(
    Task = df$task,
    Difficulty = df$difficulty_3,
    Effort = tools::toTitleCase(df$effort_condition),
    Parameter = ch3_map_labels(df$quantity, .quantity_map, "T3"),
    ch3_posterior_cols(df$median, df$q2.5, df$q97.5, 3),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_ppc_choice <- function(df) {
  df <- df[df$model == "M4", , drop = FALSE]
  out <- data.frame(
    Task = df$task,
    Difficulty = df$difficulty_3,
    Effort = tools::toTitleCase(df$effort_condition),
    Observed = ch3_fmt_cells(df$observed, function(v) fmt_num(v, 3)),
    Predicted = ch3_fmt_cells(df$pred_median, function(v) fmt_num(v, 3)),
    `95% PI` = mapply(function(a, b) {
      if (is.na(a) || is.na(b)) "" else fmt_ci(a, b, 3)
    }, df$pred_q2.5, df$pred_q97.5, USE.NAMES = FALSE),
    Inside = ifelse(df$inside, "Yes", "No"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_robustness <- function(df) {
  out <- data.frame(
    Model = df$model,
    Parameter = ch3_map_labels(df$term, .effort_label_map, "T6a"),
    ch3_posterior_cols(df$median, df$q2.5, df$q97.5, 3),
    `In ROPE` = ch3_rope_col(df$pct_in_rope),
    Trials = ch3_fmt_cells(df$n_trials, fmt_int),
    Subjects = ch3_fmt_cells(df$n_subjects, fmt_int),
    Pass = ifelse(df$passes_convergence_rule, "Yes", "No"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
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
  slope_out <- data.frame(
    Block = "Pupil slope",
    Model = slopes$model,
    Parameter = ch3_map_labels(slopes$term, .pupil_term_map, "T7"),
    ch3_posterior_cols(slopes$median, slopes$q2.5, slopes$q97.5, 3),
    `Change in a` = ch3_pct_change_col(
      slopes$pct_change_median, slopes$pct_change_q2.5, slopes$pct_change_q97.5
    ),
    `Delta ELPD` = mapply(function(d, s) {
      if (is.na(d) || is.na(s)) "" else paste0(fmt_num(d, 1), " \u00b1 ", fmt_num(s, 1))
    }, slopes$delta_elpd_vs_baseline, slopes$se_delta_elpd, USE.NAMES = FALSE),
    Trials = ch3_fmt_cells(slopes$n_trials, fmt_int),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  effort_out <- data.frame(
    Block = "P0 effort term",
    Model = effort$model,
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
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_pupil_descriptives <- function(df) {
  out <- data.frame(
    Gate = ifelse(is.na(df$gate), "", df$gate),
    Block = ifelse(is.na(df$block), "", df$block),
    Task = ifelse(is.na(df$task), "", df$task),
    Effort = ifelse(is.na(df$effort_condition), "", as.character(df$effort_condition)),
    Outcome = ifelse(is.na(df$outcome), "", df$outcome),
    Trials = ch3_fmt_cells(df$n_trials, fmt_int),
    Subjects = ch3_fmt_cells(df$n_subjects, fmt_int),
    Mean = ch3_fmt_cells(df$mean, function(v) fmt_num(v, 3)),
    SD = ch3_fmt_cells(df$sd, function(v) fmt_num(v, 3)),
    `High minus low` = ch3_fmt_cells(df$mean_high_minus_low, function(v) fmt_num(v, 3)),
    t = ch3_fmt_cells(df$t, function(v) fmt_num(v, 2)),
    df = ch3_fmt_cells(df$df, fmt_int),
    p = ch3_fmt_cells(df$p, fmt_p),
    r = ch3_fmt_cells(df$mean_r_fisher, function(v) paste0("r = ", .drop_lead0(fmt_num(v, 2)))),
    `r CrI` = mapply(function(a, b) {
      if (is.na(a) || is.na(b)) "" else paste0("[", .drop_lead0(fmt_num(a, 2)), ", ", .drop_lead0(fmt_num(b, 2)), "]")
    }, df$ci_lo, df$ci_hi, USE.NAMES = FALSE),
    `Grip mean` = ch3_fmt_cells(df$mean_grip, function(v) fmt_num(v, 3)),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_glmm <- function(df, what) {
  out <- data.frame(
    Effect = ch3_map_labels(df$term, .glmm_label_map, what),
    Estimate = ch3_fmt_cells(df$estimate, function(v) fmt_num(v, 3)),
    SE = ch3_fmt_cells(df$std.error, function(v) fmt_num(v, 3)),
    Statistic = ch3_fmt_cells(df$statistic, function(v) fmt_num(v, 2)),
    stringsAsFactors = FALSE
  )
  if ("p.value" %in% names(df)) {
    out$p <- ch3_fmt_cells(df$p.value, fmt_p)
  }
  if (all(c("conf.low", "conf.high") %in% names(df))) {
    out$`95% CI` <- mapply(function(a, b) {
      if (is.na(a) || is.na(b)) "" else fmt_ci(a, b, 3)
    }, df$conf.low, df$conf.high, USE.NAMES = FALSE)
  }
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_associations <- function(df, analysis_keep, what) {
  df <- df[df$analysis %in% analysis_keep, , drop = FALSE]
  if (!nrow(df)) {
    stop(what, " has no rows", call. = FALSE)
  }
  out <- data.frame(
    Predictor = df$predictor,
    Outcome = df$outcome,
    Analysis = df$analysis,
    r = ch3_fmt_cells(df$r, function(v) paste0("r = ", .drop_lead0(fmt_num(v, 2)))),
    p = ch3_fmt_cells(df$p, fmt_p),
    n = ch3_fmt_cells(df$n, fmt_int),
    stringsAsFactors = FALSE
  )
  make_table(out, cols = names(out), col_labels = names(out))
}

ch3_tbl_temporal <- function(df) {
  model <- ifelse(is.na(df$model), "", df$model)
  out <- data.frame(
    Model = model,
    Parameter = ch3_map_labels(df$parameter, .temporal_label_map, "T15"),
    Estimate = ch3_fmt_cells(df$median, function(v) fmt_num(v, 3)),
    SD = ch3_fmt_cells(df$sd, function(v) fmt_num(v, 3)),
    `p > 0` = ch3_fmt_cells(df$p_gt_0, fmt_prob),
    stringsAsFactors = FALSE
  )
  make_table(
    out,
    cols = names(out),
    col_labels = names(out),
    footnote = "Fit on the pre-revision model structure."
  )
}

if (exists("iv", inherits = TRUE)) {
  design <- load_ch3_design()
}
