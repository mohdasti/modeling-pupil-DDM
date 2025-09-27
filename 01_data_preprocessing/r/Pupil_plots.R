# === BAP EVENT-RELATED PUPILLOMETRY ANALYSIS - CORRECTED FOR 8-PHASE PARADIGM ===
# Dual baseline approach for BAP force manipulation study

library(dplyr)
library(ggplot2)
library(tidyr)
library(readr)
library(purrr)
library(gridExtra)
library(viridis)
library(stringr)
library(grid)
library(cowplot)

# Set paths
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"

cat("=== BAP EVENT-RELATED PUPILLOMETRY ANALYSIS - CORRECTED FOR 8-PHASE PARADIGM ===\n\n")

# === MAIN ANALYSIS FUNCTION - CORRECTED ===
analyze_bap_pupil_timecourse <- function(session_file, baseline_method = "both") {
    
    cat(sprintf("Processing: %s\n", basename(session_file)))
    
    # Extract subject and task from filename
    filename <- basename(session_file)
    subject <- str_extract(filename, "BAP\\d+")
    task <- str_extract(filename, "(ADT|VDT)")
    
    if(is.na(subject) || is.na(task)) {
        cat("Could not extract subject/task from filename\n")
        return(NULL)
    }
    
    # Load data with error handling
    tryCatch({
        data <- read_csv(session_file, show_col_types = FALSE)
    }, error = function(e) {
        cat("Error loading data:", e$message, "\n")
        return(NULL)
    })
    
    if(nrow(data) == 0) {
        cat("No data in file\n")
        return(NULL)
    }
    
    # === DATA PREPARATION - CORRECTED FOR 8 PHASES ===
    cat(sprintf("  Raw data: %d rows\n", nrow(data)))
    
    # Filter for trials with behavioral data and valid pupil data
    analysis_data <- data %>%
        filter(
            has_behavioral_data == TRUE,
            !is.na(pupil),
            !is.na(time),
            !is.na(trial_label),
            !is.na(force_condition)
        ) %>%
        mutate(
            # Create force level factor
            force_level = factor(force_condition, 
                                 levels = c("Low_Force_5pct", "High_Force_40pct"),
                                 labels = c("Low Force (5%)", "High Force (40%)")),
            
            # Create stimulus level factor (if available)
            stim_level = factor(stimLev),
            
            # CORRECTED: 8-phase structure including Pre_Stimulus_Fixation
            trial_phase = factor(trial_label, levels = c(
                "ITI_Baseline", "Squeeze", "Post_Squeeze_Blank", 
                "Pre_Stimulus_Fixation",  # ADDED: Missing 500ms phase!
                "Stimulus", "Post_Stimulus_Fixation", 
                "Response_Different", "Confidence"
            ))
        )
    
    cat(sprintf("  Analysis data: %d rows, %d trials\n", 
                nrow(analysis_data), length(unique(analysis_data$trial_index))))
    
    if(nrow(analysis_data) == 0) {
        cat("No valid analysis data\n")
        return(NULL)
    }
    
    # === APPROACH 1: SQUEEZE-LOCKED ANALYSIS ===
    squeeze_analysis <- NULL
    if(baseline_method %in% c("squeeze", "both")) {
        
        cat("  Computing squeeze-locked baseline correction...\n")
        
        # Calculate baseline from ITI_Baseline phase
        baseline_data <- analysis_data %>%
            filter(trial_phase == "ITI_Baseline") %>%
            group_by(trial_index) %>%
            summarise(
                baseline_pupil_squeeze = mean(pupil, na.rm = TRUE),
                .groups = "drop"
            )
        
        # Apply squeeze-locked baseline correction
        squeeze_analysis <- analysis_data %>%
            left_join(baseline_data, by = "trial_index") %>%
            mutate(
                # Baseline-corrected pupil size
                pupil_bc_squeeze = pupil - baseline_pupil_squeeze,
                
                # Time relative to squeeze onset (time=0 at squeeze start)
                time_rel_squeeze = time
            ) %>%
            filter(!is.na(pupil_bc_squeeze))
        
        cat(sprintf("    Squeeze-locked data: %d rows\n", nrow(squeeze_analysis)))
    }
    
    # === APPROACH 2: STIMULUS-LOCKED ANALYSIS ===
    stimulus_analysis <- NULL
    if(baseline_method %in% c("stimulus", "both")) {
        
        cat("  Computing stimulus-locked baseline correction...\n")
        
        # CORRECTED: Use Pre_Stimulus_Fixation for baseline period
        # Calculate pre-stimulus baseline using the actual Pre_Stimulus_Fixation phase
        baseline_data_stim <- analysis_data %>%
            filter(trial_phase == "Pre_Stimulus_Fixation") %>%  # CORRECTED: Use actual phase
            group_by(trial_index) %>%
            summarise(
                baseline_pupil_stimulus = mean(pupil, na.rm = TRUE),
                .groups = "drop"
            )
        
        # Find stimulus onset time for each trial
        stimulus_onsets <- analysis_data %>%
            filter(trial_phase == "Stimulus") %>%
            group_by(trial_index) %>%
            summarise(
                stimulus_onset_time = min(time, na.rm = TRUE),
                .groups = "drop"
            )
        
        # Apply stimulus-locked baseline correction
        stimulus_analysis <- analysis_data %>%
            left_join(stimulus_onsets, by = "trial_index") %>%
            left_join(baseline_data_stim, by = "trial_index") %>%
            mutate(
                # Baseline-corrected pupil size
                pupil_bc_stimulus = pupil - baseline_pupil_stimulus,
                
                # Time relative to stimulus onset
                time_rel_stimulus = time - stimulus_onset_time
            ) %>%
            filter(
                !is.na(pupil_bc_stimulus),
                # Focus on relevant time window around stimulus
                time_rel_stimulus >= -1.0 & time_rel_stimulus <= 8.0
            )
        
        cat(sprintf("    Stimulus-locked data: %d rows\n", nrow(stimulus_analysis)))
    }
    
    # === CREATE SUMMARY STATISTICS ===
    results <- list(
        subject = subject,
        task = task,
        filename = filename
    )
    
    # Squeeze-locked timecourse
    if(!is.null(squeeze_analysis)) {
        
        squeeze_timecourse <- squeeze_analysis %>%
            # Create time bins for averaging
            mutate(
                time_bin = round(time_rel_squeeze / 0.1) * 0.1  # 100ms bins
            ) %>%
            group_by(time_bin, force_level) %>%  # Simplified grouping
            summarise(
                mean_pupil = mean(pupil_bc_squeeze, na.rm = TRUE),
                se_pupil = sd(pupil_bc_squeeze, na.rm = TRUE) / sqrt(n()),
                n_samples = n(),
                .groups = "drop"
            ) %>%
            filter(n_samples >= 5)  # Require minimum samples per bin
        
        results$squeeze_timecourse <- squeeze_timecourse
    }
    
    # Stimulus-locked timecourse
    if(!is.null(stimulus_analysis)) {
        
        stimulus_timecourse <- stimulus_analysis %>%
            # Create time bins for averaging
            mutate(
                time_bin = round(time_rel_stimulus / 0.1) * 0.1  # 100ms bins
            ) %>%
            group_by(time_bin, force_level) %>%  # Simplified grouping
            summarise(
                mean_pupil = mean(pupil_bc_stimulus, na.rm = TRUE),
                se_pupil = sd(pupil_bc_stimulus, na.rm = TRUE) / sqrt(n()),
                n_samples = n(),
                .groups = "drop"
            ) %>%
            filter(n_samples >= 5)  # Require minimum samples per bin
        
        results$stimulus_timecourse <- stimulus_timecourse
    }
    
    cat(sprintf("  Analysis complete for %s %s\n", subject, task))
    return(results)
}

# === CLEAN PLOTTING FUNCTIONS - CORRECTED ===

create_squeeze_locked_plot_clean <- function(session_result) {
    
    if(is.null(session_result$squeeze_timecourse)) {
        return(NULL)
    }
    
    timecourse_data <- session_result$squeeze_timecourse
    
    # CORRECTED: Updated phase boundaries for 8-phase paradigm
    phase_boundaries <- data.frame(
        time = c(0, 3, 3.25, 3.75, 4.45, 4.7, 7.7),  # CORRECTED: Updated timings
        phase = c("Squeeze", "Post_Squeeze_Blank", "Pre_Stimulus_Fixation", 
                  "Stimulus", "Post_Stimulus_Fixation", "Response_Different", "Confidence"),
        label = c("Squeeze\nOnset", "Post\nSqueeze", "Pre-Stim\nFixation", 
                  "Stimulus\nOnset", "Post-Stim\nFixation", "Response\nPeriod", "Confidence\nRating")
    )
    
    # CLEAN VERSION: Minimal labels for grid arrangement
    p <- ggplot(timecourse_data, aes(x = time_bin, y = mean_pupil, color = force_level, group = force_level)) +
        geom_line(size = 1.2, alpha = 0.8) +
        geom_ribbon(aes(ymin = mean_pupil - se_pupil, ymax = mean_pupil + se_pupil, 
                        fill = force_level), alpha = 0.2, color = NA) +
        
        # Add phase boundaries (updated for 8 phases)
        geom_vline(data = phase_boundaries, aes(xintercept = time), 
                   linetype = "dashed", color = "gray50", alpha = 0.7) +
        
        # Force manipulation highlighting (squeeze period)
        annotate("rect", xmin = 0, xmax = 3, ymin = -Inf, ymax = Inf, 
                 alpha = 0.15, fill = "orange") +
        
        # ENHANCED: Highlight Pre_Stimulus_Fixation period
        annotate("rect", xmin = 3.25, xmax = 3.75, ymin = -Inf, ymax = Inf, 
                 alpha = 0.1, fill = "purple") +
        
        scale_color_manual(values = c("Low Force (5%)" = "#1f78b4", "High Force (40%)" = "#e31a1c")) +
        scale_fill_manual(values = c("Low Force (5%)" = "#1f78b4", "High Force (40%)" = "#e31a1c")) +
        
        # CLEAN: Only subject-task as title, no axis labels
        ggtitle(paste(session_result$subject, session_result$task)) +
        
        # CLEAN: Remove all axis titles and labels for grid
        theme_minimal() +
        theme(
            axis.title = element_blank(),        # Remove axis titles
            axis.text = element_text(size = 8),  # Smaller axis text
            plot.title = element_text(size = 10, face = "bold", hjust = 0.5),
            legend.position = "none",            # Remove individual legends
            panel.grid.minor = element_blank(),  # Clean grid
            plot.margin = margin(5, 5, 5, 5)    # Tight margins
        )
    
    return(p)
}

create_stimulus_locked_plot_clean <- function(session_result) {
    
    if(is.null(session_result$stimulus_timecourse)) {
        return(NULL)
    }
    
    timecourse_data <- session_result$stimulus_timecourse
    
    # CLEAN VERSION: Minimal labels for grid arrangement
    p <- ggplot(timecourse_data, aes(x = time_bin, y = mean_pupil, color = force_level, group = force_level)) +
        geom_line(size = 1.2, alpha = 0.8) +
        geom_ribbon(aes(ymin = mean_pupil - se_pupil, ymax = mean_pupil + se_pupil, 
                        fill = force_level), alpha = 0.2, color = NA) +
        
        # Stimulus onset
        geom_vline(xintercept = 0, linetype = "dashed", color = "red", size = 1) +
        
        # Decision period highlighting
        annotate("rect", xmin = 0, xmax = 4, ymin = -Inf, ymax = Inf, 
                 alpha = 0.15, fill = "lightblue") +
        
        # ENHANCED: Pre-stimulus fixation baseline period highlighting
        annotate("rect", xmin = -0.5, xmax = 0, ymin = -Inf, ymax = Inf, 
                 alpha = 0.1, fill = "purple") +
        
        scale_color_manual(values = c("Low Force (5%)" = "#1f78b4", "High Force (40%)" = "#e31a1c")) +
        scale_fill_manual(values = c("Low Force (5%)" = "#1f78b4", "High Force (40%)" = "#e31a1c")) +
        
        # CLEAN: Only subject-task as title, no axis labels
        ggtitle(paste(session_result$subject, session_result$task)) +
        
        # CLEAN: Remove all axis titles and labels for grid
        theme_minimal() +
        theme(
            axis.title = element_blank(),        # Remove axis titles
            axis.text = element_text(size = 8),  # Smaller axis text
            plot.title = element_text(size = 10, face = "bold", hjust = 0.5),
            legend.position = "none",            # Remove individual legends
            panel.grid.minor = element_blank(),  # Clean grid
            plot.margin = margin(5, 5, 5, 5)    # Tight margins
        )
    
    return(p)
}

# === COMPREHENSIVE PLOTTING FUNCTION - CORRECTED ===

create_comprehensive_plot_simple <- function(plot_list, plot_type = "squeeze") {
    
    if(length(plot_list) == 0) return(NULL)
    
    cat(sprintf("Creating comprehensive %s plot with %d subplots...\n", plot_type, length(plot_list)))
    
    # Create titles based on plot type - CORRECTED for 8-phase paradigm
    if(plot_type == "squeeze") {
        main_title <- "Squeeze-Locked Pupillometry: Force Manipulation Effects Across Sessions"
        subtitle_text <- "Baseline: ITI period (-3s to 0s) | Time zero: Squeeze onset | Orange: Force manipulation (5% vs 40% MVC)"
        subtitle2_text <- "8-Phase trial: ITI → Squeeze (3s) → Post-Squeeze (0.25s) → Pre-Stim-Fix (0.5s) → Stimulus (0.7s) → Post-Stim-Fix (0.25s) → Response (3s) → Confidence (3s)"  # CORRECTED
        x_label <- "Time relative to squeeze onset (seconds)"
    } else {
        main_title <- "Stimulus-Locked Pupillometry: Decision-Period Analysis Across Sessions"
        subtitle_text <- "Baseline: Pre-stimulus fixation period (0.5s) | Time zero: Stimulus onset | Blue: Decision period"  # CORRECTED
        subtitle2_text <- "Focus: Cognitive load effects during auditory/visual discrimination (post-force manipulation)"
        x_label <- "Time relative to stimulus onset (seconds)"
    }
    
    # Arrange plots in grid
    n_plots <- length(plot_list)
    n_cols <- min(4, ceiling(sqrt(n_plots)))
    n_rows <- ceiling(n_plots / n_cols)
    
    # Use cowplot for more reliable layout
    plot_grid_main <- plot_grid(plotlist = plot_list, ncol = n_cols, align = "hv")
    
    # Create shared legend
    legend_data <- data.frame(
        x = 1:2, 
        y = 1:2, 
        force = c("Low Force (5%)", "High Force (40%)")
    )
    
    legend_plot <- ggplot(legend_data, aes(x, y, color = force)) +
        geom_line(size = 1.5) +
        scale_color_manual(
            values = c("Low Force (5%)" = "#1f78b4", "High Force (40%)" = "#e31a1c"),
            name = "Handgrip Force Condition"
        ) +
        theme_void() +
        theme(
            legend.position = "bottom",
            legend.title = element_text(size = 12, face = "bold"),
            legend.text = element_text(size = 11)
        )
    
    legend_grob <- get_legend(legend_plot)
    
    # Add title and subtitle using cowplot (more reliable)
    final_plot <- ggdraw() +
        # Main plot grid
        draw_plot(plot_grid_main, x = 0.05, y = 0.15, width = 0.9, height = 0.7) +
        
        # Main title
        draw_label(
            main_title,
            x = 0.5, y = 0.98, hjust = 0.5, vjust = 1,
            size = 16, fontface = "bold"
        ) +
        
        # Subtitle line 1
        draw_label(
            subtitle_text,
            x = 0.5, y = 0.94, hjust = 0.5, vjust = 1,
            size = 11, color = "gray30"
        ) +
        
        # Subtitle line 2 - CORRECTED for 8-phase structure
        draw_label(
            subtitle2_text,
            x = 0.5, y = 0.90, hjust = 0.5, vjust = 1,
            size = 10, color = "gray50", fontface = "italic"
        ) +
        
        # Y-axis label
        draw_label(
            "Pupil Dilation (baseline corrected)",
            x = 0.02, y = 0.5, hjust = 0.5, vjust = 0.5,
            angle = 90, size = 12, fontface = "bold"
        ) +
        
        # X-axis label
        draw_label(
            x_label,
            x = 0.5, y = 0.08, hjust = 0.5, vjust = 0.5,
            size = 12, fontface = "bold"
        ) +
        
        # Legend
        draw_plot(legend_grob, x = 0.3, y = 0.01, width = 0.4, height = 0.06) +
        
        # Method info
        draw_label(
            sprintf("n = %d subject-task sessions | 8-phase paradigm | Pupillometry sampled at 250Hz | Quality threshold: >50%% valid samples per trial", 
                    length(plot_list)),  # CORRECTED: mention 8-phase paradigm
            x = 0.5, y = 0.02, hjust = 0.5, vjust = 0.5,
            size = 9, color = "gray60"
        )
    
    return(final_plot)
}

# === MAIN EXECUTION - SAME AS BEFORE ===

cat("Finding merged files...\n")

# Find all merged files
merged_files <- list.files(processed_dir, pattern = ".*_flat_merged\\.csv$", full.names = TRUE)

cat(sprintf("Found %d merged files:\n", length(merged_files)))
for(file in merged_files) {
    cat(sprintf("  %s\n", basename(file)))
}

if(length(merged_files) == 0) {
    stop("No merged files found!")
}

# === ANALYZE ALL SESSIONS ===
cat("\nStarting analysis of all sessions...\n")

all_results <- list()
squeeze_plots_clean <- list()
stimulus_plots_clean <- list()

for(file in merged_files) {
    
    # Analyze session
    result <- analyze_bap_pupil_timecourse(file, baseline_method = "both")
    
    if(!is.null(result)) {
        session_id <- paste(result$subject, result$task, sep = "_")
        all_results[[session_id]] <- result
        
        # Create CLEAN plots for grid arrangement
        squeeze_plot_clean <- create_squeeze_locked_plot_clean(result)
        stimulus_plot_clean <- create_stimulus_locked_plot_clean(result)
        
        if(!is.null(squeeze_plot_clean)) {
            squeeze_plots_clean[[session_id]] <- squeeze_plot_clean
        }
        
        if(!is.null(stimulus_plot_clean)) {
            stimulus_plots_clean[[session_id]] <- stimulus_plot_clean
        }
    }
}

cat(sprintf("\nAnalysis complete! Processed %d sessions successfully.\n", length(all_results)))

# === CREATE COMPREHENSIVE VISUALIZATIONS ===
cat("\nCreating comprehensive visualizations...\n")

# Combined squeeze-locked plot
if(length(squeeze_plots_clean) > 0) {
    
    cat("Creating comprehensive squeeze-locked plots...\n")
    
    squeeze_comprehensive <- create_comprehensive_plot_simple(squeeze_plots_clean, "squeeze")
    
    # Save comprehensive plot
    tryCatch({
        ggsave(
            file.path(processed_dir, "BAP_squeeze_locked_comprehensive.png"),
            squeeze_comprehensive,
            width = 16, height = 12, dpi = 300
        )
        cat("Comprehensive squeeze-locked plot saved successfully!\n")
    }, error = function(e) {
        cat("Error saving comprehensive plot:", e$message, "\n")
    })
}

# Combined stimulus-locked plot
if(length(stimulus_plots_clean) > 0) {
    
    cat("Creating comprehensive stimulus-locked plots...\n")
    
    stimulus_comprehensive <- create_comprehensive_plot_simple(stimulus_plots_clean, "stimulus")
    
    # Save comprehensive plot
    tryCatch({
        ggsave(
            file.path(processed_dir, "BAP_stimulus_locked_comprehensive.png"),
            stimulus_comprehensive,
            width = 16, height = 12, dpi = 300
        )
        cat("Comprehensive stimulus-locked plot saved successfully!\n")
    }, error = function(e) {
        cat("Error saving stimulus comprehensive plot:", e$message, "\n")
    })
}

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Results saved:\n")
cat("- BAP_squeeze_locked_comprehensive.png (8-phase corrected)\n")
cat("- BAP_stimulus_locked_comprehensive.png (8-phase corrected)\n")
cat("\nAll results stored in 'all_results' list\n")
cat("Individual plots available in 'squeeze_plots_clean' and 'stimulus_plots_clean' lists\n")

# Display first plot as example if available
if(length(squeeze_plots_clean) > 0) {
    cat("\nDisplaying first squeeze-locked plot:\n")
    print(squeeze_plots_clean[[1]])
}
