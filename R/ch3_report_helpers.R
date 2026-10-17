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

if (exists("iv", inherits = TRUE)) {
  design <- load_ch3_design()
}
