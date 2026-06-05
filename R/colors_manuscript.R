# colors_manuscript.R
# Single source of truth for all figure colors.
# Source this file at the top of every figure script:
#   source(here::here("R", "colors_manuscript.R"))

# ── Tier 1: Experimental conditions (Difficulty × Effort) ─────────────────────
# Hue families: blue (Easy), pink (Hard), gray (Standard)
# Lightness encodes effort: light = Low (5% MVC), dark = High (40% MVC)

cond_colors <- c(
  "Standard/Low"  = "#B8BCC4",   # light neutral gray
  "Standard/High" = "#6B7280",   # dark neutral gray
  "Easy/Low"      = "#5DADE2",   # light blue
  "Easy/High"     = "#2E86AB",   # dark blue
  "Hard/Low"      = "#EC70AB",   # light pink
  "Hard/High"     = "#A23B72"    # dark magenta
)

# Difficulty only (effort pooled or on x-axis / faceted)
diff_colors <- c(
  "Standard" = "#8B9099",
  "Easy"     = "#2E86AB",
  "Hard"     = "#A23B72"
)

# Effort only (difficulty pooled or on x-axis)
effort_colors <- c(
  "Low"  = "#5DADE2",   # 5% MVC
  "High" = "#A23B72"    # 40% MVC
)

# ── Tier 2: Task modality ──────────────────────────────────────────────────────
# Hue families: teal (ADT), purple (VDT)
# Chosen to be hue-distinct from Tier 1 (no blue, no pink)

task_colors <- c(
  "ADT" = "#1D9E75",   # mid teal
  "VDT" = "#6B4F8C"    # mid purple
)

# ── Tier 3: DDM parameters (fixed across all analytic figures) ─────────────────
# Each parameter gets a unique hue family not used in Tier 1 or Tier 2.
# Use these whenever coloring by parameter type, not by condition.

param_colors <- c(
  "v"  = "#1D9E75",   # Drift rate       — teal   (evidence flow)
  "a"  = "#6B4F8C",   # Boundary sep.    — purple  (caution/threshold)
  "z"  = "#8B6914",   # Bias             — dark gold (criterion, no valence)
  "t0" = "#6B7280"    # Non-decision t.  — gray    (peripheral timing)
)

# Human-readable aliases (use in legend labels)
param_labels <- c(
  "v"  = "Drift rate (v)",
  "a"  = "Boundary separation (a)",
  "z"  = "Bias (z)",
  "t0" = "Non-decision time (t\u2080)"
)

# ── Tier 4: Pupil / physiology ─────────────────────────────────────────────────
pupil_colors <- c(
  "baseline"  = "#8B9099",   # tonic baseline (B0)
  "tepr"      = "#C4681A",   # TEPR / cognitive AUC — warm amber
  "total_auc" = "#3D6B8C"    # Total AUC (only when shown alongside TEPR)
)

# ── Tier 5: Statistical / model layers ────────────────────────────────────────
stat_colors <- c(
  "prior"      = "#B0B8C0",
  "posterior"  = "#374151",   # use #2E86AB only if no Tier 1 blue in same panel
  "empirical"  = "#1F2937",
  "predicted"  = "#A23B72",
  "zero_line"  = "#9CA3AF"
)

# CrI / HDI band: same hue as the estimate line at 20% alpha.
# Apply in ggplot with: fill = alpha(stat_colors["posterior"], 0.2)

# ── Tier 6: Exploratory models ─────────────────────────────────────────────────
model_colors <- c(
  "history" = "#1D9E75",   # History model — teal (consistent with Drift v)
  "wsls"    = "#B8860B"    # WSLS model    — dark goldenrod (distinct from gold Bias)
)

# ── Utility: retire list ───────────────────────────────────────────────────────
# These hex values must not appear in any new or edited figure script.
# Search the repo for each and replace per the mapping below.

RETIRED_HEX <- list(
  "#2166ac"  = "use effort_colors['High'] or param_colors['v']",
  "#4393C3"  = "use effort_colors['Low'] or cond_colors['Easy/Low']",
  "#4472C4"  = "use cond_colors['Easy/High']",
  "#5DA5DA"  = "use cond_colors['Easy/Low']",
  "#d6604d"  = "use effort_colors['High'] or param_colors['a']",
  "#D6604D"  = "use effort_colors['High'] or param_colors['a']",
  "#B276B2"  = "use param_colors['a'] (purple)",
  "#4DAC26"  = "use param_colors['z'] (dark gold)",
  "#2ECC71"  = "use param_colors['z'] (dark gold)",
  "#1f78b4"  = "use task_colors['ADT']",
  "#DC143C"  = "use task_colors['VDT']"
)
