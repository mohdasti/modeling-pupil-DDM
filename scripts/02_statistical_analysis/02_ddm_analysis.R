# =========================================================================
# SCRIPT 2: DDM STATISTICAL MODELING (FULLY EXPLICIT & FINAL VERSION)
# =========================================================================

# Ensure required packages and paths are available when running standalone
suppressPackageStartupMessages({
    library(dplyr)
    library(readr)
    library(purrr)
    library(brms)
})
if (!exists("DATA_PATHS") || !exists("OUTPUT_PATHS")) {
    config_dir <- file.path(getwd(), "config")
    candidate_configs <- c(
        file.path(config_dir, "paths_config.R"),
        file.path(config_dir, "pipeline_config.R"),
        file.path(config_dir, "paths_config.R.example")
    )
    loaded <- FALSE
    for (cfg in candidate_configs) {
        if (file.exists(cfg)) {
            try({ source(cfg); loaded <- TRUE }, silent = TRUE)
        }
        if (loaded && exists("DATA_PATHS") && exists("OUTPUT_PATHS")) break
    }
    if (!loaded || !exists("DATA_PATHS") || !exists("OUTPUT_PATHS")) {
        # Fallback minimal defaults inside repo
        DATA_PATHS <- list(
            analysis_ready = "data/analysis_ready",
            behavioral_file = "data/analysis_ready/BAP_analysis_ready_BEHAVIORAL.csv",
            pupil_file = "data/analysis_ready/BAP_analysis_ready_PUPIL.csv"
        )
        OUTPUT_PATHS <- list(
            base = "output",
            models = "output/models",
            results = "output/results",
            figures = "output/figures",
            logs = "output/logs"
        )
    }
}
if (!exists("log_message")) {
    log_message <- function(message, level = "INFO") {
        cat(sprintf("[%s] [%s] %s\n", format(Sys.time(), "%H:%M:%S"), level, message))
    }
}
dir.create(OUTPUT_PATHS$models, recursive = TRUE, showWarnings = FALSE)

log_message("DDM analysis (Step 2) initiated.", "INIT")
log_message("--- Loading & Preparing Datasets ---", "SUB-STEP")
choose_first_existing <- function(paths) {
    for (p in paths) {
        if (!is.null(p) && file.exists(p)) return(p)
    }
    return(NA_character_)
}
behavioral_candidates <- c(
    if (!is.null(DATA_PATHS$behavioral_data)) DATA_PATHS$behavioral_data else NA_character_,
    file.path(DATA_PATHS$analysis_ready, "BAP_analysis_ready_BEHAVIORAL.csv"),
    file.path(DATA_PATHS$analysis_ready, "behavioral_data.csv"),
    file.path("data/analysis_ready", "BAP_analysis_ready_BEHAVIORAL.csv"),
    file.path("data/analysis_ready", "behavioral_data.csv"),
    file.path("data/analysis_ready", "bap_ddm_ready.csv")
)
pupil_candidates <- c(
    if (!is.null(DATA_PATHS$pupil_data)) DATA_PATHS$pupil_data else NA_character_,
    file.path(DATA_PATHS$analysis_ready, "BAP_analysis_ready_PUPIL.csv"),
    file.path(DATA_PATHS$analysis_ready, "pupil_data.csv"),
    file.path("data/analysis_ready", "BAP_analysis_ready_PUPIL.csv"),
    file.path("data/analysis_ready", "pupil_data.csv"),
    file.path("data/analysis_ready", "bap_ddm_ready.csv")
)
behavioral_file <- choose_first_existing(behavioral_candidates)
pupil_file <- choose_first_existing(pupil_candidates)
if (is.na(behavioral_file)) {
    stop(paste0(
        "Could not find a behavioral data file. Tried: ",
        paste(behavioral_candidates[!is.na(behavioral_candidates)], collapse = ", ")
    ))
}
if (is.na(pupil_file)) {
    stop(paste0(
        "Could not find a pupil data file. Tried: ",
        paste(pupil_candidates[!is.na(pupil_candidates)], collapse = ", ")
    ))
}
log_message(paste("Using behavioral data:", behavioral_file))
log_message(paste("Using pupil data:", pupil_file))
ddm_data_behav <- readr::read_csv(behavioral_file, show_col_types = FALSE)
ddm_data_pupil <- readr::read_csv(pupil_file, show_col_types = FALSE)

# Harmonize column names/types for behavioral data
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
if (!"difficulty_level" %in% names(ddm_data_behav)) {
    if ("stimulus_condition" %in% names(ddm_data_behav)) {
        ddm_data_behav$difficulty_level <- ifelse(ddm_data_behav$stimulus_condition == "Standard", "Easy",
                                           ifelse(ddm_data_behav$stimulus_condition == "Oddball", "Hard", NA_character_))
    } else {
        ddm_data_behav$difficulty_level <- NA_character_
    }
}

# Harmonize column names/types for pupil data
# Map RT
if (!"rt" %in% names(ddm_data_pupil)) {
    if ("resp1RT" %in% names(ddm_data_pupil)) {
        ddm_data_pupil$rt <- ddm_data_pupil$resp1RT
    } else if ("same_diff_resp_secs" %in% names(ddm_data_pupil)) {
        ddm_data_pupil$rt <- ddm_data_pupil$same_diff_resp_secs
    }
}
ddm_data_pupil$rt <- suppressWarnings(as.numeric(ddm_data_pupil$rt))

# Map accuracy
if (!"accuracy" %in% names(ddm_data_pupil)) {
    if ("iscorr" %in% names(ddm_data_pupil)) {
        ddm_data_pupil$accuracy <- ddm_data_pupil$iscorr
    } else if ("resp_is_correct" %in% names(ddm_data_pupil)) {
        ddm_data_pupil$accuracy <- as.integer(ddm_data_pupil$resp_is_correct)
    }
}

# Map subject_id
if (!"subject_id" %in% names(ddm_data_pupil)) {
    if ("sub" %in% names(ddm_data_pupil)) {
        ddm_data_pupil$subject_id <- as.character(ddm_data_pupil$sub)
    } else if ("subject_id" %in% names(ddm_data_pupil)) {
        ddm_data_pupil$subject_id <- as.character(ddm_data_pupil$subject_id)
    }
}

# Map task
if (!"task" %in% names(ddm_data_pupil) || all(is.na(ddm_data_pupil$task))) {
    if ("task_behav" %in% names(ddm_data_pupil)) {
        ddm_data_pupil$task <- ddm_data_pupil$task_behav
    } else if ("task_modality" %in% names(ddm_data_pupil)) {
        ddm_data_pupil$task <- dplyr::case_when(
            ddm_data_pupil$task_modality == "aud" ~ "ADT",
            ddm_data_pupil$task_modality == "vis" ~ "VDT",
            TRUE ~ as.character(ddm_data_pupil$task_modality)
        )
    }
}
if (!"difficulty_level" %in% names(ddm_data_pupil)) {
    if ("stimulus_condition" %in% names(ddm_data_pupil)) {
        ddm_data_pupil$difficulty_level <- ifelse(ddm_data_pupil$stimulus_condition == "Standard", "Easy",
                                           ifelse(ddm_data_pupil$stimulus_condition == "Oddball", "Hard", NA_character_))
    } else {
        ddm_data_pupil$difficulty_level <- NA_character_
    }
}

# Map alternative pupil columns to required names if needed
get_first_col <- function(df, candidates) {
    for (nm in candidates) {
        if (nm %in% names(df)) return(df[[nm]])
    }
    return(NULL)
}
if (!"tonic_arousal" %in% names(ddm_data_pupil)) {
    tonic_candidate <- get_first_col(ddm_data_pupil, c("tonic_arousal", "pupil_baseline", "pupil_baseline_z"))
    if (!is.null(tonic_candidate)) {
        ddm_data_pupil$tonic_arousal <- as.numeric(tonic_candidate)
        log_message("Mapped tonic_arousal from available pupil baseline column", "INFO")
    }
}
if (!"effort_arousal_change" %in% names(ddm_data_pupil)) {
    effort_candidate <- get_first_col(ddm_data_pupil, c("effort_arousal_change", "pupil_evoked", "pupil_evoked_z", "pupil_mean", "pupil_mean_z"))
    if (!is.null(effort_candidate)) {
        ddm_data_pupil$effort_arousal_change <- as.numeric(effort_candidate)
        log_message("Mapped effort_arousal_change from available evoked/mean pupil column", "INFO")
    }
}
PUPIL_FEATURES_AVAILABLE <- all(c("tonic_arousal", "effort_arousal_change") %in% names(ddm_data_pupil))

    ddm_data_behav <- ddm_data_behav %>%
    dplyr::filter(rt >= 0.2 & rt <= 3.0) %>%
    dplyr::mutate(
        response = as.integer(accuracy),
        effort_condition = as.factor(effort_condition),
        difficulty_level = as.factor(difficulty_level),
        subject_id = as.factor(subject_id),
        task = as.factor(task),
        # Create decision variable for wiener family (1 for correct, 0 for incorrect)
        decision = ifelse(accuracy == 1, 1, 0)
    )
# Enforce consistent task levels globally so per-task splits retain both levels
if (all(unique(na.omit(ddm_data_behav$task)) %in% c("ADT","VDT"))) {
    ddm_data_behav$task <- factor(ddm_data_behav$task, levels = c("ADT","VDT"))
}
if (PUPIL_FEATURES_AVAILABLE) {
    ddm_data_pupil <- ddm_data_pupil %>%
        dplyr::filter(rt >= 0.2 & rt <= 3.0) %>%
        dplyr::mutate(
            response = as.integer(accuracy),
            effort_condition = as.factor(effort_condition),
            difficulty_level = as.factor(difficulty_level),
            subject_id = as.factor(subject_id),
            task = as.factor(task),
            # Create decision variable for wiener family (1 for correct, 0 for incorrect)
            decision = ifelse(accuracy == 1, 1, 0),
            tonic_arousal_scaled = scale(tonic_arousal)[,1],
            effort_arousal_scaled = scale(effort_arousal_change)[,1]
        )
    if (all(unique(na.omit(ddm_data_pupil$task)) %in% c("ADT","VDT"))) {
        ddm_data_pupil$task <- factor(ddm_data_pupil$task, levels = c("ADT","VDT"))
    }
} else {
    log_message("Pupillometry features not found; skipping pupil-based models.", "WARN")
}
log_message("SUCCESS: Data loading and preparation complete.", "INFO")
log_message(sprintf("Final datasets ready: BEHAVIORAL (%d trials), PUPIL (%d trials).", nrow(ddm_data_behav), nrow(ddm_data_pupil)))
create_ddm_models <- function() {
    # STANDARDIZED PRIORS: Literature-justified for older adults + response-signal design
    # Base priors (intercept-only for all parameters)
    # Note: b priors are added only when formulas have predictors
    base_priors <- c(
        # Drift rate (v) - identity link (intercept-only)
        prior(normal(0, 1), class = "Intercept"),
        
        # Boundary separation (a/bs) - log link: center at log(1.7) for older adults
        prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
        
        # Non-decision time (t0/ndt) - log link: center at log(0.23) for response-signal design
        # RTs measured from response screen, so ndt reflects motor output only (not stimulus encoding)
        # Prior mass ~95% ≈ 0.16-0.33s on natural scale
        prior(normal(log(0.23), 0.20), class = "Intercept", dpar = "ndt"),
        
        # Starting point bias (z) - logit link: centered at 0.5 with moderate spread
        prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
        
        # Random effects - subject-level variability
        # NOTE: NDT random effects removed to avoid initialization issues
        # Subject variation still captured in drift, boundary, and bias
        prior(student_t(3, 0, 0.5), class = "sd")
        # No sd prior for ndt since ndt has no random effects
    )
    
    # Priors for models with predictors on bs/ndt/bias (add when formulas have them)
    dpar_b_priors <- c(
        prior(normal(0, 0.20), class = "b", dpar = "bs"),
        prior(normal(0, 0.15), class = "b", dpar = "ndt"),  # Note: ndt predictor priors rarely used (usually intercept-only)
        prior(normal(0, 0.3), class = "b", dpar = "bias")
    )
    
    # Common priors for models where bs/ndt/bias are intercept-only
    common_priors <- base_priors
    # All models need explicit bs, ndt, bias formulas to allow priors on them
    models <- list(
        # NOTE: All models use ndt ~ 1 (no random effects) to avoid initialization issues
        # Subject variation is still modeled in drift, boundary, and bias parameters
        "Model1_Baseline"     = list(dataType = "behavioral", formula = brms::bf(
            rt | dec(decision) ~ 1 + (1|subject_id),
            bs ~ 1 + (1|subject_id),
            ndt ~ 1,  # No RE - avoids initialization explosions
            bias ~ 1 + (1|subject_id)
        )),
        "Model2_Force"        = list(dataType = "behavioral", formula = brms::bf(
            rt | dec(decision) ~ effort_condition + (1|subject_id),
            bs ~ 1 + (1|subject_id),
            ndt ~ 1,  # No RE
            bias ~ 1 + (1|subject_id)
        )),
        "Model3_Difficulty"   = list(dataType = "behavioral", formula = brms::bf(
            rt | dec(decision) ~ difficulty_level + (1|subject_id),
            bs ~ 1 + (1|subject_id),
            ndt ~ 1,  # No RE
            bias ~ 1 + (1|subject_id)
        )),
        "Model4_Additive"     = list(dataType = "behavioral", formula = brms::bf(
            rt | dec(decision) ~ effort_condition + difficulty_level + (1|subject_id),
            bs ~ 1 + (1|subject_id),
            ndt ~ 1,  # No RE
            bias ~ 1 + (1|subject_id)
        )),
        "Model5_Interaction"  = list(dataType = "behavioral", formula = brms::bf(
            rt | dec(decision) ~ effort_condition * difficulty_level + (1|subject_id),
            bs ~ 1 + (1|subject_id),
            ndt ~ 1,  # No RE
            bias ~ 1 + (1|subject_id)
        )),
        # Sensitivity: include task main effect and interactions
        "Model7_Task"          = list(dataType = "behavioral", formula = brms::bf(
            rt | dec(decision) ~ task + (1|subject_id),
            bs ~ 1 + (1|subject_id),
            ndt ~ 1,  # No RE
            bias ~ 1 + (1|subject_id)
        )),
        "Model8_Task_Additive" = list(dataType = "behavioral", formula = brms::bf(
            rt | dec(decision) ~ effort_condition + difficulty_level + task + (1|subject_id),
            bs ~ 1 + (1|subject_id),
            ndt ~ 1,  # No RE
            bias ~ 1 + (1|subject_id)
        )),
        "Model9_Task_Intx"     = list(dataType = "behavioral", formula = brms::bf(
            rt | dec(decision) ~ task * effort_condition + task * difficulty_level + (1|subject_id),
            bs ~ 1 + (1|subject_id),
            ndt ~ 1,  # No RE
            bias ~ 1 + (1|subject_id)
        ))
    )
    # Add parameterized Wiener model estimating both v and bs (and simple ndt)
    param_bf <- brms::bf(
        rt | dec(decision) ~ effort_condition + difficulty_level + (1|subject_id),
        bs ~ effort_condition + difficulty_level + (1|subject_id),
        ndt ~ 1,  # No RE
        bias ~ 1 + (1|subject_id)
    )
    models[["Model10_Param_v_bs"]] <- list(dataType = "behavioral", formula = param_bf)
    if (PUPIL_FEATURES_AVAILABLE) {
        models <- c(
            models,
            list(
                "Model6_Pupillometry"  = list(dataType = "pupil", formula = brms::bf(
                    rt | dec(decision) ~ effort_arousal_scaled + tonic_arousal_scaled + (1|subject_id),
                    bs ~ 1 + (1|subject_id),
                    ndt ~ 1,  # No RE
                    bias ~ 1 + (1|subject_id)
                )),
                "Model6a_Pupil_Task"   = list(dataType = "pupil", formula = brms::bf(
                    rt | dec(decision) ~ effort_arousal_scaled + tonic_arousal_scaled + task + (1|subject_id),
                    bs ~ 1 + (1|subject_id),
                    ndt ~ 1,  # No RE
                    bias ~ 1 + (1|subject_id)
                ))
            )
        )
    }
    # DEFENSIVE PRIOR BUILDER: Prevents "argument 5 is empty" from trailing commas/empty args
    build_priors <- function(...) {
        pieces <- list(...)
        # Filter out NULL, empty, or zero-length pieces
        pieces <- Filter(function(x) !is.null(x) && length(x) > 0, pieces)
        if (length(pieces) == 0) return(NULL)
        do.call(c, pieces)
    }
    
    # Assign priors based on model formulas (only include b priors when formulas have predictors)
    final_models <- purrr::imap(models, function(model_spec, model_name) {
        # Check drift rate formula for predictors
        formula_str <- paste(deparse(model_spec$formula), collapse = " ")
        drift_has_predictors <- any(grepl("~\\s*[^1(]+[a-zA-Z_]", formula_str))
        
        # Build priors defensively (no empty arguments)
        has_bs_predictors <- grepl("Model10", model_name)  # Only Model10 has bs predictors
        
        model_priors <- build_priors(
            base_priors,
            if (drift_has_predictors) prior(normal(0, 0.5), class = "b") else NULL,
            if (has_bs_predictors) prior(normal(0, 0.20), class = "b", dpar = "bs") else NULL
        )
        
        # Fallback to base_priors if build_priors returns NULL (shouldn't happen)
        if (is.null(model_priors)) model_priors <- base_priors
        
        model_spec$priors <- model_priors
        return(model_spec)
    })
    
    # Override priors for baseline (intercept-only for all parameters)
    final_models[["Model1_Baseline"]]$priors <- base_priors
    return(final_models)
}
fit_ddm_model <- function(spec, data, model_name) {
    # Minimal safe initialization: Only NDT must be initialized (must be < every RT)
    # Parameter names: brms uses Intercept_ndt (not b_ndt_Intercept) for dpar intercepts
    safe_init <- function(chain_id = 1) {
        list(
            Intercept_ndt = log(0.20),  # 200ms on log scale; safely below 250ms RT floor
            Intercept_bs  = log(1.3),   # Optional: tamer init for older adults
            Intercept_bias = 0,          # Optional: z ≈ 0.5 on logit scale
            Intercept     = 0            # Optional: drift intercept at 0
        )
    }
    
    # Validate priors before fitting (catches mismatches early)
    tryCatch({
        brms::validate_prior(spec$formula, data = data, prior = spec$priors)
    }, error = function(e) {
        log_message(sprintf("Prior validation warning for %s: %s", model_name, e$message), "WARN")
    })
    
    # Now using proper wiener family for DDM models
    brm(
        formula = spec$formula, data = data, 
        family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),  # Standardized links
        prior = spec$priors, 
        chains = 4, iter = 2000, warmup = 1000, cores = 4,
        init = safe_init,
        control = list(adapt_delta = 0.95, max_treedepth = 12),
        backend = "cmdstanr", 
        file = file.path(OUTPUT_PATHS$models, model_name), 
        file_refit = "on_change",
        refresh = 100
    )
}
model_specs <- create_ddm_models()

# Check factor levels before fitting
effort_levels <- length(unique(stats::na.omit(ddm_data_behav$effort_condition)))
difficulty_levels <- length(unique(stats::na.omit(ddm_data_behav$difficulty_level)))
task_levels <- length(unique(stats::na.omit(ddm_data_behav$task)))

log_message(sprintf("Factor levels: effort=%d, difficulty=%d, task=%d", 
                    effort_levels, difficulty_levels, task_levels), "INFO")

for (model_name in names(model_specs)) {
    spec <- model_specs[[model_name]]
    if (spec$dataType == "pupil" && !PUPIL_FEATURES_AVAILABLE) {
        log_message(paste("Skipping", model_name, "(pupil features unavailable)"), "WARN")
        next
    }
    
    # Check if model requires factors with multiple levels
    formula_str <- paste(deparse(spec$formula), collapse = " ")
    requires_effort <- any(grepl("effort_condition", formula_str))
    requires_task <- any(grepl("\\btask\\b", formula_str)) && !any(grepl("task_", formula_str))
    
    if (requires_effort && effort_levels < 2) {
        log_message(paste("Skipping", model_name, "(requires multiple effort levels, but only", effort_levels, "level(s) available)"), "WARN")
        next
    }
    if (requires_task && task_levels < 2) {
        log_message(paste("Skipping", model_name, "(requires multiple task levels, but only", task_levels, "level(s) available)"), "WARN")
        next
    }
    
    data_to_use <- if (spec$dataType == "pupil") ddm_data_pupil else ddm_data_behav
    
    tryCatch({
        log_message(paste("--- FITTING:", model_name, "---"), "MODEL")
        fit_ddm_model(spec, data_to_use, model_name)
        log_message(sprintf("SUCCESS: %s fitted.", model_name), "SUCCESS")
    }, error = function(e) {
        log_message(sprintf("FAILED to fit %s: %s", model_name, e$message), "ERROR")
    })
}

# ============================================================================
# REFIT FOUR BORDERLINE MODELS WITH SAFER HMC SETTINGS AND SAVE DIAGNOSTICS
# ============================================================================

try({ dir.create(file.path(OUTPUT_PATHS$base, "verification"), recursive = TRUE, showWarnings = FALSE) }, silent = TRUE)

borderline_models <- c("Model1_Baseline", "Model2_Force", "Model7_Task", "Model8_Task_Additive")
convergence_rows <- list()

for (model_name in borderline_models) {
    if (!model_name %in% names(model_specs)) next
    spec <- model_specs[[model_name]]
    if (spec$dataType != "behavioral") next
    data_to_use <- ddm_data_behav
    log_message(paste("--- REFIT (SAFE HMC):", model_name, "---"), "MODEL")
    # Use the same safe_init defined in fit_ddm_model
    safe_init <- function(chain_id = 1) {
        list(
            Intercept_ndt = log(0.20),
            Intercept_bs  = log(1.3),
            Intercept_bias = 0,
            Intercept     = 0
        )
    }
    fit <- tryCatch({
        brm(
            formula = spec$formula, data = data_to_use,
            family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
            prior = spec$priors,
            chains = 6, iter = 8000, warmup = 4000, cores = 6,
            init = safe_init,
            control = list(adapt_delta = 0.99, max_treedepth = 15),
            backend = "cmdstanr",
            file = file.path(OUTPUT_PATHS$models, model_name),
            file_refit = "on_change",
            refresh = 200
        )
    }, error = function(e) {
        log_message(sprintf("SAFE REFIT FAILED for %s: %s", model_name, e$message), "ERROR")
        NULL
    })
    if (is.null(fit)) next
    # Convergence diagnostics
    rhat_vals <- brms::rhat(fit)
    neff_rat <- brms::neff_ratio(fit)
    max_rhat <- suppressWarnings(max(rhat_vals, na.rm = TRUE))
    min_neff_ratio <- suppressWarnings(min(neff_rat, na.rm = TRUE))
    convergence_rows[[length(convergence_rows) + 1]] <- data.frame(
        model = model_name,
        max_rhat = max_rhat,
        min_neff_ratio = min_neff_ratio,
        stringsAsFactors = FALSE
    )
}

if (length(convergence_rows) > 0) {
    convergence_df <- do.call(rbind, convergence_rows)
    out_csv <- file.path(OUTPUT_PATHS$base, "verification", "convergence_refits.csv")
    try(utils::write.csv(convergence_df, out_csv, row.names = FALSE), silent = TRUE)
    log_message(paste("Saved convergence summaries to", out_csv), "SUCCESS")
}

# Optional: run all models separately for each task (ADT/VDT)
RUN_PER_TASK_ANALYSES <- TRUE
if (RUN_PER_TASK_ANALYSES) {
    tasks_available <- unique(ddm_data_behav$task)
    log_message(paste("Per-task analyses enabled. Global task levels:", paste(levels(ddm_data_behav$task), collapse=",")))
    for (task_level in tasks_available) {
        ddm_behav_task <- ddm_data_behav %>% dplyr::filter(task == task_level)
        ddm_pupil_task <- if (PUPIL_FEATURES_AVAILABLE) ddm_data_pupil %>% dplyr::filter(task == task_level) else NULL
        log_message(paste("Subset:", task_level, "| behav levels:", paste(levels(ddm_behav_task$task), collapse=","),
                          "| pupil levels:", if (!is.null(ddm_pupil_task)) paste(levels(ddm_pupil_task$task), collapse=",") else "(no pupil)"))
        for (model_name in names(model_specs)) {
            spec <- model_specs[[model_name]]
            if (spec$dataType == "pupil" && !PUPIL_FEATURES_AVAILABLE) {
                log_message(paste("Skipping", model_name, "for", task_level, "(pupil features unavailable)"), "WARN")
                next
            }
            # If per-task subset contains a single observed task level, skip models containing 'task'
            observed_task_levels <- length(unique(stats::na.omit(ddm_behav_task$task)))
            if (observed_task_levels < 2) {
                formula_str <- paste0(deparse(spec$formula), collapse = "")
                if (grepl("task", formula_str, fixed = TRUE)) {
                    log_message(paste("Skipping", model_name, "for", task_level, "(contains 'task' term but only one observed task level)"), "WARN")
                    next
                }
            }
            data_to_use <- if (spec$dataType == "pupil") ddm_pupil_task else ddm_behav_task
            tryCatch({
                log_message(paste("--- FITTING (", task_level, "):", model_name, "---"), "MODEL")
                fit_ddm_model(spec, data_to_use, paste0(model_name, "_", task_level))
                log_message(sprintf("SUCCESS: %s (%s) fitted.", model_name, task_level), "SUCCESS")
            }, error = function(e) {
                log_message(sprintf("FAILED to fit %s (%s): %s", model_name, task_level, e$message), "ERROR")
            })
        }
    }
}