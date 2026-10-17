# historical; not used for final outputs
# Copy r3–r7 and selected legacy files into one run folder and verify the copies.
# Read-only on existing sources. No fitting.

suppressPackageStartupMessages({
  library(brms)
})

options(warn = 1)
ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
FINAL <- "output/ddm_refits/runs/final_20261016"
INV <- "output/diagnostics/final_inventory"
dir.create(INV, recursive = TRUE, showWarnings = FALSE)

stop_at <- function(step, msg) {
  writeLines(c(
    sprintf("# Stopped at Step %s", step),
    "",
    msg,
    "",
    sprintf("Time: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  ), file.path(INV, "STOPPED.md"))
  stop(msg, call. = FALSE)
}

runs <- c(
  r3 = "output/ddm_refits/runs/r3_20261014_062419",
  r4 = "output/ddm_refits/runs/r4_20261015_074152",
  r5 = "output/ddm_refits/runs/r5_20261015_155543",
  r6 = "output/ddm_refits/runs/r6_20261016_010434",
  r7 = "output/ddm_refits/runs/r7_20261016_051737",
  legacy = "output/ddm_refits/runs/20260226_092110"
)
for (nm in names(runs)) {
  if (!dir.exists(runs[[nm]])) stop_at("1.2", sprintf("Missing source run %s: %s", nm, runs[[nm]]))
}

git_head <- tryCatch(system("git rev-parse HEAD", intern = TRUE), error = function(e) "UNKNOWN")
git_branch <- tryCatch(system("git rev-parse --abbrev-ref HEAD", intern = TRUE), error = function(e) "UNKNOWN")
git_short <- tryCatch(system("git status --short", intern = TRUE), error = function(e) character())
n_modified <- sum(grepl("^[ MARC]M|^M |^MM|^ D|^D ", git_short))
n_untracked <- sum(grepl("^\\?\\?", git_short))
preflight <- c(
  "# Step 1 preflight",
  "",
  sprintf("- Branch: `%s`", git_branch),
  sprintf("- HEAD: `%s`", git_head),
  sprintf("- git status --short: %d modified, %d untracked", n_modified, n_untracked),
  sprintf("- R: %s", R.version.string),
  sprintf("- brms: %s", as.character(packageVersion("brms"))),
  "",
  "## Resolved run directories",
  "",
  sprintf("- r3: `%s`", normalizePath(runs[["r3"]])),
  sprintf("- r4: `%s`", normalizePath(runs[["r4"]])),
  sprintf("- r5: `%s` (newest r5_*)", normalizePath(runs[["r5"]])),
  sprintf("- r6: `%s` (newest r6_*)", normalizePath(runs[["r6"]])),
  sprintf("- r7: `%s` (newest r7_*)", normalizePath(runs[["r7"]])),
  sprintf("- legacy: `%s`", normalizePath(runs[["legacy"]]))
)
writeLines(preflight, file.path(INV, "step1_preflight.md"))
file.copy("docs/ch3_analysis_decision_record.md",
          file.path(INV, "reference_decision_record.md"), overwrite = TRUE)
if (file.exists(file.path(INV, "STOPPED.md"))) unlink(file.path(INV, "STOPPED.md"))

copy_checked <- function(src, dest, step = "3") {
  if (!file.exists(src)) stop_at(step, sprintf("Required file missing: %s", src))
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(src, dest, overwrite = TRUE)
  if (!isTRUE(ok)) stop_at(step, sprintf("Copy failed: %s -> %s", src, dest))
  md_src <- unname(tools::md5sum(src))
  md_dst <- unname(tools::md5sum(dest))
  if (!identical(md_src, md_dst)) {
    stop_at(step, sprintf("md5 mismatch\nsource %s %s\ncopy   %s %s", src, md_src, dest, md_dst))
  }
  md_src
}

# model_id, role, tag, cutoff, n_trials, n_subjects, source model basename, loo basename, draws basename
specs <- rbind(
  data.frame(model_id = "M4", role = "primary", tag = "r4", cutoff = "0.20", n_trials = 17857L, n_subjects = 67L,
             model_base = "M4__probe_onset_locked__thr0.20.rds", loo_base = "loo_M4.rds", draws_base = "draws_M4.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "M4b", role = "comparison", tag = "r4", cutoff = "0.20", n_trials = 17857L, n_subjects = 67L,
             model_base = "M4b__probe_onset_locked__thr0.20.rds", loo_base = "loo_M4b.rds", draws_base = "draws_M4b.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "M0", role = "comparison", tag = "r3", cutoff = "0.20", n_trials = 17857L, n_subjects = 67L,
             model_base = "M0__probe_onset_locked__thr0.20.rds", loo_base = "loo_M0.rds", draws_base = "draws_M0.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "M1", role = "comparison", tag = "r3", cutoff = "0.20", n_trials = 17857L, n_subjects = 67L,
             model_base = "M1__probe_onset_locked__thr0.20.rds", loo_base = "loo_M1.rds", draws_base = "draws_M1.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "M2", role = "comparison", tag = "r3", cutoff = "0.20", n_trials = 17857L, n_subjects = 67L,
             model_base = "M2__probe_onset_locked__thr0.20.rds", loo_base = "loo_M2.rds", draws_base = "draws_M2.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "M3", role = "comparison", tag = "r3", cutoff = "0.20", n_trials = 17857L, n_subjects = 67L,
             model_base = "M3__probe_onset_locked__thr0.20.rds", loo_base = "loo_M3.rds", draws_base = "draws_M3.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "M4r", role = "robustness (random effort slopes)", tag = "r5", cutoff = "0.20", n_trials = 17857L, n_subjects = 67L,
             model_base = "M4r__probe_onset_locked__thr0.20.rds", loo_base = "loo_M4r.rds", draws_base = "draws_M4r.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "M4_thr0.15", role = "robustness (RT cutoff)", tag = "r7", cutoff = "0.15", n_trials = 17981L, n_subjects = 67L,
             model_base = "M4__probe_onset_locked__thr0.15.rds", loo_base = "loo_M4_thr0.15.rds", draws_base = "draws_M4_thr0.15.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "M4_thr0.25", role = "robustness (RT cutoff)", tag = "r7", cutoff = "0.25", n_trials = 17720L, n_subjects = 67L,
             model_base = "M4__probe_onset_locked__thr0.25.rds", loo_base = "loo_M4_thr0.25.rds", draws_base = "draws_M4_thr0.25.csv", stringsAsFactors = FALSE),
  data.frame(model_id = c("P0", "P1", "P2", "P3", "P4"), role = c("pupil (baseline)", "pupil", "pupil", "pupil (main pupil result)", "pupil"),
             tag = "r5", cutoff = "0.20", n_trials = 4569L, n_subjects = 39L,
             model_base = sprintf("%s__probe_onset_locked__thr0.20.rds", c("P0", "P1", "P2", "P3", "P4")),
             loo_base = sprintf("loo_%s.rds", c("P0", "P1", "P2", "P3", "P4")),
             draws_base = sprintf("draws_%s.csv", c("P0", "P1", "P2", "P3", "P4")), stringsAsFactors = FALSE),
  data.frame(model_id = "P5", role = "pupil-ordering", tag = "r6", cutoff = "0.20", n_trials = 4569L, n_subjects = 39L,
             model_base = "P5__probe_onset_locked__thr0.20.rds", loo_base = "loo_P5.rds", draws_base = "draws_P5.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "P6", role = "pupil-ordering", tag = "r6", cutoff = "0.20", n_trials = 3474L, n_subjects = 38L,
             model_base = "P6__probe_onset_locked__thr0.20.rds", loo_base = "loo_P6.rds", draws_base = "draws_P6.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "P7", role = "pupil-ordering", tag = "r6", cutoff = "0.20", n_trials = 3593L, n_subjects = 39L,
             model_base = "P7__probe_onset_locked__thr0.20.rds", loo_base = "loo_P7.rds", draws_base = "draws_P7.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "P8", role = "pupil-ordering", tag = "r6", cutoff = "0.20", n_trials = 4382L, n_subjects = 39L,
             model_base = "P8__probe_onset_locked__thr0.20.rds", loo_base = "loo_P8.rds", draws_base = "draws_P8.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "P3_rt", role = "pupil-ordering", tag = "r6", cutoff = "0.20", n_trials = 3677L, n_subjects = 39L,
             model_base = "P3_rt__probe_onset_locked__thr0.20.rds", loo_base = "loo_P3_rt.rds", draws_base = "draws_P3_rt.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "P0_lag", role = "pupil-ordering baseline", tag = "r6", cutoff = "0.20", n_trials = 3474L, n_subjects = 38L,
             model_base = "P0_lag__probe_onset_locked__thr0.20.rds", loo_base = "loo_P0_lag.rds", draws_base = "draws_P0_lag.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "P0_pre", role = "pupil-ordering baseline", tag = "r6", cutoff = "0.20", n_trials = 3593L, n_subjects = 39L,
             model_base = "P0_pre__probe_onset_locked__thr0.20.rds", loo_base = "loo_P0_pre.rds", draws_base = "draws_P0_pre.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "P0_grip", role = "pupil-ordering baseline", tag = "r6", cutoff = "0.20", n_trials = 4382L, n_subjects = 39L,
             model_base = "P0_grip__probe_onset_locked__thr0.20.rds", loo_base = "loo_P0_grip.rds", draws_base = "draws_P0_grip.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "P0_rt", role = "pupil-ordering baseline", tag = "r6", cutoff = "0.20", n_trials = 3677L, n_subjects = 39L,
             model_base = "P0_rt__probe_onset_locked__thr0.20.rds", loo_base = "loo_P0_rt.rds", draws_base = "draws_P0_rt.csv", stringsAsFactors = FALSE),
  data.frame(model_id = "P0_r6", role = "duplicate of r5 P0", tag = "r6", cutoff = "0.20", n_trials = 4569L, n_subjects = 39L,
             model_base = "P0__probe_onset_locked__thr0.20.rds", loo_base = "loo_P0.rds", draws_base = "draws_P0.csv", stringsAsFactors = FALSE)
)

dest_model_name <- function(model_id, cutoff, model_base) {
  if (model_id %in% c("M4_thr0.15", "M4_thr0.25")) return(model_base)
  if (model_id == "P0_r6") return("P0_r6__probe_onset_locked__thr0.20.rds")
  model_base
}

extract_dir <- c(r3 = "output/diagnostics/r3_extract", r4 = "output/diagnostics/r4_extract",
                 r5 = "output/diagnostics/r5_extract", r6 = "output/diagnostics/r6_extract",
                 r7 = "output/diagnostics/r7_extract")

message("Copying models, LOO, and draws")
copied <- vector("list", nrow(specs))
for (i in seq_len(nrow(specs))) {
  sp <- specs[i, ]
  src_model <- file.path(runs[[sp$tag]], "models", sp$model_base)
  src_loo <- file.path(runs[[sp$tag]], "loo", sp$loo_base)
  src_draws <- file.path(extract_dir[[sp$tag]], sp$draws_base)
  dest_model <- file.path(FINAL, "models", dest_model_name(sp$model_id, sp$cutoff, sp$model_base))
  dest_loo <- file.path(FINAL, "loo", sprintf("loo_%s.rds", sp$model_id))
  md_m <- copy_checked(src_model, dest_model)
  md_l <- copy_checked(src_loo, dest_loo)
  draws_final <- ""
  md_d <- NA_character_
  if (file.exists(src_draws)) {
    dest_draws <- file.path(FINAL, "draws", sprintf("draws_%s.csv", sp$model_id))
    md_d <- copy_checked(src_draws, dest_draws)
    draws_final <- dest_draws
  }
  copied[[i]] <- list(src_model = src_model, dest_model = dest_model, src_loo = src_loo,
                      dest_loo = dest_loo, draws_final = draws_final, md_model = md_m, md_loo = md_l, md_draws = md_d)
  message("  ", sp$model_id)
}

message("Copying tables, qc, descriptives, data")
for (tag in c("r3", "r4", "r5", "r6", "r7")) {
  src <- file.path(runs[[tag]], "tables")
  dest <- file.path(FINAL, "tables", tag)
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  files <- list.files(src, full.names = TRUE)
  if (!length(files)) stop_at("3", sprintf("No tables in %s", src))
  for (f in files) copy_checked(f, file.path(dest, basename(f)))
}
part_a <- list.files("output/diagnostics/r5_extract/part_a", full.names = TRUE)
if (!length(part_a)) stop_at("3", "r5 part_a folder is empty or missing")
for (f in part_a) copy_checked(f, file.path(FINAL, "qc", basename(f)))
desc <- list.files("output/diagnostics/r6_extract/descriptives", full.names = TRUE)
if (!length(desc)) stop_at("3", "r6 descriptives folder is empty or missing")
for (f in desc) copy_checked(f, file.path(FINAL, "pupil_descriptives", basename(f)))
data_files <- c(
  "data/analysis_ready/r5/ddm_pupil_r5_qc.csv",
  "data/analysis_ready/r5/ddm_behavioral_r5_full17857.csv",
  "data/analysis_ready/r6/ddm_pupil_r6.csv",
  "data/analysis_ready/r7/ddm_m4_cue_thr0.15.csv",
  "data/analysis_ready/r7/ddm_m4_cue_thr0.25.csv"
)
for (f in data_files) copy_checked(f, file.path(FINAL, "data", basename(f)))

message("Copying legacy models the chapter can still load")
legacy_copy <- list(
  list(id = "standard_only_thr0.20",
       src = file.path(runs[["legacy"]], "models", "standard_only__probe_onset_locked__thr0.20.rds"),
       dest = file.path(FINAL, "legacy", "standard_only__probe_onset_locked__thr0.20.rds")),
  list(id = "choice_history",
       src = "output/publish/fit_exploratory_choice_history_hist.rds",
       dest = file.path(FINAL, "legacy", "fit_exploratory_choice_history_hist.rds")),
  list(id = "choice_history_wsls",
       src = "output/publish/fit_exploratory_choice_history_wsls.rds",
       dest = file.path(FINAL, "legacy", "fit_exploratory_choice_history_wsls.rds")),
  list(id = "fatigue",
       src = "output/publish/fit_exploratory_fatigue_trajectory.rds",
       dest = file.path(FINAL, "legacy", "fit_exploratory_fatigue_trajectory.rds"))
)
legacy_md5 <- list()
for (item in legacy_copy) {
  if (!file.exists(item$src)) stop_at("2", sprintf("Legacy file missing: %s", item$src))
  legacy_md5[[item$id]] <- list(src = item$src, dest = item$dest, md5 = copy_checked(item$src, item$dest))
  message("  ", item$id)
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
conv_extract <- lapply(extract_dir, function(d) read_csv_safe(file.path(d, "tables", "convergence.csv")))
loo_extract <- lapply(extract_dir, function(d) read_csv_safe(file.path(d, "tables", "loo_summary.csv")))
conv_r3_run <- read_csv_safe(file.path(runs[["r3"]], "tables", "convergence_models.csv"))

lookup_row <- function(df, model_id) {
  if (is.null(df) || !nrow(df) || !"model" %in% names(df)) return(NULL)
  hit <- df[df$model == model_id, , drop = FALSE]
  if (!nrow(hit)) return(NULL)
  hit[1, , drop = FALSE]
}

formula_string <- function(fit) {
  txt <- tryCatch(
    paste(capture.output(print(stats::formula(fit))), collapse = " "),
    error = function(e) paste(deparse(fit$formula), collapse = " ")
  )
  gsub("\\s+", " ", txt)
}
sampler_bits <- function(fit) {
  out <- list(chains = NA_integer_, iter = NA_integer_, warmup = NA_integer_, save_pars_all = NA)
  sa <- tryCatch(fit$fit@stan_args[[1]], error = function(e) NULL)
  ch <- tryCatch(fit$fit@sim$chains, error = function(e) NA_integer_)
  if (!is.null(sa)) {
    out$iter <- sa$iter
    out$warmup <- sa$warmup
  }
  out$chains <- ch
  out$save_pars_all <- isTRUE(fit$save_pars$all)
  out
}

message("Verifying copied models")
rows <- list()
flags <- character()
for (i in seq_len(nrow(specs))) {
  sp <- specs[i, ]
  cp <- copied[[i]]
  message("  load ", sp$model_id)
  fit <- tryCatch(readRDS(cp$dest_model), error = function(e) {
    stop_at("4", sprintf("Model failed to load: %s\n%s", cp$dest_model, conditionMessage(e)))
  })
  n <- nrow(fit$data)
  if (!identical(as.integer(n), as.integer(sp$n_trials))) {
    stop_at("4", sprintf("%s nrow(fit$data) = %s, expected %s", sp$model_id, n, sp$n_trials))
  }
  subj_col <- if ("subject_id" %in% names(fit$data)) "subject_id" else NA_character_
  n_subj <- if (!is.na(subj_col)) length(unique(fit$data[[subj_col]])) else NA_integer_
  if (!is.na(n_subj) && !identical(as.integer(n_subj), as.integer(sp$n_subjects))) {
    stop_at("4", sprintf("%s n_subjects = %s, expected %s", sp$model_id, n_subj, sp$n_subjects))
  }
  samp <- sampler_bits(fit)
  form <- formula_string(fit)
  lo <- tryCatch(readRDS(cp$dest_loo), error = function(e) {
    stop_at("4", sprintf("LOO failed to load: %s\n%s", cp$dest_loo, conditionMessage(e)))
  })
  elpd <- tryCatch(unname(lo$estimates["elpd_loo", "Estimate"]), error = function(e) NA_real_)
  se <- tryCatch(unname(lo$estimates["elpd_loo", "SE"]), error = function(e) NA_real_)
  k <- tryCatch(as.numeric(lo$diagnostics$pareto_k), error = function(e) numeric())
  n_k <- if (length(k)) sum(k > 0.7, na.rm = TRUE) else NA_integer_
  rm(fit, lo)
  gc(verbose = FALSE)

  conv_id <- if (sp$model_id == "P0_r6") "P0" else sp$model_id
  ex <- lookup_row(conv_extract[[sp$tag]], conv_id)
  max_rhat <- if (!is.null(ex)) as.numeric(ex$max_rhat_all) else NA_real_
  min_ess <- if (!is.null(ex)) as.numeric(ex$min_bulk_ess_all) else NA_real_
  n_div <- if (!is.null(ex) && "n_divergent" %in% names(ex)) as.numeric(ex$n_divergent) else NA_real_
  if (is.na(max_rhat)) {
    stop_at("4", sprintf("No convergence.csv row for %s in %s extract", conv_id, sp$tag))
  }
  note <- character()
  if (sp$tag == "r3" && !is.null(conv_r3_run)) {
    run_row <- lookup_row(conv_r3_run, sp$model_id)
    if (!is.null(run_row)) {
      if (abs(as.numeric(run_row$max_rhat_all) - max_rhat) > 1e-6 ||
          abs(as.numeric(run_row$min_bulk_ess_all) - min_ess) > 1e-4) {
        flags <- c(flags, sprintf("%s r3 run convergence differs from extract", sp$model_id))
        note <- c(note, "r3 run convergence_models.csv differs from extract beyond rounding")
      }
      if ("divergences" %in% names(run_row)) n_div <- as.numeric(run_row$divergences)
    }
  }
  loo_row <- lookup_row(loo_extract[[sp$tag]], conv_id)
  if (!is.null(loo_row)) {
    if (is.finite(elpd) && abs(as.numeric(loo_row$elpd_loo) - elpd) > 1e-4) {
      flags <- c(flags, sprintf("%s elpd differs from extract", sp$model_id))
      note <- c(note, sprintf("extract elpd %.6f vs loo object %.6f", as.numeric(loo_row$elpd_loo), elpd))
    }
    k_cols <- intersect(c("k_0.7_1_final", "k_gt_1_final"), names(loo_row))
    if (length(k_cols) == 2 && is.finite(n_k)) {
      k_ex <- sum(as.numeric(loo_row[1, k_cols]))
      if (!is.na(k_ex) && k_ex != n_k) {
        flags <- c(flags, sprintf("%s Pareto-k count differs from extract", sp$model_id))
        note <- c(note, sprintf("extract k>0.7 = %s vs loo object %s", k_ex, n_k))
      }
    }
  }
  if (sp$model_id == "P0_r6") note <- c(note, "Same-data refit of P0 from r6, stored under a separate name from r5 P0")
  pass <- isTRUE(max_rhat < 1.01 && min_ess > 400 && n_div == 0)
  rows[[i]] <- data.frame(
    model_id = sp$model_id, role = sp$role, source_run = runs[[sp$tag]], source_path = cp$src_model,
    final_path = cp$dest_model, md5_source = cp$md_model, md5_final = cp$md_model,
    n_trials = n, n_subjects = n_subj, formula = form,
    chains = samp$chains, iter = samp$iter, warmup = samp$warmup, save_pars_all = samp$save_pars_all,
    max_rhat = max_rhat, min_bulk_ess = min_ess,
    passes_convergence_rule = pass, elpd_loo = elpd, se_elpd_loo = se, n_k_gt_0.7 = n_k,
    notes = paste(note, collapse = "; "), stringsAsFactors = FALSE
  )
}

message("Recording superseded, obsolete, and legacy rows")
superseded <- rbind(
  data.frame(model_id = "M3_thr0.15", src = file.path(runs[["r3"]], "models", "sens_M3__probe_onset_locked__thr0.15.rds"), stringsAsFactors = FALSE),
  data.frame(model_id = "M3_thr0.25", src = file.path(runs[["r3"]], "models", "sens_M3__probe_onset_locked__thr0.25.rds"), stringsAsFactors = FALSE)
)
extra_rows <- list()
for (i in seq_len(nrow(superseded))) {
  src <- superseded$src[i]
  if (!file.exists(src)) stop_at("2", sprintf("Superseded file missing: %s", src))
  md <- unname(tools::md5sum(src))
  ex <- lookup_row(conv_extract[["r3"]], superseded$model_id[i])
  extra_rows[[length(extra_rows) + 1]] <- data.frame(
    model_id = superseded$model_id[i], role = "superseded", source_run = runs[["r3"]], source_path = src,
    final_path = "", md5_source = md, md5_final = "",
    n_trials = NA_integer_, n_subjects = NA_integer_, formula = "",
    chains = NA_integer_, iter = NA_integer_, warmup = NA_integer_, save_pars_all = NA,
    max_rhat = if (!is.null(ex)) as.numeric(ex$max_rhat_all) else NA_real_,
    min_bulk_ess = if (!is.null(ex)) as.numeric(ex$min_bulk_ess_all) else NA_real_,
    passes_convergence_rule = if (!is.null(ex)) isTRUE(ex$pass_rhat_lt_1.01_bulk_gt_400 == "TRUE" || ex$pass_rhat_lt_1.01_bulk_gt_400 == TRUE) else NA,
    elpd_loo = NA_real_, se_elpd_loo = NA_real_, n_k_gt_0.7 = NA_integer_,
    notes = "r3 cutoff sensitivity on M3. Not copied. Superseded by r7 M4.",
    stringsAsFactors = FALSE
  )
}

legacy_models <- list.files(file.path(runs[["legacy"]], "models"), full.names = TRUE)
obsolete_pat <- "^(additive|interaction|baseline|task_sensitivity|pupil_interaction|sensitivity_baseline)__"
for (src in legacy_models) {
  base <- basename(src)
  if (base == "standard_only__probe_onset_locked__thr0.20.rds") next
  role <- if (grepl(obsolete_pat, base)) "obsolete" else "legacy_not_refit"
  note <- if (role == "obsolete") {
    "Old legacy model. Not copied."
  } else {
    "Present in the legacy run. Prompt copied only standard_only probe-onset 0.20 s."
  }
  extra_rows[[length(extra_rows) + 1]] <- data.frame(
    model_id = sub("\\.rds$", "", base), role = role, source_run = runs[["legacy"]], source_path = src,
    final_path = "", md5_source = unname(tools::md5sum(src)), md5_final = "",
    n_trials = NA_integer_, n_subjects = NA_integer_, formula = "",
    chains = NA_integer_, iter = NA_integer_, warmup = NA_integer_, save_pars_all = NA,
    max_rhat = NA_real_, min_bulk_ess = NA_real_, passes_convergence_rule = NA,
    elpd_loo = NA_real_, se_elpd_loo = NA_real_, n_k_gt_0.7 = NA_integer_,
    notes = note, stringsAsFactors = FALSE
  )
}
legacy_loo <- list.files(file.path(runs[["legacy"]], "loo"), pattern = "\\.rds$", full.names = TRUE)
for (src in legacy_loo) {
  base <- basename(src)
  role <- "obsolete"
  extra_rows[[length(extra_rows) + 1]] <- data.frame(
    model_id = sub("\\.rds$", "", base), role = role, source_run = runs[["legacy"]], source_path = src,
    final_path = "", md5_source = unname(tools::md5sum(src)), md5_final = "",
    n_trials = NA_integer_, n_subjects = NA_integer_, formula = "",
    chains = NA_integer_, iter = NA_integer_, warmup = NA_integer_, save_pars_all = NA,
    max_rhat = NA_real_, min_bulk_ess = NA_real_, passes_convergence_rule = NA,
    elpd_loo = NA_real_, se_elpd_loo = NA_real_, n_k_gt_0.7 = NA_integer_,
    notes = "Old LOO object. Not copied. loo_difficultyonly_primary_thr.rds is the unequal-N comparison.",
    stringsAsFactors = FALSE
  )
}

for (item in legacy_copy) {
  info <- legacy_md5[[item$id]]
  message("  load legacy ", item$id)
  fit <- tryCatch(readRDS(info$dest), error = function(e) {
    stop_at("4", sprintf("Legacy model failed to load: %s\n%s", info$dest, conditionMessage(e)))
  })
  n <- nrow(fit$data)
  n_subj <- if ("subject_id" %in% names(fit$data)) length(unique(fit$data$subject_id)) else NA_integer_
  samp <- sampler_bits(fit)
  form <- formula_string(fit)
  rm(fit)
  gc(verbose = FALSE)
  where <- if (grepl("^output/publish/", item$src)) {
    "Not inside the legacy run directory. The qmd loads this file from output/publish/."
  } else {
    "Copied from the legacy run."
  }
  extra_rows[[length(extra_rows) + 1]] <- data.frame(
    model_id = item$id, role = "legacy_not_refit", source_run = if (grepl("20260226", item$src)) runs[["legacy"]] else "output/publish",
    source_path = item$src, final_path = item$dest, md5_source = info$md5, md5_final = info$md5,
    n_trials = n, n_subjects = n_subj, formula = form,
    chains = samp$chains, iter = samp$iter, warmup = samp$warmup, save_pars_all = samp$save_pars_all,
    max_rhat = NA_real_, min_bulk_ess = NA_real_, passes_convergence_rule = NA,
    elpd_loo = NA_real_, se_elpd_loo = NA_real_, n_k_gt_0.7 = NA_integer_,
    notes = paste(where, "Convergence not recomputed (no convergence.csv for this file)."),
    stringsAsFactors = FALSE
  )
}

manifest <- do.call(rbind, c(rows, extra_rows))
utils::write.csv(manifest, file.path(FINAL, "MANIFEST.csv"), row.names = FALSE)
utils::write.csv(manifest, file.path(INV, "MANIFEST.csv"), row.names = FALSE)
writeLines(if (length(flags)) flags else "No extract cross-check differences larger than rounding.",
           file.path(INV, "step4_crosscheck.txt"))

fail <- manifest$role %in% c("primary", "comparison", "robustness (random effort slopes)", "robustness (RT cutoff)",
                             "pupil (baseline)", "pupil", "pupil (main pupil result)", "pupil-ordering",
                             "pupil-ordering baseline", "duplicate of r5 P0") &
  manifest$passes_convergence_rule %in% FALSE
fail_ids <- manifest$model_id[which(fail)]
fail_txt <- if (length(fail_ids)) {
  paste(sprintf("- `%s`: max R-hat %s, min bulk ESS %s",
                manifest$model_id[fail], format(manifest$max_rhat[fail], digits = 4),
                format(manifest$min_bulk_ess[fail], digits = 4)), collapse = "\n")
} else "None."

readme <- c(
  "# final_20261016",
  "",
  sprintf("Consolidated Chapter 3 fits. Built %s from git `%s`.", format(Sys.Date(), "%Y-%m-%d"), git_head),
  "",
  "This folder copies models from r3–r7. It does not refit them. Old filenames such as `additive__` were not recreated.",
  "",
  "## Roles",
  "",
  "- **primary**: M4, the model to report.",
  "- **comparison**: M0–M3 and M4b.",
  "- **robustness (random effort slopes)**: M4r.",
  "- **robustness (RT cutoff)**: M4 at cue-locked 0.15 s and 0.25 s.",
  "- **pupil** / **pupil (baseline)** / **pupil (main pupil result)**: r5 P0–P4. P3 is the main pupil result.",
  "- **pupil-ordering** and **pupil-ordering baseline**: r6 models. `P0_r6` is the r6 refit of P0 on the same 4,569 trials.",
  "- **superseded**: r3 M3 cutoff fits. Listed in MANIFEST.csv and not copied.",
  "- **legacy_not_refit**: Standard-only calibration, choice-history, WSLS, and within-session fatigue. Copied under `legacy/` for a later decision. Choice-history and fatigue were not in run `20260226_092110`; the chapter loads them from `output/publish/`.",
  "- **obsolete**: old additive, interaction, baseline, task-sensitivity, and pupil-interaction fits, plus their LOO objects. Listed and not copied.",
  "",
  "## Convergence exceptions",
  "",
  "The rule is max R-hat < 1.01, minimum bulk ESS > 400, and 0 divergences.",
  "",
  fail_txt,
  "",
  "`M4_thr0.15` fails on `Intercept_bs` only (R-hat 1.013, bulk ESS 926, 0 divergences). Its effort terms and non-decision time are not the failing parameter.",
  "",
  "M1 and M2 also fail this rule. The superseded r3 0.25 s M3 fit fails it as well and was not copied."
)
writeLines(readme, file.path(FINAL, "README.md"))
message("Consolidation finished. Cross-check flags: ", length(flags))
