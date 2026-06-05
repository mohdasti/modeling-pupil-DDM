# colors_manuscript.R — single source of truth for all figure colors
# Source at top of every figure script: source(here::here("R", "colors_manuscript.R"))

cond_colors <- c(
  "Standard/Low"  = "#B8BCC4",
  "Standard/High" = "#6B7280",
  "Easy/Low"      = "#5DADE2",
  "Easy/High"     = "#2E86AB",
  "Hard/Low"      = "#EC70AB",
  "Hard/High"     = "#A23B72"
)
diff_colors <- c("Standard" = "#8B9099", "Easy" = "#2E86AB", "Hard" = "#A23B72")
effort_colors <- c("Low" = "#5DADE2", "High" = "#A23B72")
task_colors   <- c("ADT" = "#1D9E75", "VDT" = "#6B4F8C")
param_colors  <- c("v" = "#1D9E75", "a" = "#6B4F8C", "z" = "#8B6914", "t0" = "#6B7280")
param_labels  <- c("v"="Drift rate (v)", "a"="Boundary separation (a)",
                   "z"="Bias (z)", "t0"="Non-decision time (t\u2080)")
pupil_colors  <- c("baseline" = "#8B9099", "tepr" = "#C4681A", "total_auc" = "#3D6B8C")
stat_colors   <- c("prior"="#B0B8C0", "posterior"="#374151", "empirical"="#1F2937",
                   "predicted"="#A23B72", "zero_line"="#9CA3AF")
model_colors  <- c("history" = "#1D9E75", "wsls" = "#B8860B")
