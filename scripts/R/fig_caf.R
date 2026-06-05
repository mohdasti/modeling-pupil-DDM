suppressPackageStartupMessages({library(tidyverse); library(here); library(purrr)})
source(here::here("R", "colors_manuscript.R"))
source(here::here("R", "fig_save_utils.R"))

# Try multiple possible locations
caf_file <- if (file.exists("output/ppc/metrics/consolidated_for_chatgpt/04_all_caf_empirical.csv")) {
  "output/ppc/metrics/consolidated_for_chatgpt/04_all_caf_empirical.csv"
} else if (file.exists("output/publish/04_all_caf_empirical.csv")) {
  "output/publish/04_all_caf_empirical.csv"
} else {
  stop("CAF file not found. Checked: output/ppc/metrics/consolidated_for_chatgpt/04_all_caf_empirical.csv and output/publish/04_all_caf_empirical.csv")
}

caf <- read_csv(caf_file, show_col_types=FALSE)

# Filter to primary model if model column exists
if ("model" %in% names(caf)) {
  primary_models <- c("fit_primary_vza", "Model10_Param_v_bs", "v_z_a")
  model_match <- caf$model %in% primary_models | grepl("primary|v_z_a|Model10", caf$model, ignore.case=TRUE)
  if (any(model_match)) {
    caf <- caf |> filter(model_match)
    cat("Filtered to primary model. Rows:", nrow(caf), "\n")
  } else {
    # Take most common model
    caf <- caf |> filter(model == names(sort(table(caf$model), decreasing=TRUE))[1])
    cat("Using model:", unique(caf$model), ". Rows:", nrow(caf), "\n")
  }
}

# Check required columns
required_cols <- c("task","effort_condition","difficulty_level")
if (!all(required_cols %in% names(caf))) {
  stop("Missing required columns. Found: ", paste(names(caf), collapse=", "))
}

# Check for bin column - might be "bin" or "bin_rt_mid" or similar
has_bin <- "bin" %in% names(caf) || "bin_rt_mid" %in% names(caf) || any(grepl("bin", names(caf), ignore.case=TRUE))
has_acc_emp <- "acc_emp" %in% names(caf) || "emp_caf" %in% names(caf) || any(grepl("emp.*acc|emp.*caf", names(caf), ignore.case=TRUE))

if (!has_bin || !has_acc_emp) {
  stop("Cannot find bin or accuracy columns. Found: ", paste(names(caf), collapse=", "))
}

# Standardize column names
if ("emp_caf" %in% names(caf)) {
  caf <- caf |> rename(acc_emp = emp_caf)
}
if ("bin" %in% names(caf) && !"bin_rt_mid" %in% names(caf)) {
  # If we only have bin numbers, we'll need to compute RT midpoints from data
  # For now, use bin as bin_rt_mid (will need to be converted to RT scale)
  caf <- caf |> rename(bin_rt_mid = bin)
}

# Check for predicted values
has_pred <- any(grepl("pred|sim", names(caf), ignore.case=TRUE))

# If bin_rt_mid holds bin indices (not seconds), compute RT midpoints from trial data
needs_rt_mid <- !"bin_rt_mid" %in% names(caf) ||
  all(grepl("^[0-9]+$", as.character(caf$bin_rt_mid)), na.rm = TRUE)

if (needs_rt_mid) {
  if ("bin" %in% names(caf) && !"bin_rt_mid" %in% names(caf)) {
    caf <- caf |> rename(bin_rt_mid = bin)
  }

  data_candidates <- c(
    "data/ddm_ready_data_unthresholded.csv",
    "data/analysis_ready/bap_ddm_ready.csv"
  )
  data_file <- data_candidates[file.exists(data_candidates)][1]

  if (!is.na(data_file)) {
    dd <- read_csv(data_file, show_col_types = FALSE) |>
      mutate(
        task = case_when(
          task %in% c("ADT", "aud") ~ "ADT",
          task %in% c("VDT", "vis") ~ "VDT",
          TRUE ~ as.character(task)
        ),
        effort_condition = case_when(
          effort_condition %in% c("High", "High_MVC", "High_40_MVC") ~ "High",
          effort_condition %in% c("Low", "Low_5_MVC") ~ "Low",
          TRUE ~ as.character(effort_condition)
        ),
        difficulty_level = factor(difficulty_level, levels = c("Standard", "Easy", "Hard"))
      ) |>
      filter(!is.na(rt), rt > 0, rt < 10,
             task %in% c("ADT", "VDT"),
             effort_condition %in% c("Low", "High"),
             !is.na(difficulty_level))

    caf_with_rt <- caf |>
      mutate(
        task = factor(task, levels = c("ADT", "VDT")),
        effort_condition = case_when(
          effort_condition %in% c("High_MVC", "High_40_MVC", "High") ~ "High",
          effort_condition %in% c("Low_5_MVC", "Low") ~ "Low",
          TRUE ~ as.character(effort_condition)
        ) |> factor(levels = c("Low", "High")),
        difficulty_level = factor(difficulty_level, levels = c("Standard", "Easy", "Hard")),
        bin_num = as.numeric(bin_rt_mid)
      )

    rt_bins <- purrr::pmap_dfr(
      caf_with_rt |> distinct(task, effort_condition, difficulty_level),
      function(task, effort_condition, difficulty_level) {
        n_bins <- max(
          caf_with_rt$bin_num[
            caf_with_rt$task == task &
              caf_with_rt$effort_condition == effort_condition &
              caf_with_rt$difficulty_level == difficulty_level
          ],
          na.rm = TRUE
        )
        if (!is.finite(n_bins) || n_bins < 1) return(NULL)
        dd_sub <- dd |>
          filter(.data$task == .env$task,
                 .data$effort_condition == .env$effort_condition,
                 .data$difficulty_level == .env$difficulty_level)
        if (nrow(dd_sub) == 0) return(NULL)
        rt_q <- quantile(dd_sub$rt, probs = seq(0, 1, length.out = n_bins + 1), na.rm = TRUE)
        tibble(
          task = task, effort_condition = effort_condition,
          difficulty_level = difficulty_level,
          bin = seq_len(n_bins),
          bin_rt_mid = (rt_q[-length(rt_q)] + rt_q[-1]) / 2
        )
      }
    )

    if (nrow(rt_bins) > 0) {
      caf <- caf_with_rt |>
        left_join(rt_bins, by = c("task", "effort_condition", "difficulty_level", "bin_num" = "bin")) |>
        mutate(bin_rt_mid = coalesce(bin_rt_mid.y, bin_rt_mid.x)) |>
        select(-any_of(c("bin_rt_mid.x", "bin_rt_mid.y", "bin_num")))
    } else {
      caf <- caf_with_rt |> select(-bin_num)
      message("CAF: could not map bins to RT midpoints; using bin index on x-axis.")
    }
  }
}

# Prepare data
caf <- caf |>
  mutate(
    task = factor(task),
    # Rename effort conditions
    effort_condition = case_when(
      effort_condition == "High_MVC" ~ "High",
      effort_condition == "Low_5_MVC" ~ "Low",
      TRUE ~ as.character(effort_condition)
    ) |>
      factor(levels=c("Low","High")),
    # Reorder difficulty: Standard, Easy, Hard
    difficulty_level = factor(difficulty_level, levels=c("Standard","Easy","Hard"))
  ) |>
  filter(!is.na(acc_emp), is.finite(acc_emp))

# Check for predicted columns
pred_cols <- names(caf)[grepl("pred|sim", names(caf), ignore.case=TRUE)]
has_pred_mean <- any(grepl("mean|avg", pred_cols, ignore.case=TRUE))
has_pred_ci <- any(grepl("lo|hi|lower|upper|ci", pred_cols, ignore.case=TRUE))

# Create plot
if (has_pred_mean && has_pred_ci) {
  # Has predicted values with CI
  pred_mean_col <- pred_cols[grepl("mean|avg", pred_cols, ignore.case=TRUE)][1]
  pred_lo_col <- pred_cols[grepl("lo|lower", pred_cols, ignore.case=TRUE)][1]
  pred_hi_col <- pred_cols[grepl("hi|upper", pred_cols, ignore.case=TRUE)][1]
  
  plt <- caf |>
    ggplot(aes(x=bin_rt_mid)) +
    geom_ribbon(aes_string(ymin=pred_lo_col, ymax=pred_hi_col), alpha=0.15, na.rm=TRUE, fill=unname(stat_colors["predicted"])) +
    geom_line(aes_string(y=pred_mean_col), na.rm=TRUE, color=unname(stat_colors["predicted"]), linewidth=0.8) +
    geom_point(aes(y=acc_emp), size=1.6, color=unname(stat_colors["empirical"])) +
    facet_grid(task + effort_condition ~ difficulty_level) +
    labs(
      x="RT bin midpoint (s)", 
      y="Accuracy",
      title="Conditional Accuracy Function: Accuracy by RT Bin",
      subtitle="Empirical (points) vs Predicted (line + ribbon)"
    ) +
    scale_y_continuous(limits=c(0, 1)) +
    theme_minimal(base_size=11) +
    theme(
      legend.position="none",
      plot.title = element_text(size=12, face="bold", hjust=0.5),
      plot.subtitle = element_text(size=10, color="gray50", hjust=0.5),
      strip.text = element_text(face="bold")
    )
} else {
  # Only empirical data
  plt <- caf |>
    ggplot(aes(x=bin_rt_mid, y=acc_emp, color=effort_condition, group=effort_condition)) +
    geom_point(size=1.6) +
    geom_path(linewidth=0.7, alpha=0.6) +
    scale_color_manual(values=effort_colors, guide="none") +
    facet_grid(task + effort_condition ~ difficulty_level) +
    labs(
      x="RT bin midpoint (s)", 
      y="Accuracy",
      title="Conditional Accuracy Function: Accuracy by RT Bin",
      subtitle="Empirical accuracy (speed-accuracy tradeoff)"
    ) +
    scale_y_continuous(limits=c(0, 1)) +
    theme_minimal(base_size=11) +
    theme(
      plot.title = element_text(size=12, face="bold", hjust=0.5),
      plot.subtitle = element_text(size=10, color="gray50", hjust=0.5),
      strip.text = element_text(face="bold")
    )
}

save_manuscript_fig(plt, "fig_caf", 9, 6.5)

