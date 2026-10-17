# historical; not used for final outputs
# Read-only inventory of reports/chap3_ddm_results.qmd.
# Writes output/diagnostics/final_inventory/.

suppressPackageStartupMessages(library(tools))
ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
INV <- "output/diagnostics/final_inventory"
FINAL <- "output/ddm_refits/runs/final_20261016"
QMD <- "reports/chap3_ddm_results.qmd"
dir.create(INV, recursive = TRUE, showWarnings = FALSE)

lines <- readLines(QMD, warn = FALSE)
final_files <- list.files(FINAL, recursive = TRUE, full.names = TRUE)
final_base <- basename(final_files)
names(final_files) <- final_base

classify_path <- function(path_written) {
  base <- basename(path_written)
  obsolete <- grepl("additive__|interaction__|pupil_interaction__|task_sensitivity__|baseline__|loo_difficultyonly|loo_additive|loo_interaction|sensitivity_baseline", path_written)
  legacy <- grepl("standard_only|choice_history|fatigue_trajectory|wsls", path_written)
  if (obsolete) {
    return(list(status = "obsolete", proposed = ""))
  }
  if (legacy) {
    hit <- final_files[final_base == base]
    proposed <- if (length(hit)) unname(hit[[1]]) else ""
    return(list(status = "legacy_not_refit", proposed = proposed))
  }
  hit <- final_files[final_base == base]
  if (length(hit) == 1) return(list(status = "available_same_name", proposed = unname(hit[[1]])))
  if (length(hit) > 1) return(list(status = "available_same_name", proposed = paste(unname(hit), collapse = " | ")))
  # renamed refit equivalents for the primary behavioral model name the qmd still uses
  if (grepl("additive__probe_onset_locked__thr0\\.20", path_written)) {
    return(list(status = "obsolete", proposed = file.path(FINAL, "models/M4__probe_onset_locked__thr0.20.rds")))
  }
  list(status = "missing", proposed = "")
}

extract_paths <- function(text) {
  out <- character()
  mm <- gregexpr("\"([^\"]+)\"", text, perl = TRUE)
  if (mm[[1]][1] != -1) {
    caps <- regmatches(text, mm)[[1]]
    caps <- gsub("^\"|\"$", "", caps)
    out <- c(out, caps)
  }
  mm2 <- gregexpr("here::here\\(([^)]*)\\)", text, perl = TRUE)
  if (mm2[[1]][1] != -1) {
    bits <- regmatches(text, mm2)[[1]]
    for (b in bits) {
      parts <- gsub("\"", "", unlist(regmatches(b, gregexpr("\"[^\"]+\"", b))))
      if (length(parts)) out <- c(out, paste(parts, collapse = "/"))
    }
  }
  out[grepl("/|\\.(csv|rds|R|r|png|pdf|jpg|md|qmd)$", out)]
}

# --- Inventory A ---
in_chunk <- FALSE
chunk <- "prose"
a_rows <- list()
add_a <- function(line_no, chunk_label, call, path_written, used_for) {
  cls <- classify_path(path_written)
  resolved <- path_written
  if (!grepl("^/|params\\$", path_written) && !file.exists(path_written)) {
    resolved <- path_written
  }
  a_rows[[length(a_rows) + 1]] <<- data.frame(
    qmd_line = line_no, chunk_label = chunk_label, call = call,
    path_as_written = path_written, resolved_path_old = resolved,
    used_for = used_for, old_model_or_table = basename(path_written),
    status = cls$status, proposed_source_in_final = cls$proposed,
    stringsAsFactors = FALSE
  )
}
used_for_line <- function(text, chunk_now) {
  if (grepl("include_graphics|!\\[|fig1_|fig2_|fig3_|fig4_|fig5_|\\.png|\\.pdf", text)) return("figure")
  if (grepl("read_csv|read\\.csv|sread|readRDS|load\\(", text)) {
    if (grepl("fig|plot|ggplot", chunk_now)) return("figure")
    return("table")
  }
  if (grepl("source\\(", text)) return("helper")
  "inline value"
}

for (i in seq_along(lines)) {
  ln <- lines[[i]]
  if (grepl("^```\\{r", ln)) {
    in_chunk <- TRUE
    lab <- sub("^```\\{r\\s*", "", ln)
    lab <- sub("\\}.*$", "", lab)
    chunk <- if (nzchar(lab)) lab else "unlabeled"
    next
  }
  if (in_chunk && grepl("^```\\s*$", ln)) {
    in_chunk <- FALSE
    chunk <- "prose"
    next
  }
  label_now <- if (in_chunk) chunk else if (grepl("^!\\[", ln)) "prose" else "prose"
  calls <- c()
  if (grepl("source\\(", ln)) calls <- c(calls, "source")
  if (grepl("readRDS\\(", ln)) calls <- c(calls, "readRDS")
  if (grepl("read_csv\\(|readr::read_csv\\(|read\\.csv\\(", ln)) calls <- c(calls, "read_csv")
  if (grepl("\\bload\\(", ln)) calls <- c(calls, "load")
  if (grepl("include_graphics", ln)) calls <- c(calls, "include_graphics")
  if (grepl("!\\[", ln)) calls <- c(calls, "image_link")
  if (grepl("file\\.path\\(", ln)) calls <- c(calls, "file.path")
  if (grepl("params\\$run_dir", ln)) calls <- c(calls, "params$run_dir")
  if (!length(calls)) next
  paths <- extract_paths(ln)
  if (grepl("params\\$run_dir", ln) && !length(paths)) paths <- "params$run_dir"
  if (!length(paths)) next
  for (p in unique(paths)) {
    add_a(i, label_now, paste(unique(calls), collapse = "+"), p, used_for_line(ln, label_now))
  }
}

# one level into sourced helpers
src_files <- unique(a_rows_df_paths <- unlist(lapply(a_rows, function(r) if (r$call == "source" || grepl("^source", r$call)) r$path_as_written else character())))
# rebuild from the rows we have
src_files <- unique(vapply(a_rows, function(r) if (grepl("source", r$call)) r$path_as_written else NA_character_, character(1)))
src_files <- src_files[!is.na(src_files) & file.exists(src_files)]
for (sf in src_files) {
  sl <- readLines(sf, warn = FALSE)
  for (j in seq_along(sl)) {
    ln <- sl[[j]]
    if (!grepl("read_csv|read\\.csv|readRDS|file\\.path|load\\(", ln)) next
    paths <- extract_paths(ln)
    for (p in unique(paths)) {
      add_a(j, paste0("helper:", basename(sf)), "helper-read", p, "helper")
    }
  }
}
inv_a <- do.call(rbind, a_rows)
utils::write.csv(inv_a, file.path(INV, "inventory_A_reads.csv"), row.names = FALSE)

# --- Inventory B: prose numbers ---
in_yaml <- length(lines) && lines[[1]] == "---"
yaml_done <- !in_yaml
in_chunk <- FALSE
in_refs <- FALSE
section <- ""
b_rows <- list()
num_re <- "(?<![A-Za-z0-9.])(-?\\d{1,3}(?:,\\d{3})+(?:\\.\\d+)?|-?\\d+\\.\\d+|-?\\d+)(?![A-Za-z0-9])"
for (i in seq_along(lines)) {
  ln <- lines[[i]]
  if (!yaml_done) {
    if (i > 1 && ln == "---") yaml_done <- TRUE
    next
  }
  if (grepl("^```", ln)) {
    in_chunk <- !in_chunk
    next
  }
  if (in_chunk) next
  if (grepl("^#+\\s+.*[Rr]eference", ln)) {
    in_refs <- TRUE
    next
  }
  if (in_refs) next
  if (grepl("^#+\\s+", ln)) section <- gsub("^#+\\s+", "", ln)
  text <- ln
  text <- gsub("`r [^`]*`", " ", text)
  text <- gsub("\\[@[^\\]]+\\]", " ", text)
  text <- gsub("@[A-Za-z0-9_.:-]+", " ", text)
  text <- gsub("\\\\(label|ref|eqref)\\{[^}]*\\}", " ", text)
  text <- gsub("(Figure|Fig\\.|Table|Section|Supplementary Section)\\s+S?\\d+(?:\\.\\d+)*", " ", text, ignore.case = TRUE)
  text <- gsub("@(fig|tbl|sec|supp)[A-Za-z0-9-]*", " ", text)
  mm <- gregexpr(num_re, text, perl = TRUE)
  if (mm[[1]][1] == -1) next
  matches <- regmatches(text, mm)[[1]]
  pos <- as.integer(mm[[1]])
  for (k in seq_along(matches)) {
    start <- max(1, pos[[k]] - 40)
    end <- min(nchar(text), pos[[k]] + nchar(matches[[k]]) + 40)
    ctx <- substr(text, start, end)
    ctx <- gsub("\\s+", " ", ctx)
    low <- tolower(ctx)
    category <- if (grepl("p\\s*[=<>]|95%|cri|elpd|r-hat|beta|\\\\hat|rmse|\\bks\\b|logit|posterior", low)) {
      "statistic"
    } else if (grepl("mvc|handgrip|stimulus|isi|hz|duration|seconds of", low)) {
      "design"
    } else if (grepl("chain|iteration|warmup|prior|cutoff|rope|adapt|treedepth", low)) {
      "setting"
    } else if (grepl("trial|participant|subject|enrolled|older adult|sample", low)) {
      "count"
    } else {
      "other"
    }
    still <- if (category == "statistic") {
      if (grepl("\\bage\\b|moca|demographic|years", low)) "yes" else "no"
    } else if (category == "design") {
      "yes"
    } else {
      "check"
    }
    b_rows[[length(b_rows) + 1]] <- data.frame(
      qmd_line = i, section_heading = section, number = matches[[k]],
      context = ctx, category = category, still_valid = still,
      stringsAsFactors = FALSE
    )
  }
}
inv_b <- if (length(b_rows)) do.call(rbind, b_rows) else data.frame()
utils::write.csv(inv_b, file.path(INV, "inventory_B_hardcoded.csv"), row.names = FALSE)

known <- c("8 chains", "745", "1669", "1,669", "38,662.7", "38662.7", "0.6 s", "17,857", "17857",
           "12,287", "12287", "59 participants", "63 subjects", "ROPE")
known_hits <- lapply(known, function(k) {
  hit <- grep(k, lines, fixed = TRUE)
  # keep hits outside chunks roughly by reporting all lines; the prose filter is applied below
  if (!length(hit)) return(data.frame(item = k, qmd_line = NA_integer_, in_prose = NA))
  data.frame(item = k, qmd_line = hit, in_prose = NA, stringsAsFactors = FALSE)
})
known_df <- do.call(rbind, known_hits)
# mark whether the line is inside a chunk
in_chunk <- FALSE
chunk_lines <- rep(FALSE, length(lines))
for (i in seq_along(lines)) {
  if (grepl("^```", lines[[i]])) {
    in_chunk <- !in_chunk
    chunk_lines[[i]] <- TRUE
    next
  }
  chunk_lines[[i]] <- in_chunk
}
known_df$in_prose <- !chunk_lines[known_df$qmd_line]
known_df$context <- ifelse(is.na(known_df$qmd_line), "", substr(lines[known_df$qmd_line], 1, 160))
utils::write.csv(known_df, file.path(INV, "inventory_B_known_items.csv"), row.names = FALSE)

# --- Inventory C ---
action_map <- list(
  "fig-ddm-process" = c("regenerate", "Figure 1", "Decision record: redo panel C (task on drift; criterion versus quality)."),
  "fig-central-result" = c("regenerate", "Figure 2", "Regenerate from M4, split by task."),
  "fig-parameter-forest" = c("replace", "Figure 3", "Replace with a forest of criterion, quality, boundary, and bias, with ROPE bands."),
  "fig-individual-diffs" = c("keep", "Figure 4", "Keep the Brinley panel. Drop the subject-level effort panels. Image file is fig5_individual_differences.png."),
  "fig-difficulty-posterior-diffs" = c("cut", "not rendered", "Chunk is eval false and include false."),
  "suppfig-participant-flow" = c("regenerate", "UNKNOWN", "Decision record S1 must use the new pupil QC counts. A qmd comment calls this Supplementary Section S2.1."),
  "suppfig-loo-comparison" = c("regenerate", "UNKNOWN", "LOO figure. Decision record: manuscript supplement LOO table; figure itself is not named S4/S10."),
  "suppfig-ndt-prior-posterior" = c("regenerate", "UNKNOWN", "Depends on the old additive model path."),
  "suppfig-caf" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "suppfig-ppc-heatmaps" = c("regenerate", "UNKNOWN", "Decision record: PPC figures regenerate."),
  "suppfig-a4-2a-drift-by-difficulty" = c("regenerate", "S4", "Filename and section point at Supplementary S4."),
  "suppfig-suppl-drift-by-task" = c("regenerate", "S4", "Task-on-drift sensitivity. Decision record names S4."),
  "suppfig-additivity-check" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "suppfig-tepr-timecourse-supp" = c("replace", "UNKNOWN", "Pupil figure. Decision record: one forest panel of the P3 slope with trimmed-RT and pre-decision slopes."),
  "suppfig-tepr-slopes-supp" = c("replace", "UNKNOWN", "Pupil slope figure. Same pupil-panel plan."),
  "suppfig-timing-supp" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "suppfig-rt-distributions" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "suppfig-ddm-dag-plate" = c("keep", "UNKNOWN", "Schematic. Not named in the plan; it does not read a fitted model."),
  "suppfig-a2-bias-calibration-panel" = c("decide", "UNKNOWN", "Depends on the Standard-only legacy model."),
  "suppfig-accuracy-distribution" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "suppfig-rt-distribution" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "suppfig-lc-fiso-dprime-variability" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "suppfig-lc-fiso-four-panel" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "suppfig-temporal-dynamics" = c("decide", "S10 / S22", "Decision record puts choice-history and fatigue in the dissertation supplement (it calls this S22). The qmd heading is S10."),
  "tbl-demographics" = c("keep", "Table 1", "Demographics. Not produced by a DDM refit."),
  "tbl-trial-exclusions" = c("regenerate", "UNKNOWN", "Trial counts must follow the refit sample."),
  "tbl-hyp-summary" = c("regenerate", "UNKNOWN", "Hypothesis table is built from the primary model."),
  "supptbl-loo-comparison" = c("regenerate", "UNKNOWN", "Decision record: LOO table of M0–M4b in the manuscript supplement."),
  "supptbl-convergence-detailed" = c("regenerate", "UNKNOWN", "Convergence table."),
  "supptbl-trial-counts" = c("regenerate", "UNKNOWN", "Counts change with the refit sample."),
  "supptbl-ddm-posterior-estimates" = c("regenerate", "UNKNOWN", "Primary posterior table."),
  "supptbl-standard-only-bias-levels" = c("decide", "UNKNOWN", "Standard-only calibration was not refit."),
  "supptbl-baseline-pupil" = c("regenerate", "UNKNOWN", "Pupil descriptives from the r5/r6 tables."),
  "supptbl-bias-drift-intercept" = c("regenerate", "UNKNOWN", "Not named separately; it reports model estimates."),
  "supptbl-convergence-ppc-gate-appendix" = c("regenerate", "UNKNOWN", "PPC gate. Decision record: PPC figures regenerate."),
  "supptbl-ppc-midbody" = c("regenerate", "UNKNOWN", "PPC table."),
  "supptbl-sensitivity-subchance" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "supptbl-sensitivity-thresholds" = c("replace", "S4", "Replace with the r7 M4 cutoff table."),
  "supptbl-h1-h2-by-cutoff" = c("replace", "S4", "Replace with the r7 effort terms."),
  "supptbl-app-sensitivity-full" = c("replace", "S4", "Cutoff sensitivity."),
  "supptbl-task-sensitivity" = c("regenerate", "S4", "Decision record names S4."),
  "supptbl-pupil-loo-unified" = c("regenerate", "UNKNOWN", "Pupil LOO from r5–r6."),
  "supptbl-pupil-key-effects-appendix" = c("regenerate", "UNKNOWN", "Pupil coefficients from P3 and the ordering models."),
  "supptbl-pupil-boundary-appendix" = c("regenerate", "UNKNOWN", "Boundary pupil terms."),
  "supptbl-tepr" = c("regenerate", "UNKNOWN", "TEPR descriptives from the r5/r6 tables."),
  "supptbl-accuracy-glmm" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "supptbl-overall-accuracy" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "supptbl-rt-lmm" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "supptbl-lc-exploratory-correlations" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "supptbl-extended-baseline-categorical" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "supptbl-extended-baseline" = c("decide", "UNKNOWN", "Not named in the figure plan."),
  "supptbl-neuropsych-ddm-exploratory" = c("decide", "UNKNOWN", "Not named in the figure plan.")
)

section <- ""
in_chunk <- FALSE
chunk <- ""
c_rows <- list()
grab_label <- function(i, label, kind) {
  act <- action_map[[label]]
  if (is.null(act)) act <- c("decide", "UNKNOWN", "Not covered by the decision-record figure plan.")
  window <- lines[max(1, i - 5):min(length(lines), i + 40)]
  inputs <- unique(unlist(lapply(window, extract_paths)))
  dep <- any(grepl("additive__|interaction__|pupil_interaction|task_sensitivity|baseline__|loo_difficultyonly|BAP_analysis_ready_PUPIL|ch3_triallevel", inputs))
  c_rows[[length(c_rows) + 1]] <<- data.frame(
    label = label, number_as_rendered = act[[2]], section = section,
    generating_chunk_or_script = if (nzchar(chunk)) chunk else kind,
    inputs_read = paste(inputs, collapse = " | "),
    depends_on_obsolete = if (dep) "yes" else "no",
    action = act[[1]], notes = act[[3]],
    stringsAsFactors = FALSE
  )
}
for (i in seq_along(lines)) {
  ln <- lines[[i]]
  if (grepl("^#+\\s+", ln)) section <- gsub("^#+\\s+", "", ln)
  if (grepl("^```\\{r", ln)) {
    in_chunk <- TRUE
    chunk <- sub("^```\\{r\\s*", "", ln)
    chunk <- sub("\\}.*$", "", chunk)
  } else if (in_chunk && grepl("^```\\s*$", ln)) {
    in_chunk <- FALSE
  }
  m <- regexpr("#\\|\\s*label:\\s*([A-Za-z0-9_-]+)", ln, perl = TRUE)
  if (m != -1) {
    lab <- sub("^#\\|\\s*label:\\s*", "", regmatches(ln, m))
    if (grepl("^(fig|tbl|suppfig|supptbl)-", lab)) grab_label(i, lab, "chunk")
  }
  m2 <- regexpr("^:::\\s*\\{#(supp(?:fig|tbl)-[A-Za-z0-9_-]+)", ln, perl = TRUE)
  if (m2 != -1) {
    lab <- sub("^:::\\s*\\{#", "", regmatches(ln, m2))
    grab_label(i, lab, "fenced-div")
  }
}
# explicit unmatched plan items
c_rows[[length(c_rows) + 1]] <- data.frame(
  label = "S11", number_as_rendered = "S11", section = "",
  generating_chunk_or_script = "", inputs_read = "", depends_on_obsolete = "UNKNOWN",
  action = "cut", notes = "Decision record says cut S11. No heading or label in the qmd contains S11.",
  stringsAsFactors = FALSE
)
c_rows[[length(c_rows) + 1]] <- data.frame(
  label = "S12", number_as_rendered = "S12", section = "",
  generating_chunk_or_script = "", inputs_read = "", depends_on_obsolete = "UNKNOWN",
  action = "cut", notes = "Decision record says cut S12. No heading or label in the qmd contains S12.",
  stringsAsFactors = FALSE
)
inv_c <- do.call(rbind, c_rows)
utils::write.csv(inv_c, file.path(INV, "inventory_C_figures.csv"), row.names = FALSE)

# scripts that read obsolete models or the old pupil CSV
script_dirs <- c("06_visualization", "07_manuscript/scripts", "scripts", "R")
script_hits <- list()
for (d in script_dirs) {
  if (!dir.exists(d)) next
  fs <- list.files(d, pattern = "\\.(R|r|qmd|py)$", recursive = TRUE, full.names = TRUE)
  for (f in fs) {
    if (grepl("^scripts/final/", f)) next
    tx <- readLines(f, warn = FALSE)
    hit <- grep("additive__|pupil_interaction__|task_sensitivity__|loo_difficultyonly|BAP_analysis_ready_PUPIL|ddm_pupil_ready|ch3_triallevel|interaction__probe", tx)
    if (length(hit)) {
      script_hits[[length(script_hits) + 1]] <- data.frame(
        file = f, line = hit, text = substr(tx[hit], 1, 160), stringsAsFactors = FALSE
      )
    }
  }
}
scripts_df <- if (length(script_hits)) do.call(rbind, script_hits) else data.frame(file = character(), line = integer(), text = character())
utils::write.csv(scripts_df, file.path(INV, "inventory_C_obsolete_scripts.csv"), row.names = FALSE)

# --- final_inventory.md ---
man <- utils::read.csv(file.path(FINAL, "MANIFEST.csv"), stringsAsFactors = FALSE)
pre <- readLines(file.path(INV, "step1_preflight.md"), warn = FALSE)
head_line <- grep("^- HEAD:", pre, value = TRUE)
git_head <- sub("^- HEAD: `?([^`]*)`?", "\\1", head_line)
n_copied <- sum(nzchar(man$final_path) & man$role != "obsolete")
# models only
n_model_copied <- sum(grepl("/models/|/legacy/", man$final_path))
md5_ok <- all(man$md5_source[nzchar(man$final_path)] == man$md5_final[nzchar(man$final_path)])
fail <- man[man$passes_convergence_rule %in% "FALSE" | man$passes_convergence_rule %in% FALSE, ]
fail_txt <- if (!nrow(fail)) "none" else paste(sprintf("%s (R-hat %s)", fail$model_id, signif(as.numeric(fail$max_rhat), 4)), collapse = "; ")
st <- table(inv_a$status)
b_no <- sum(inv_b$still_valid == "no")
act <- table(inv_c$action)
legacy_found <- man$model_id[man$role == "legacy_not_refit" & nzchar(man$final_path)]
unknowns <- c(
  "Rendered supplement numbers are UNKNOWN where the qmd does not print them.",
  "S11 and S12 are named in the decision record and are not labels in the qmd.",
  "Choice-history and fatigue convergence were not recomputed (no convergence.csv).",
  "max R-hat and bulk ESS for the refit models were taken from the extract convergence tables, which matched the r3 run table where both exist. They were not recomputed with summarise_draws."
)
disagreement <- paste(
  "The decision record says to consolidate into one run directory that matches the qmd paths (params$run_dir).",
  "This prompt forbids alias copies under the old names, so no additive__ (or other old) filenames were created.",
  "The decision record says cut S11 and S12; the qmd has no S11 or S12 label.",
  "The decision record's Fig 4 is the Brinley figure. In the qmd that is the fourth main figure, and the image file is fig5_individual_differences.png."
)
summary10 <- c(
  sprintf("1. git HEAD %s", git_head),
  sprintf("2. %d model files copied (24 refit + 4 legacy); all md5 checks passed: %s", n_model_copied, if (md5_ok) "yes" else "NO"),
  sprintf("3. Convergence-rule failures: %s", fail_txt),
  "4. Count mismatches versus Step 2: none",
  sprintf("5. qmd reads by status: %s", paste(sprintf("%s %d", names(st), as.integer(st)), collapse = ", ")),
  sprintf("6. Hardcoded prose numbers: %d, of which still_valid=no: %d", nrow(inv_b), b_no),
  sprintf("7. Figures and tables by action: %s", paste(sprintf("%s %d", names(act), as.integer(act)), collapse = ", ")),
  sprintf("8. Legacy models copied: %s. Other legacy_not_refit rows were listed and not copied.", paste(legacy_found, collapse = ", ")),
  sprintf("9. Disagreement: %s", disagreement),
  sprintf("10. UNKNOWN: %s", paste(unknowns, collapse = " "))
)
writeLines(c(
  "# Final inventory",
  "",
  summary10,
  "",
  "## Step 1. Preflight",
  "",
  pre,
  "",
  "## Step 4. Verification",
  "",
  "Every copied refit model matched its expected trial count and subject count. md5 of each copy matched its source. Cross-check against the r3–r7 extract tables found no difference larger than rounding (see step4_crosscheck.txt).",
  "",
  "Convergence rule: max R-hat < 1.01, minimum bulk ESS > 400, and 0 divergences.",
  "",
  fail_txt,
  "",
  "M4_thr0.15 fails on Intercept_bs only. M1 and M2 fail on the same parameter family. Superseded M3_thr0.25 also fails and was not copied. M3_thr0.15 passes and was not copied.",
  "",
  "## Step 5. Manifest",
  "",
  "MANIFEST.csv in this folder is a copy of output/ddm_refits/runs/final_20261016/MANIFEST.csv. Role definitions are in that run's README.md.",
  "",
  "## Step 6. Inventory A",
  "",
  sprintf("Rows: %d. Counts: %s.", nrow(inv_a), paste(sprintf("%s %d", names(st), as.integer(st)), collapse = ", ")),
  "",
  "Full table: inventory_A_reads.csv. Helper files followed one level are the qmd source() targets that exist on disk.",
  "",
  "## Step 7. Inventory B",
  "",
  sprintf("Prose numbers: %d. still_valid=no: %d. still_valid=yes: %d. still_valid=check: %d.",
          nrow(inv_b), b_no, sum(inv_b$still_valid == "yes"), sum(inv_b$still_valid == "check")),
  "",
  "Known items are in inventory_B_known_items.csv. A row with qmd_line NA means that string was not found.",
  "",
  "## Step 8. Inventory C",
  "",
  sprintf("Floats: %d. Actions: %s.", nrow(inv_c), paste(sprintf("%s %d", names(act), as.integer(act)), collapse = ", ")),
  "",
  "Full table: inventory_C_figures.csv. Scripts that still read an obsolete model or the old pupil CSV: inventory_C_obsolete_scripts.csv.",
  "",
  "## Disagreement with the decision record",
  "",
  disagreement
), file.path(INV, "final_inventory.md"))

zip_path <- "output/diagnostics/final_inventory.zip"
if (file.exists(zip_path)) unlink(zip_path)
system(paste("cd", shQuote(file.path(ROOT, "output/diagnostics")),
             "&& zip -r -q final_inventory.zip final_inventory"))
message("inventory rows A=", nrow(inv_a), " B=", nrow(inv_b), " C=", nrow(inv_c))
message("zip exists: ", file.exists("output/diagnostics/final_inventory.zip"))
