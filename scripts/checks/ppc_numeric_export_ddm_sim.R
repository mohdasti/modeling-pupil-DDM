# --- ppc_numeric_export_ddm_sim.R ---------------------------------------------

# Purpose: Export numeric PPC metrics using *true DDM simulation* (choices + RT).

# Requirements: brms, rtdists, data.table, dplyr, tidyr, purrr

# Input:

#   - Saved brms models (RDS) in output/models/

#   - Trial-level data used to fit (data/analysis_ready/bap_ddm_ready.csv)

# Output (CSV):

#   - output/ppc/metrics/ddm_ppc_metrics_all_models.csv

#   - output/ppc/metrics/ddm_ppc_top10_cells.csv



suppressPackageStartupMessages({

  library(brms)

  library(rtdists)

  library(data.table)

  library(dplyr)

  library(tidyr)

  library(purrr)

  library(scales)

})



dir.create("output/ppc/metrics", recursive = TRUE, showWarnings = FALSE)



# --------- USER CONFIG ---------------------------------------------------------

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



cell_vars <- c("task","effort_condition","difficulty_level")

ppc_draws <- 400          # 300–600 is a good balance for speed vs. stability

set.seed(42)



# Thresholds

ACC_TOL   <- 0.05

QP_TOL_S  <- 0.09   # seconds

KS_TOL    <- 0.15

CAF_TOL   <- 0.07



# --------------------------------------------------------------------------------



# Load data ---------------------------------------------------------------

df <- fread("data/analysis_ready/bap_ddm_ready.csv")

# Harmonize column names
if (!"rt" %in% names(df) && "resp1RT" %in% names(df)) {
  df[, rt := resp1RT]
}
df[, rt := as.numeric(rt)]

# Create decision from accuracy/iscorr/choice if needed
if (!"decision" %in% names(df)) {
  if ("accuracy" %in% names(df)) {
    df[, decision := as.integer(accuracy)]
  } else if ("iscorr" %in% names(df)) {
    df[, decision := as.integer(iscorr)]
  } else if ("choice" %in% names(df)) {
    df[, decision := as.integer(choice)]
  } else if ("choice_binary" %in% names(df)) {
    df[, decision := as.integer(choice_binary)]
  } else {
    stop("Could not find decision, accuracy, iscorr, choice, or choice_binary column")
  }
} else {
  df[, decision := as.integer(decision)]
}

# Ensure required columns exist
if (!"trial_id" %in% names(df)) df[, trial_id := .I]

# Harmonize other columns if needed
if (!"subject_id" %in% names(df) && "sub" %in% names(df)) {
  df[, subject_id := as.character(sub)]
}

if (!"task" %in% names(df) && "task_behav" %in% names(df)) {
  df[, task := task_behav]
}

# Filter RT range (same as model fitting)
df <- df[rt >= 0.25 & rt <= 3.0 & !is.na(decision) & !is.na(rt)]

stopifnot(all(c(cell_vars, "rt","decision","trial_id") %in% names(df)))



# Helper: posterior trial-wise parameters (natural scale) -----------------

get_param_draws <- function(fit, newdata, ndraws=ppc_draws) {

  # Extract trial-wise posterior draws for DDM parameters on *natural* scale.

  # dpars in brms(wiener): "mu" (drift), "bs" (boundary), "ndt" (non-decision time), "bias" (starting point)

  sel <- sample(1:posterior::ndraws(fit), size=ndraws, replace=FALSE)



  # drift v (identity link) - in brms Wiener models, drift is called "mu", not "v"

  v   <- posterior_linpred(fit, newdata=newdata, dpar="mu", transform=TRUE)[sel, , drop=FALSE]

  # boundary a (log link -> transform=TRUE returns natural a)

  a   <- posterior_linpred(fit, newdata=newdata, dpar="bs", transform=TRUE)[sel, , drop=FALSE]

  # ndt t0 (log link)

  t0  <- posterior_linpred(fit, newdata=newdata, dpar="ndt", transform=TRUE)[sel, , drop=FALSE]

  # bias z (logit link)

  z   <- posterior_linpred(fit, newdata=newdata, dpar="bias", transform=TRUE)[sel, , drop=FALSE]



  # Sanity clamps (avoid pathologies)

  a[a <= 1e-4]   <- 1e-4

  t0[t0 <= 1e-4] <- 1e-4

  z[z <= 1e-6]   <- 1e-6

  z[z >= 1-1e-6] <- 1-1e-6



  list(v=v, a=a, t0=t0, z=z, sel=sel)

}



# Helper: simulate choices + RT per draw ----------------------------------

sim_ddm_draws <- function(pars, newdata) {

  # Simulate for each draw across all trials in 'newdata'

  n_trials <- nrow(newdata)

  nd <- nrow(pars$v)

  out <- vector("list", length=nd)



  for (d in seq_len(nd)) {

    vv  <- pars$v[d, ]

    aa  <- pars$a[d, ]

    tt  <- pars$t0[d, ]

    zz  <- pars$z[d, ]



    # IMPORTANT: We define "upper" boundary as "correct" by design (consistent with dec(decision))

    sim <- rwiener(n = n_trials, alpha = aa, tau = tt, beta = zz, delta = vv)

    # rwiener returns 'resp' as "upper"/"lower"; treat "upper" as correct

    sim$correct <- as.integer(sim$resp == "upper")

    sim$rt      <- sim$q

    sim$draw    <- d

    sim$trial_id <- newdata$trial_id



    # attach cells - convert newdata to data.frame for interaction

    newdata_df <- if (inherits(newdata, "data.table")) as.data.frame(newdata) else newdata

    sim$cell <- interaction(newdata_df[, cell_vars, drop=FALSE], drop=TRUE)

    out[[d]] <- as.data.table(sim)

  }

  rbindlist(out)

}



# Empirical summaries (by cell & correctness) ----------------------------

empirical_summaries <- function(df) {

  # Convert to data.frame if data.table to avoid dplyr issues

  if (inherits(df, "data.table")) {

    df <- as.data.frame(df)

  }

  df %>%

    mutate(correct = decision == 1L,

           cell = interaction(across(all_of(cell_vars)), drop=TRUE)) %>%

    group_by(cell, correct) %>%

    summarise(

      n = n(),

      acc = mean(correct),

      rt_q10 = quantile(rt, .10, na.rm=TRUE),

      rt_q30 = quantile(rt, .30, na.rm=TRUE),

      rt_q50 = quantile(rt, .50, na.rm=TRUE),

      rt_q70 = quantile(rt, .70, na.rm=TRUE),

      rt_q90 = quantile(rt, .90, na.rm=TRUE),

      .groups="drop"

    )

}



# Compute PPC metrics per model ------------------------------------------

ppc_metrics_for_model <- function(model_path, df) {

  fit <- readRDS(model_path)

  pars <- get_param_draws(fit, df, ndraws=ppc_draws)

  sim  <- sim_ddm_draws(pars, df)



  # Empirical

  emp <- empirical_summaries(df)



  # Accuracy by cell: empirical vs simulated

  # Convert to data.frame if data.table

  df_df <- if (inherits(df, "data.table")) as.data.frame(df) else df

  acc_emp <- df_df %>%

    mutate(cell = interaction(across(all_of(cell_vars)), drop=TRUE),

           correct = decision==1L) %>%

    group_by(cell) %>%

    summarise(emp_acc = mean(correct), .groups="drop")



  acc_sim <- sim %>%

    group_by(cell, draw) %>%

    summarise(sim_acc = mean(correct), .groups="drop") %>%

    group_by(cell) %>%

    summarise(pred_acc_mean = mean(sim_acc),

              pred_acc_lo = quantile(sim_acc,.025),

              pred_acc_hi = quantile(sim_acc,.975),

              .groups="drop")



  acc_merge <- left_join(acc_emp, acc_sim, by="cell") %>%

    mutate(acc_abs_diff = abs(emp_acc - pred_acc_mean),

           acc_flag = acc_abs_diff > ACC_TOL)



  # QP: RT quantiles by correctness

  sim_q <- sim %>%

    group_by(cell, correct, draw) %>%

    summarise(

      rt_q10 = quantile(rt, .10, na.rm=TRUE),

      rt_q30 = quantile(rt, .30, na.rm=TRUE),

      rt_q50 = quantile(rt, .50, na.rm=TRUE),

      rt_q70 = quantile(rt, .70, na.rm=TRUE),

      rt_q90 = quantile(rt, .90, na.rm=TRUE),

      .groups="drop"

    ) %>%

    group_by(cell, correct) %>%

    summarise(across(starts_with("rt_q"),

                     list(mean=mean, lo=~quantile(.x,.025), hi=~quantile(.x,.975))),

              .groups="drop")



  emp_q <- emp %>% select(cell, correct, starts_with("rt_q"))

  qp <- left_join(emp_q, sim_q, by=c("cell","correct")) %>%

    rowwise() %>%

    mutate(

      rmse_qp = {

        empv <- c(rt_q10, rt_q30, rt_q50, rt_q70, rt_q90)

        pred <- c(`rt_q10_mean`, `rt_q30_mean`, `rt_q50_mean`, `rt_q70_mean`, `rt_q90_mean`)

        sqrt(mean((empv - pred)^2, na.rm=TRUE))

      }

    ) %>% ungroup()



  # Aggregate QP across correct/error per cell by worst-case (max)

  qp_cell <- qp %>%

    group_by(cell) %>%

    summarise(qp_rmse_max = max(rmse_qp, na.rm=TRUE),

              qp_flag = qp_rmse_max > QP_TOL_S,

              .groups="drop")



  # KS: average per-draw KS between empirical vs simulated RTs by correctness; take worst case

  ks_cell <- sim %>%

    group_by(cell, correct, draw) %>%

    summarise(list_rt = list(rt), .groups="drop") %>%

    group_by(cell, correct) %>%

    summarise(

      ks_mean = {

        df_df <- if (inherits(df, "data.table")) as.data.frame(df) else df

        emp_rt <- df_df %>% mutate(cell = interaction(across(all_of(cell_vars)), drop=TRUE),

                                correct2 = decision==1L) %>%

          filter(cell==first(cell), correct2==first(correct)) %>% pull(rt)

        if (length(emp_rt) < 5) return(NA_real_)

        mean(sapply(list_rt, function(x){

          x <- unlist(x); if (length(x)<5) return(NA_real_)

          suppressWarnings(ks.test(x, emp_rt)$statistic)

        }), na.rm=TRUE)

      },

      .groups="drop"

    ) %>%

    group_by(cell) %>%

    summarise(ks_mean_max = max(ks_mean, na.rm=TRUE),

              ks_flag = ks_mean_max > KS_TOL,

              .groups="drop")



  # CAF: 5-bin accuracy vs RT

  df_df <- if (inherits(df, "data.table")) as.data.frame(df) else df

  emp_caf <- df_df %>%

    mutate(cell = interaction(across(all_of(cell_vars)), drop=TRUE)) %>%

    group_by(cell) %>%

    mutate(bin = ntile(rt, 5)) %>%

    ungroup() %>%

    group_by(cell, bin) %>%

    summarise(emp_caf = mean(decision==1L), .groups="drop")



  sim_caf <- sim %>%

    group_by(cell, draw) %>%

    mutate(bin = ntile(rt, 5)) %>%

    ungroup() %>%

    group_by(cell, draw, bin) %>%

    summarise(sim_caf = mean(correct), .groups="drop") %>%

    group_by(cell, bin) %>%

    summarise(pred_caf_mean = mean(sim_caf), .groups="drop")



  caf <- left_join(emp_caf, sim_caf, by=c("cell","bin")) %>%

    group_by(cell) %>%

    summarise(caf_rmse = sqrt(mean((emp_caf - pred_caf_mean)^2, na.rm=TRUE)),

              caf_flag = caf_rmse > CAF_TOL,

              .groups="drop")



  # Put it together

  metrics <- acc_merge %>%

    left_join(qp_cell, by="cell") %>%

    left_join(ks_cell, by="cell") %>%

    left_join(caf, by="cell") %>%

    mutate(model = tools::file_path_sans_ext(basename(model_path)),

           any_flag = acc_flag | qp_flag | ks_flag | caf_flag) %>%

    select(model, cell, emp_acc, pred_acc_mean, pred_acc_lo, pred_acc_hi,

           acc_abs_diff, acc_flag, qp_rmse_max, qp_flag, ks_mean_max, ks_flag,

           caf_rmse, caf_flag, any_flag)



  metrics

}



# Driver: run for each model and export -----------------------------------

all_metrics <- map_dfr(model_files, ~ppc_metrics_for_model(.x, df))



# Expand 'cell' back to columns

split_cells <- all_metrics %>%

  separate(cell, into = cell_vars, sep="\\.", remove=FALSE)



# Write out

fwrite(split_cells, "output/ppc/metrics/ddm_ppc_metrics_all_models.csv")



top10 <- split_cells %>%

  mutate(composite = scales::rescale(abs(acc_abs_diff)) +

                     scales::rescale(qp_rmse_max) +

                     scales::rescale(ks_mean_max) +

                     scales::rescale(caf_rmse)) %>%

  arrange(desc(composite)) %>%

  slice_head(n=10)



fwrite(top10, "output/ppc/metrics/ddm_ppc_top10_cells.csv")



message("Wrote: ddm_ppc_metrics_all_models.csv and ddm_ppc_top10_cells.csv")

# -------------------------------------------------------------------------



# Now run this script from project root:

# source('scripts/checks/ppc_numeric_export_ddm_sim.R')

