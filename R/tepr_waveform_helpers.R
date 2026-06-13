# Helpers for TEPR subject-level waveform extraction and plotting.

#' Interpolate a single trial onto the analysis grid without extrapolation.
interpolate_trial_to_grid <- function(t, y, time_grid) {
  ok <- is.finite(t) & is.finite(y)
  t <- t[ok]
  y <- y[ok]
  if (length(t) < 2L) {
    return(tibble::tibble(t_rel = numeric(0), mean_pupil_full = numeric(0)))
  }
  ord <- order(t)
  t <- t[ord]
  y <- y[ord]
  if (anyDuplicated(t)) {
    dd <- stats::aggregate(y, by = list(t = t), FUN = mean, na.rm = TRUE)
    t <- dd$t
    y <- dd$y
  }
  grid <- time_grid[time_grid >= min(t) & time_grid <= max(t)]
  if (length(grid) < 2L) {
    return(tibble::tibble(t_rel = numeric(0), mean_pupil_full = numeric(0)))
  }
  y_interp <- stats::approx(t, y, xout = grid, method = "linear", rule = 1)$y
  keep <- is.finite(y_interp)
  tibble::tibble(
    t_rel = grid[keep],
    mean_pupil_full = y_interp[keep]
  )
}

#' Winsorize subject-level means within each task x time sample.
winsorize_subject_waveforms <- function(df,
                                        value_col = "mean_pupil_full",
                                        probs = c(0.01, 0.99),
                                        abs_cap = 2) {
  df %>%
    dplyr::group_by(task, t_rel) %>%
    dplyr::mutate(
      .lo = stats::quantile(.data[[value_col]], probs[1], na.rm = TRUE),
      .hi = stats::quantile(.data[[value_col]], probs[2], na.rm = TRUE),
      "{value_col}" := pmax(pmin(.data[[value_col]], .hi), .lo)
    ) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      "{value_col}" := pmax(pmin(.data[[value_col]], abs_cap), -abs_cap)
    ) %>%
    dplyr::select(-.lo, -.hi)
}

#' Collapse to one row per subject x task x condition x time.
collapse_subject_condition_time <- function(df,
                                          value_col = "mean_pupil_full",
                                          out_col = "mean_pupil_isolated") {
  subject_col <- intersect(c("subject_id", "sub"), names(df))[1]
  if (is.na(subject_col)) {
    rlang::abort("Expected subject_id or sub column.")
  }
  df %>%
    dplyr::mutate(
      subject_id = as.character(.data[[subject_col]]),
      t_rel = round(.data$t_rel * 50) / 50
    ) %>%
    dplyr::group_by(subject_id, task, condition, t_rel) %>%
    dplyr::summarise(
      mean_pupil_isolated = mean(.data[[value_col]], na.rm = TRUE),
      .groups = "drop"
    ) %>%
    {if (out_col != "mean_pupil_isolated") dplyr::rename(., !!out_col := mean_pupil_isolated) else .}
}

#' LCYA-style summary: mean and SE across subjects at each time sample.
aggregate_condition_time_means <- function(subject_df, value_col = "mean_pupil_isolated") {
  subject_df %>%
    dplyr::group_by(task, condition, t_rel) %>%
    dplyr::summarise(
      n_subjects = sum(is.finite(.data[[value_col]])),
      se_pupil_isolated = stats::sd(.data[[value_col]], na.rm = TRUE) / sqrt(n_subjects),
      mean_pupil_isolated = mean(.data[[value_col]], na.rm = TRUE),
      .groups = "drop"
    )
}

#' Subject-level squeeze anchor so each subject x condition trace is 0 at t = 0.
normalize_subject_tepr <- function(subject_df,
                                   value_col = "mean_pupil_isolated") {
  squeeze_at_zero <- function(x, t) {
    idx <- which(abs(t) < 1e-8)
    if (length(idx)) x[idx[1]] else x[which.min(abs(t))]
  }

  subject_df %>%
    dplyr::group_by(subject_id, task, condition) %>%
    dplyr::mutate(
      squeeze_val = squeeze_at_zero(.data[[value_col]], t_rel),
      "{value_col}" := .data[[value_col]] - squeeze_val
    ) %>%
    dplyr::ungroup() %>%
    dplyr::select(-squeeze_val)
}

#' Collapse pre-squeeze condition means to a single shared trajectory for display.
overlap_pre_squeeze_conditions <- function(condition_df,
                                           value_col = "mean_pupil_isolated",
                                           se_col = "se_pupil_isolated") {
  condition_df %>%
    dplyr::group_by(task, t_rel) %>%
    dplyr::mutate(
      "{value_col}" := if (dplyr::first(t_rel) < 0) {
        mean(.data[[value_col]], na.rm = TRUE)
      } else {
        .data[[value_col]]
      },
      "{se_col}" := if (dplyr::first(t_rel) < 0) {
        mean(.data[[se_col]], na.rm = TRUE)
      } else {
        .data[[se_col]]
      }
    ) %>%
    dplyr::ungroup()
}

#' Display normalization on already-aggregated condition means (legacy fallback).
finalize_tepr_display <- function(condition_df,
                                  value_col = "mean_pupil_isolated",
                                  b0_win = c(-0.5, 0)) {
  squeeze_at_zero <- function(x, t) {
    idx <- which(abs(t) < 1e-8)
    if (length(idx)) x[idx[1]] else x[which.min(abs(t))]
  }

  condition_df %>%
    dplyr::group_by(task, condition) %>%
    dplyr::mutate(
      squeeze_level = squeeze_at_zero(.data[[value_col]], t_rel),
      "{value_col}" := .data[[value_col]] - squeeze_level
    ) %>%
    dplyr::ungroup() %>%
    overlap_pre_squeeze_conditions(value_col = value_col)
}

#' Prepare plotting data: cleaned subject rows + display-normalized condition-time means.
prepare_tepr_plot_data <- function(df,
                                   value_col = "mean_pupil_full",
                                   winsorize = TRUE) {
  out_col <- "mean_pupil_isolated"
  cleaned <- df
  if (winsorize) {
    cleaned <- winsorize_subject_waveforms(cleaned, value_col = value_col)
  }
  subject_df <- collapse_subject_condition_time(
    cleaned,
    value_col = value_col,
    out_col = out_col
  )
  subject_df <- normalize_subject_tepr(subject_df, value_col = out_col)
  condition_df <- aggregate_condition_time_means(subject_df, value_col = out_col) %>%
    overlap_pre_squeeze_conditions(value_col = out_col)
  list(subject = subject_df, condition = condition_df)
}

#' Display grid for GAM plotting (~200 time samples by default).
tepr_display_time_grid <- function(x_range = c(-0.5, 7.7), n_timepoints = 200L) {
  grid <- seq(x_range[1], x_range[2], length.out = n_timepoints)
  if (x_range[1] < 0 && x_range[2] > 0) {
    grid[which.min(abs(grid))] <- 0
  }
  sort(unique(grid))
}

#' Bin subject-level traces onto a coarser grid for smoother GAM fits.
downsample_subject_condition_time <- function(subject_df,
                                              grid,
                                              value_col = "mean_pupil_isolated") {
  if (length(grid) < 2L) {
    return(subject_df)
  }
  half_step <- diff(grid[1:2]) / 2
  breaks <- c(
    grid[1] - half_step,
    (grid[-length(grid)] + grid[-1]) / 2,
    grid[length(grid)] + half_step
  )

  subject_df %>%
    dplyr::filter(is.finite(.data$t_rel), is.finite(.data[[value_col]])) %>%
    dplyr::mutate(.bin = findInterval(.data$t_rel, breaks, all.inside = TRUE)) %>%
    dplyr::filter(.bin >= 1L, .bin <= length(grid)) %>%
    dplyr::mutate(t_rel = grid[.bin]) %>%
    dplyr::group_by(.data$subject_id, .data$task, .data$condition, .data$t_rel) %>%
    dplyr::summarise(
      "{value_col}" := mean(.data[[value_col]], na.rm = TRUE),
      .groups = "drop"
    )
}

#' Coarser condition-time means for GAM display (default ~200 samples).
prepare_tepr_gam_plot_data <- function(plot_prep,
                                       x_range = c(-0.5, 7.7),
                                       n_timepoints = 200L,
                                       value_col = "mean_pupil_isolated") {
  grid <- tepr_display_time_grid(x_range = x_range, n_timepoints = n_timepoints)
  subject_df <- downsample_subject_condition_time(
    plot_prep$subject,
    grid = grid,
    value_col = value_col
  )
  subject_df <- normalize_subject_tepr(subject_df, value_col = value_col)
  aggregate_condition_time_means(subject_df, value_col = value_col) %>%
    overlap_pre_squeeze_conditions(value_col = value_col)
}

#' Fit GAM display curves and re-anchor each smooth to pass through zero at t = 0.
fit_tepr_gam_curves <- function(condition_df,
                                value_col = "mean_pupil_isolated",
                                gam_k = 10L,
                                n_eval = 300L,
                                x_range = c(-0.5, 7.7)) {
  if (!requireNamespace("mgcv", quietly = TRUE)) {
    rlang::abort("Package 'mgcv' is required for TEPR GAM display curves.")
  }

  eval_grid <- seq(x_range[1], x_range[2], length.out = n_eval)
  if (x_range[1] < 0 && x_range[2] > 0) {
    eval_grid[which.min(abs(eval_grid))] <- 0
  }

  condition_df %>%
    dplyr::group_by(.data$task, .data$condition) %>%
    dplyr::group_modify(function(dat, key) {
      dat <- dat[is.finite(dat$t_rel) & is.finite(dat[[value_col]]), , drop = FALSE]
      if (nrow(dat) < 4L) {
        return(tibble::tibble(
          t_rel = numeric(0),
          fit = numeric(0),
          se = numeric(0)
        ))
      }

      fit_obj <- mgcv::gam(
        stats::as.formula(sprintf("%s ~ s(t_rel, k = %d)", value_col, gam_k)),
        data = dat,
        method = "REML"
      )
      nd <- tibble::tibble(t_rel = eval_grid)
      pred <- stats::predict(fit_obj, newdata = nd, se.fit = TRUE)
      squeeze_level <- as.numeric(
        stats::predict(fit_obj, newdata = tibble::tibble(t_rel = 0))
      )

      tibble::tibble(
        t_rel = eval_grid,
        fit = as.numeric(pred$fit) - squeeze_level,
        se = as.numeric(pred$se.fit)
      )
    }) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      fit_lo = .data$fit - 1.96 * .data$se,
      fit_hi = .data$fit + 1.96 * .data$se
    )
}

#' Y-axis limits from squeeze-anchored GAM curves.
tepr_gam_curves_ylimits <- function(gam_curves,
                                    x_range = c(-0.5, 7.65),
                                    padding = c(0.08, 0.12)) {
  in_range <- gam_curves$t_rel >= x_range[1] & gam_curves$t_rel <= x_range[2]
  y_lower <- stats::quantile(gam_curves$fit_lo[in_range], 0.01, na.rm = TRUE)
  y_upper <- stats::quantile(gam_curves$fit_hi[in_range], 0.99, na.rm = TRUE)
  if (!all(is.finite(c(y_lower, y_upper))) || y_upper <= y_lower) {
    return(c(-0.5, 1.5))
  }
  span <- y_upper - y_lower
  c(y_lower - span * padding[1], y_upper + span * padding[2])
}

#' Y-axis limits from pointwise subject SEM ribbons.
tepr_plot_ylimits <- function(condition_df,
                                x_range = c(-0.5, 7.65),
                                value_col = "mean_pupil_isolated",
                                se_col = "se_pupil_isolated",
                                padding = c(0.08, 0.12)) {
  in_range <- condition_df$t_rel >= x_range[1] & condition_df$t_rel <= x_range[2]
  y_lo <- condition_df[[value_col]] - 1.96 * condition_df[[se_col]]
  y_hi <- condition_df[[value_col]] + 1.96 * condition_df[[se_col]]
  y_lower <- stats::quantile(y_lo[in_range], 0.01, na.rm = TRUE)
  y_upper <- stats::quantile(y_hi[in_range], 0.99, na.rm = TRUE)
  if (!all(is.finite(c(y_lower, y_upper))) || y_upper <= y_lower) {
    return(c(-0.5, 1.5))
  }
  span <- y_upper - y_lower
  c(y_lower - span * padding[1], y_upper + span * padding[2])
}
