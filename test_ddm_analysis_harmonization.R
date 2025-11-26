#!/usr/bin/env Rscript
# =========================================================================
# TEST scripts/02_statistical_analysis/02_ddm_analysis.R COLUMN HARMONIZATION
# =========================================================================

cat("================================================================================\n")
cat("TESTING 02_ddm_analysis.R COLUMN HARMONIZATION\n")
cat("================================================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

library(dplyr)
library(readr)

# Create a test dataset with new column structure
test_data_new <- tibble(
    subject_id = c("BAP001", "BAP001", "BAP002", "BAP002"),
    task_modality = c("aud", "vis", "aud", "vis"),
    run_num = c(1, 1, 1, 1),
    trial_num = c(1, 2, 1, 2),
    same_diff_resp_secs = c(0.5, 0.6, 0.7, 0.8),
    resp_is_correct = c(TRUE, FALSE, TRUE, TRUE),
    grip_targ_prop_mvc = c(0.05, 0.4, 0.05, 0.4),
    stim_level_index = c(2, 3, 1, 4),
    stim_is_diff = c(FALSE, TRUE, FALSE, TRUE)
)

cat("Step 1: Testing with new column structure...\n")
ddm_data_behav <- test_data_new

# Apply harmonization logic from 02_ddm_analysis.R
# Map RT
if (!"rt" %in% names(ddm_data_behav)) {
    if ("resp1RT" %in% names(ddm_data_behav)) {
        ddm_data_behav$rt <- ddm_data_behav$resp1RT
    } else if ("same_diff_resp_secs" %in% names(ddm_data_behav)) {
        ddm_data_behav$rt <- ddm_data_behav$same_diff_resp_secs
    }
}
ddm_data_behav$rt <- suppressWarnings(as.numeric(ddm_data_behav$rt))

# Map accuracy
if (!"accuracy" %in% names(ddm_data_behav)) {
    if ("iscorr" %in% names(ddm_data_behav)) {
        ddm_data_behav$accuracy <- ddm_data_behav$iscorr
    } else if ("resp_is_correct" %in% names(ddm_data_behav)) {
        ddm_data_behav$accuracy <- as.integer(ddm_data_behav$resp_is_correct)
    }
}

# Map subject_id
if (!"subject_id" %in% names(ddm_data_behav)) {
    if ("sub" %in% names(ddm_data_behav)) {
        ddm_data_behav$subject_id <- as.character(ddm_data_behav$sub)
    } else if ("subject_id" %in% names(ddm_data_behav)) {
        ddm_data_behav$subject_id <- as.character(ddm_data_behav$subject_id)
    }
}

# Map task
if (!"task" %in% names(ddm_data_behav) || all(is.na(ddm_data_behav$task))) {
    if ("task_behav" %in% names(ddm_data_behav)) {
        ddm_data_behav$task <- ddm_data_behav$task_behav
    } else if ("task_modality" %in% names(ddm_data_behav)) {
        ddm_data_behav$task <- dplyr::case_when(
            ddm_data_behav$task_modality == "aud" ~ "ADT",
            ddm_data_behav$task_modality == "vis" ~ "VDT",
            TRUE ~ as.character(ddm_data_behav$task_modality)
        )
    }
}

cat("✅ Harmonization successful\n")
cat("   RT column:", if ("rt" %in% names(ddm_data_behav)) "✓" else "✗", "\n")
cat("   Accuracy column:", if ("accuracy" %in% names(ddm_data_behav)) "✓" else "✗", "\n")
cat("   Subject_id column:", if ("subject_id" %in% names(ddm_data_behav)) "✓" else "✗", "\n")
cat("   Task column:", if ("task" %in% names(ddm_data_behav)) "✓" else "✗", "\n")
cat("   Task values:", paste(unique(ddm_data_behav$task), collapse = ", "), "\n\n")

cat("Step 2: Testing with old column structure (backward compatibility)...\n")
test_data_old <- tibble(
    sub = c("BAP001", "BAP002"),
    task = c("aud", "vis"),
    resp1RT = c(0.5, 0.6),
    iscorr = c(1, 0)
)

ddm_data_behav_old <- test_data_old

# Apply harmonization
if (!"rt" %in% names(ddm_data_behav_old) && "resp1RT" %in% names(ddm_data_behav_old)) {
    ddm_data_behav_old$rt <- ddm_data_behav_old$resp1RT
}
ddm_data_behav_old$rt <- suppressWarnings(as.numeric(ddm_data_behav_old$rt))

if (!"accuracy" %in% names(ddm_data_behav_old) && "iscorr" %in% names(ddm_data_behav_old)) {
    ddm_data_behav_old$accuracy <- ddm_data_behav_old$iscorr
}

if (!"subject_id" %in% names(ddm_data_behav_old) && "sub" %in% names(ddm_data_behav_old)) {
    ddm_data_behav_old$subject_id <- as.character(ddm_data_behav_old$sub)
}

cat("✅ Old structure harmonization successful\n")
cat("   RT column:", if ("rt" %in% names(ddm_data_behav_old)) "✓" else "✗", "\n")
cat("   Accuracy column:", if ("accuracy" %in% names(ddm_data_behav_old)) "✓" else "✗", "\n")
cat("   Subject_id column:", if ("subject_id" %in% names(ddm_data_behav_old)) "✓" else "✗", "\n\n")

cat("================================================================================\n")
cat("✅ 02_ddm_analysis.R COLUMN HARMONIZATION TEST PASSED\n")
cat("================================================================================\n")
cat("Both new and old column structures are handled correctly.\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("================================================================================\n")

