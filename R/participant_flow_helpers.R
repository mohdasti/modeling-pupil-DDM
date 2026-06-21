# Participant / analytic-sample flow counts (Chapter 3 DDM manuscript).

format_flow_n <- function(x) {
  format(as.integer(x), big.mark = ",", scientific = FALSE, trim = TRUE)
}

CH3_ENROLLED_N <- 69L
CH3_POST_ENROLL_EXCLUDED <- 2L

norm_task <- function(x) {
  dplyr::case_when(
    x %in% c("ADT", "aud", "Auditory") ~ "ADT",
    x %in% c("VDT", "vis", "Visual") ~ "VDT",
    TRUE ~ NA_character_
  )
}

find_first_existing <- function(paths) {
  paths[file.exists(paths)][1]
}

#' Compute participant-flow counts from pipeline outputs (single source of truth).
summarize_ch3_participant_flow <- function(
    repo_root = ".",
    enrolled = CH3_ENROLLED_N,
    post_enroll_excluded = CH3_POST_ENROLL_EXCLUDED,
    primary_thr = 0.20,
    pupil_z_col = "pupil_metric_primary_z") {
  ddm_path <- find_first_existing(c(
    file.path(repo_root, "data", "ddm_ready_data_unthresholded.csv"),
    file.path(repo_root, "output", "rt_threshold_analysis", "ddm_ready_data_unthresholded.csv")
  ))
  pupil_path <- file.path(
    repo_root, "output", "ddm_pupil",
    sprintf("ddm_pupil_ready_thr%.2f_probe_onset_locked.csv", primary_thr)
  )

  if (is.na(ddm_path)) {
    stop("Could not find ddm_ready_data_unthresholded.csv")
  }
  if (!file.exists(pupil_path)) {
    stop("Could not find pupil-ready data: ", pupil_path)
  }

  ddm <- readr::read_csv(ddm_path, show_col_types = FALSE) %>%
    dplyr::mutate(Task = norm_task(.data$task))
  pupil <- readr::read_csv(pupil_path, show_col_types = FALSE) %>%
    dplyr::mutate(
      Task = dplyr::coalesce(
        norm_task(.data$task_std),
        norm_task(.data$task)
      )
    )

  analytic_cohort <- dplyr::n_distinct(ddm$subject_id)
  trials_collected <- nrow(ddm)
  ddm_rt <- ddm %>%
    dplyr::filter(!is.na(.data$rt), .data$rt >= primary_thr)
  trials_behavioral <- nrow(ddm_rt)
  trials_rt_excluded <- trials_collected - trials_behavioral

  beh_by_task <- ddm_rt %>%
    dplyr::group_by(.data$Task) %>%
    dplyr::summarise(
      n_sub = dplyr::n_distinct(.data$subject_id),
      n_trials = dplyr::n(),
      .groups = "drop"
    )

  if (!pupil_z_col %in% names(pupil)) {
    stop("Missing pupil column: ", pupil_z_col)
  }

  pupil_model <- pupil %>%
    dplyr::filter(!is.na(.data[[pupil_z_col]]))
  trials_pupil <- nrow(pupil_model)
  subs_pupil <- dplyr::n_distinct(pupil_model$subject_id)
  trials_pupil_excluded <- trials_behavioral - trials_pupil
  subs_pupil_excluded <- analytic_cohort - subs_pupil

  pup_by_task <- pupil_model %>%
    dplyr::group_by(.data$Task) %>%
    dplyr::summarise(
      n_sub = dplyr::n_distinct(.data$subject_id),
      n_trials = dplyr::n(),
      .groups = "drop"
    )

  task_stats <- function(task, by_task_df) {
    row <- by_task_df[by_task_df$Task == task, , drop = FALSE]
    if (!nrow(row)) {
      return(list(n_sub = NA_integer_, n_trials = NA_integer_))
    }
    list(
      n_sub = as.integer(row$n_sub[1]),
      n_trials = as.integer(row$n_trials[1])
    )
  }

  beh_adt <- task_stats("ADT", beh_by_task)
  beh_vdt <- task_stats("VDT", beh_by_task)
  pup_adt <- task_stats("ADT", pup_by_task)
  pup_vdt <- task_stats("VDT", pup_by_task)

  list(
    enrolled = as.integer(enrolled),
    post_enroll_excluded = as.integer(post_enroll_excluded),
    analytic_cohort = as.integer(analytic_cohort),
    trials_collected = as.integer(trials_collected),
    trials_rt_excluded = as.integer(trials_rt_excluded),
    trials_behavioral = as.integer(trials_behavioral),
    subs_behavioral = as.integer(analytic_cohort),
    trials_pupil_excluded = as.integer(trials_pupil_excluded),
    subs_pupil_excluded = as.integer(subs_pupil_excluded),
    trials_pupil = as.integer(trials_pupil),
    subs_pupil = as.integer(subs_pupil),
    behavioral = list(
      adt = beh_adt,
      vdt = beh_vdt
    ),
    pupil = list(
      adt = pup_adt,
      vdt = pup_vdt
    ),
    primary_thr = primary_thr
  )
}
