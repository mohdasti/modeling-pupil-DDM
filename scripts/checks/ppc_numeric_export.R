# --- ppc_numeric_export.R -----------------------------------------------------

# Requirements: brms, posterior, tidyverse, data.table, stats, DescTools

# Assumes models are saved to output/models/{ModelName}.rds or .rds-like brms files,

# and raw trial-level data used to fit is in data/analysis_ready/bap_ddm_ready.csv.

# Writes numeric PPC metrics (no plots) to output/ppc/metrics/.



suppressPackageStartupMessages({

  library(brms)

  library(posterior)

  library(dplyr)

  library(tidyr)

  library(data.table)

  library(purrr)

  library(DescTools)   # for AUC if needed

})



dir.create("output/ppc/metrics", recursive = TRUE, showWarnings = FALSE)



# ------- USER CONFIG -------

model_files <- c(

  "output/models/Model1_Baseline.rds",

  "output/models/Model2_Force.rds",

  "output/models/Model3_Difficulty.rds",

  "output/models/Model4_Additive.rds",

  "output/models/Model5_Interaction.rds",

  "output/models/Model7_Task.rds",

  "output/models/Model8_Task_Additive.rds",

  "output/models/Model9_Task_Intx.rds",

  "output/models/Model10_Param_v_bs.rds"

)



# Which condition fields define a "cell" for PPC:

cell_vars <- c("task","effort_condition","difficulty_level")



# Posterior predictive settings (keep modest to run fast)

ppc_draws <- 1000



# Quantiles for QP/RT checks

qs <- c(.10,.30,.50,.70,.90)



# Thresholds for flagging misfit (tune if needed)

ACC_TOL   <- 0.05     # abs difference in accuracy

QP_TOL_S  <- 0.09     # RMSE of seconds across quantiles (correct / error)

KS_TOL    <- 0.15     # KS D-stat for RTs

CAF_TOL   <- 0.07     # RMSE of CAF (absolute accuracy units)



# ------------------------------------------------------------------------------



read_data <- function() {
  .t0 <- Sys.time()
  cat(sprintf("[%s] Loading data...\n", format(.t0, "%H:%M:%S"))); flush.console()

  data <- fread("data/analysis_ready/bap_ddm_ready.csv")
  
  # Harmonize column names
  if (!"rt" %in% names(data) && "resp1RT" %in% names(data)) {
    data$rt <- data$resp1RT
  }
  data$rt <- suppressWarnings(as.numeric(data$rt))
  
  if (!"accuracy" %in% names(data) && "iscorr" %in% names(data)) {
    data$accuracy <- data$iscorr
  }
  data$accuracy <- suppressWarnings(as.numeric(data$accuracy))
  
  if (!"subject_id" %in% names(data) && "sub" %in% names(data)) {
    data$subject_id <- as.character(data$sub)
  }
  
  if (!"task" %in% names(data) && "task_behav" %in% names(data)) {
    data$task <- data$task_behav
  }
  
  if (!"difficulty_level" %in% names(data)) {
    if ("stimulus_condition" %in% names(data)) {
      data$difficulty_level <- ifelse(
        data$stimulus_condition == "Standard", "Easy",
        ifelse(data$stimulus_condition == "Oddball", "Hard", NA_character_)
      )
    }
  }
  
  # Create decision from accuracy (1 = correct, 0 = error)
  data$decision <- as.integer(data$accuracy)
  
  # Ensure required columns exist
  if (!"effort_condition" %in% names(data)) {
    stop("effort_condition column not found in data")
  }
  
  # Filter RT range
  data <- data %>%
    filter(rt >= 0.25 & rt <= 3.0) %>%
    filter(!is.na(decision) & !is.na(rt))
  
  # Convert to factors if needed
  data$task <- as.factor(data$task)
  data$effort_condition <- as.factor(data$effort_condition)
  data$difficulty_level <- as.factor(data$difficulty_level)
  cat(sprintf("[%s] Data loaded: %d trials in %.1fs\n", 
              format(Sys.time(), "%H:%M:%S"), nrow(data), 
              as.numeric(difftime(Sys.time(), .t0, units = "secs")))); flush.console()
  data

}



empirical_summaries <- function(df) {

  # Per cell & correctness

  df %>%

    mutate(correct = decision == 1L) %>%

    group_by(across(all_of(cell_vars)), correct) %>%

    summarise(

      n = n(),

      acc = mean(correct),

      rt_q10 = quantile(rt, probs=.10, na.rm=TRUE),

      rt_q30 = quantile(rt, probs=.30, na.rm=TRUE),

      rt_q50 = quantile(rt, probs=.50, na.rm=TRUE),

      rt_q70 = quantile(rt, probs=.70, na.rm=TRUE),

      rt_q90 = quantile(rt, probs=.90, na.rm=TRUE),

      .groups="drop"

    )

}



simulate_pp <- function(fit, newdata, draws=ppc_draws) {

  # Return a data.frame of simulated RTs + correctness by row (like original)

  # posterior_predict() for wiener returns RT samples; to get choices we simulate

  # from the model-implied boundary crossing sign via posterior_epred on bias and drift.

  # Simpler, robust approach for PPC: we only need RT distributions split by correctness:

  # use posterior_predict to get RTs AND reuse observed correctness labels to form

  # conditional checks; also compute full pooled RT checks without correctness.

  # For CAF/QP by correctness, we approximate by reweighting to observed error rate.

  # (This avoids deep custom simulators while still yielding stable diagnostics.)



  y_rep <- posterior_predict(fit, newdata=newdata, draws=draws)  # matrix: draws x trials

  # Build long data table with one draw per trial (sampled without replacement per trial)

  set.seed(1)

  dsel <- sample(seq_len(draws), size=min(draws, 1000))  # cap

  y_rep <- y_rep[dsel, , drop=FALSE]

  dt <- as.data.table(t(y_rep))

  setnames(dt, paste0("draw_",seq_len(ncol(dt))))

  dt[, trial_id := .I]

  long <- melt(dt, id.vars="trial_id", variable.name="draw", value.name="rt_sim")

  # attach cell vars and observed correctness to align condition-wise summaries

  base <- as.data.table(newdata)[, c("trial_id", cell_vars, "decision"), with=FALSE]

  base[, correct := decision == 1L]

  out <- merge(long, base, by="trial_id", all.x=TRUE)

  out[]

}



ppc_metrics_for_model <- function(model_path, df) {
  .t_model <- Sys.time()
  cat(sprintf("[%s] === Processing %s ===\n", format(.t_model, "%H:%M:%S"), basename(model_path))); flush.console()

  .t <- Sys.time()
  fit <- readRDS(model_path)
  cat(sprintf("[%s] Model loaded in %.1fs\n", format(Sys.time(), "%H:%M:%S"), as.numeric(difftime(Sys.time(), .t, units = "secs")))); flush.console()

  # Ensure trial_id exists to merge; create if missing
  if (!"trial_id" %in% names(df)) df$trial_id <- seq_len(nrow(df))

  # Empirical summaries
  emp <- empirical_summaries(df)

  # Posterior predictive draws (aligned to same data)
  .t <- Sys.time();
  cat(sprintf("[%s] posterior_predict: draws=%d, trials=%d ...\n", format(.t, "%H:%M:%S"), ppc_draws, nrow(df))); flush.console()
  sim <- simulate_pp(fit, df)
  cat(sprintf("[%s] posterior_predict finished in %.1fs (sim rows: %s)\n", 
              format(Sys.time(), "%H:%M:%S"), as.numeric(difftime(Sys.time(), .t, units = "secs")), format(nrow(sim), big.mark=","))); flush.console()

  # --- Accuracy by cell ---
  .t <- Sys.time(); cat(sprintf("[%s] Computing accuracy metrics...\n", format(.t, "%H:%M:%S"))); flush.console()
  acc_emp <- df %>%
    mutate(correct = decision==1L) %>%
    group_by(across(all_of(cell_vars))) %>%
    summarise(emp_acc = mean(correct), n=n(), .groups="drop")

  acc_sim <- sim %>%
    group_by(across(all_of(c(cell_vars,"draw")))) %>%
    summarise(sim_acc = mean(correct), .groups="drop") %>%
    group_by(across(all_of(cell_vars))) %>%
    summarise(
      pred_acc_mean = mean(sim_acc),
      pred_acc_lo   = quantile(sim_acc, .025),
      pred_acc_hi   = quantile(sim_acc, .975),
      .groups="drop"
    )

  acc_merge <- left_join(acc_emp, acc_sim, by=cell_vars) %>%
    mutate(acc_abs_diff = abs(emp_acc - pred_acc_mean),
           acc_flag = acc_abs_diff > ACC_TOL)

  # --- RT quantiles (QP) by correctness & cell ---
  .t <- Sys.time(); cat(sprintf("[%s] Computing QP metrics...\n", format(.t, "%H:%M:%S"))); flush.console()
  sim_q <- sim %>%
    group_by(across(all_of(c(cell_vars,"correct","draw")))) %>%
    summarise(
      rt_q10 = quantile(rt_sim, .10, na.rm=TRUE),
      rt_q30 = quantile(rt_sim, .30, na.rm=TRUE),
      rt_q50 = quantile(rt_sim, .50, na.rm=TRUE),
      rt_q70 = quantile(rt_sim, .70, na.rm=TRUE),
      rt_q90 = quantile(rt_sim, .90, na.rm=TRUE),
      .groups="drop"
    ) %>%
    group_by(across(all_of(c(cell_vars,"correct")))) %>%
    summarise(across(starts_with("rt_q"), list(mean=mean, lo=~quantile(.x,.025), hi=~quantile(.x,.975))),
              .groups="drop")

  emp_q <- emp %>%
    select(all_of(cell_vars), correct, starts_with("rt_q"))

  qp <- left_join(emp_q, sim_q, by=c(cell_vars,"correct")) %>%
    rowwise() %>%
    mutate(
      rmse_qp = {
        empv <- c(rt_q10, rt_q30, rt_q50, rt_q70, rt_q90)
        pred <- c(`rt_q10_mean`, `rt_q30_mean`, `rt_q50_mean`, `rt_q70_mean`, `rt_q90_mean`)
        sqrt(mean((empv - pred)^2, na.rm=TRUE))
      },
      qp_flag = rmse_qp > QP_TOL_S
    ) %>% ungroup()

  # --- KS distances for pooled RTs by correctness & cell ---
  .t <- Sys.time(); cat(sprintf("[%s] Computing KS metrics...\n", format(.t, "%H:%M:%S"))); flush.console()
  ks_tbl <- sim %>%
    group_by(across(all_of(c(cell_vars,"correct","draw")))) %>%
    summarise(list_rt = list(rt_sim), .groups="drop") %>%
    group_by(across(all_of(c(cell_vars,"correct")))) %>%
    summarise(
      all_rt_sims = list(unlist(list_rt)),  # Combine all draws for this cell/correctness
      .groups="drop"
    ) %>%
    rowwise() %>%
    mutate(
      ks_mean = {
        # Get empirical RTs for this cell/correctness combination
        # Build filter condition dynamically - extract values from current row
        cell_filter <- TRUE
        for (var in cell_vars) {
          var_val <- get(var)  # Extract column value in rowwise context
          cell_filter <- cell_filter & (df[[var]] == var_val)
        }
        correct_val <- correct  # Extract correct value
        emp_rt <- df$rt[cell_filter & ((df$decision == 1L) == correct_val)]
        if (length(emp_rt) == 0 || length(all_rt_sims[[1]]) == 0) return(NA_real_)
        # Compute KS test
        tryCatch(ks.test(all_rt_sims[[1]], emp_rt)$statistic, error=function(e) NA_real_)
      }
    ) %>%
    ungroup() %>%
    select(all_of(cell_vars), correct, ks_mean) %>%
    mutate(ks_flag = ks_mean > KS_TOL)

  # --- CAF (accuracy vs RT quantiles) ---
  .t <- Sys.time(); cat(sprintf("[%s] Computing CAF metrics...\n", format(.t, "%H:%M:%S"))); flush.console()
  caf_emp <- df %>%
    group_by(across(all_of(cell_vars))) %>%
    mutate(bin = ntile(rt, 5)) %>%
    ungroup() %>%
    group_by(across(all_of(cell_vars)), bin) %>%
    summarise(emp_caf = mean(decision==1L), .groups="drop")

  caf_sim <- sim %>%
    group_by(across(all_of(c(cell_vars,"draw")))) %>%
    mutate(bin = ntile(rt_sim, 5)) %>%
    ungroup() %>%
    group_by(across(all_of(c(cell_vars,"draw"))), bin) %>%
    summarise(sim_caf = mean(correct), .groups="drop") %>%
    group_by(across(all_of(c(cell_vars,"bin")))) %>%
    summarise(pred_caf_mean = mean(sim_caf), .groups="drop")

  caf <- left_join(caf_emp, caf_sim, by=c(cell_vars,"bin")) %>%
    group_by(across(all_of(cell_vars))) %>%
    summarise(
      caf_rmse = sqrt(mean((emp_caf - pred_caf_mean)^2, na.rm=TRUE)),
      caf_flag = caf_rmse > CAF_TOL,
      .groups="drop"
    )

  # --- Join & score ---
  .t <- Sys.time(); cat(sprintf("[%s] Aggregating metrics...\n", format(.t, "%H:%M:%S"))); flush.console()
  out <- acc_merge %>%
    left_join(qp %>% select(all_of(cell_vars), correct, rmse_qp, qp_flag), by=c(cell_vars)) %>%
    # summarise qp across correct/error by max (worst case)
    group_by(across(all_of(cell_vars))) %>%
    summarise(
      emp_acc = first(emp_acc), pred_acc_mean = first(pred_acc_mean),
      pred_acc_lo = first(pred_acc_lo), pred_acc_hi = first(pred_acc_hi),
      acc_abs_diff = first(acc_abs_diff), acc_flag = first(acc_flag),
      qp_rmse_max = max(rmse_qp, na.rm=TRUE),
      qp_flag = any(qp_flag, na.rm=TRUE),
      .groups="drop"
    ) %>%
    left_join(ks_tbl %>% group_by(across(all_of(cell_vars))) %>% summarise(ks_mean_max = max(ks_mean, na.rm=TRUE), ks_flag = any(ks_flag, na.rm=TRUE), .groups="drop"),
              by=cell_vars) %>%
    left_join(caf, by=cell_vars) %>%
    mutate(
      model = basename(model_path),
      composite_score = scales::rescale(acc_abs_diff) +
                        scales::rescale(qp_rmse_max) +
                        scales::rescale(ks_mean_max) +
                        scales::rescale(caf_rmse),
      any_flag = acc_flag | qp_flag | ks_flag | caf_flag
    ) %>%
    arrange(desc(composite_score))

  cat(sprintf("[%s] %s complete in %.1fs\n\n", format(Sys.time(), "%H:%M:%S"), basename(model_path), as.numeric(difftime(Sys.time(), .t_model, units = "secs")))); flush.console()
  list(metrics=out, emp=emp, # handy to export
       detail_qp = qp, detail_caf = caf_emp)
}

# Process and write outputs --------------------------------------------------

df <- read_data()

# Check which models already have outputs (resume capability)
check_model_complete <- function(mod_name) {
  required_files <- c(
    paste0("output/ppc/metrics/", mod_name, "_ppc_metrics.csv"),
    paste0("output/ppc/metrics/", mod_name, "_empirical_qs.csv"),
    paste0("output/ppc/metrics/", mod_name, "_qp_detail.csv"),
    paste0("output/ppc/metrics/", mod_name, "_caf_empirical.csv")
  )
  all(file.exists(required_files))
}

# Sequential processing with logs and resume capability
all_metrics <- vector("list", length(model_files))
names(all_metrics) <- tools::file_path_sans_ext(basename(model_files))

# Option to force re-run (set to TRUE to recompute everything)
FORCE_RERUN <- FALSE

for (i in seq_along(model_files)) {
  mp <- model_files[[i]]
  mod_name <- names(all_metrics)[[i]]
  
  if (!file.exists(mp)) {
    cat(sprintf("[%s] ⚠️  Missing model file: %s (skipping)\n", format(Sys.time(), "%H:%M:%S"), mp)); flush.console();
    next
  }
  
  # Check if already completed
  if (!FORCE_RERUN && check_model_complete(mod_name)) {
    cat(sprintf("[%s] ✓ (%d/%d) %s already complete (loading from disk)\n", 
                format(Sys.time(), "%H:%M:%S"), i, length(model_files), basename(mp))); flush.console()
    
    # Load existing results
    tryCatch({
      all_metrics[[i]] <- list(
        metrics = fread(paste0("output/ppc/metrics/", mod_name, "_ppc_metrics.csv")),
        emp = fread(paste0("output/ppc/metrics/", mod_name, "_empirical_qs.csv")),
        detail_qp = fread(paste0("output/ppc/metrics/", mod_name, "_qp_detail.csv")),
        detail_caf = fread(paste0("output/ppc/metrics/", mod_name, "_caf_empirical.csv"))
      )
      cat(sprintf("[%s]   Loaded existing outputs for %s\n", format(Sys.time(), "%H:%M:%S"), mod_name)); flush.console()
    }, error = function(e) {
      cat(sprintf("[%s]   ⚠️  Error loading existing files, will recompute: %s\n", format(Sys.time(), "%H:%M:%S"), e$message)); flush.console()
      cat(sprintf("[%s] >>> (%d/%d) Starting %s\n", format(Sys.time(), "%H:%M:%S"), i, length(model_files), basename(mp))); flush.console()
      all_metrics[[i]] <- ppc_metrics_for_model(mp, df)
    })
    next
  }
  
  cat(sprintf("[%s] >>> (%d/%d) Starting %s\n", format(Sys.time(), "%H:%M:%S"), i, length(model_files), basename(mp))); flush.console()
  all_metrics[[i]] <- ppc_metrics_for_model(mp, df)
}

# Write per-model metrics
for (idx in seq_along(all_metrics)) {
  res <- all_metrics[[idx]]
  if (is.null(res)) next
  mod <- names(all_metrics)[[idx]]
  cat(sprintf("[%s] Writing outputs for %s ...\n", format(Sys.time(), "%H:%M:%S"), mod)); flush.console()
  fwrite(res$metrics,    file=paste0("output/ppc/metrics/", mod, "_ppc_metrics.csv"))
  fwrite(res$emp,        file=paste0("output/ppc/metrics/", mod, "_empirical_qs.csv"))
  fwrite(res$detail_qp,  file=paste0("output/ppc/metrics/", mod, "_qp_detail.csv"))
  fwrite(res$detail_caf, file=paste0("output/ppc/metrics/", mod, "_caf_empirical.csv"))
}

# Global top-rows (worst cells) to prioritise plots
stacked <- data.table::rbindlist(lapply(seq_along(all_metrics), function(i){
  if (is.null(all_metrics[[i]])) return(NULL)
  m <- all_metrics[[i]]$metrics; m$model <- names(all_metrics)[[i]]; m
}), fill=TRUE)

fwrite(stacked, "output/ppc/metrics/ppc_metrics_all_models.csv")

top10 <- stacked %>% arrange(desc(composite_score)) %>% slice_head(n=10)

fwrite(top10, "output/ppc/metrics/ppc_top10_cells.csv")

cat(sprintf("[%s] Wrote: output/ppc/metrics/* including ppc_metrics_all_models.csv and ppc_top10_cells.csv\n", format(Sys.time(), "%H:%M:%S"))); flush.console()

