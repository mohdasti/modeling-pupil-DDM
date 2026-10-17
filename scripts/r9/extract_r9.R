# After the r9 fit. Reads output/ddm_refits/runs/r9_latest_run_id.txt unless
# PUPIL_RUN_DIR is already set. Does not refit.
id_file <- "output/ddm_refits/runs/r9_latest_run_id.txt"
if (!nzchar(Sys.getenv("PUPIL_RUN_DIR", ""))) {
  if (!file.exists(id_file)) stop("Missing ", id_file)
  Sys.setenv(PUPIL_RUN_DIR = file.path("output/ddm_refits/runs", readLines(id_file, n = 1L)))
}
source("scripts/r8/E_extract_summaries.R")
