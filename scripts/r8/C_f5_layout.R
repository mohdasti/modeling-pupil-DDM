# Part C. F5 from the r8 T8 table. Group names sit in the left margin, above their rows.
# Rscript scripts/r8/C_f5_layout.R

options(warn = 1)
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(readr)
  library(patchwork)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
source(file.path(ROOT, "R", "colors_manuscript.R"))
source(file.path(ROOT, "R", "fig_save_utils.R"))

TAB <- "output/ddm_refits/runs/final_20261016/tables/final"
FIG <- "output/ddm_refits/runs/final_20261016/figures/final_r8"
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)

t8 <- read_csv(file.path(TAB, "T8_pupil_ordering.csv"), show_col_types = FALSE)
stopifnot(setequal(t8$model, c("P3", "P3_rt", "P5", "P6", "P7", "P8")))

labels <- c(
  P3 = "Decision-window TEPR (0.3\u20133.3 s after probe)",
  P3_rt = "Decision-window TEPR, slowest 20% removed",
  P7 = "Pre-response window (0.5 s)",
  P6 = "Previous-trial TEPR",
  P5 = "Pre-squeeze baseline pupil",
  P8 = "Grip-period pupil"
)
# Top to bottom.
sequence <- c(
  "hdr_within", "P3", "P3_rt", "P7",
  "hdr_before", "P6", "P5", "P8"
)
header_of <- c(
  hdr_within = "Within the current trial",
  hdr_before = "Before the current decision"
)

fig <- t8 %>%
  mutate(
    model = as.character(model),
    row_id = model,
    row_lab = unname(labels[model]),
    is_header = FALSE,
    pct = pct_change_median,
    lo = pct_change_q2.5,
    hi = pct_change_q97.5,
    elpd_lab = sprintf("%+.1f \u00b1 %.1f", delta_elpd_vs_baseline, se_delta_elpd)
  )
headers <- tibble(
  model = c("hdr_within", "hdr_before"),
  row_id = c("hdr_within", "hdr_before"),
  row_lab = unname(header_of),
  is_header = TRUE,
  pct = NA_real_, lo = NA_real_, hi = NA_real_, elpd_lab = ""
)
fig <- bind_rows(fig, headers) %>%
  mutate(row_id = factor(row_id, levels = rev(sequence)))

theme_ms <- function() {
  theme_classic(base_size = 11) +
    theme(
      panel.grid = element_blank(),
      legend.position = "none",
      plot.caption = element_text(hjust = 0, size = 9, color = "#374151")
    )
}
axis_face <- ifelse(levels(fig$row_id) %in% names(header_of), "bold", "plain")
axis_lab <- ifelse(
  levels(fig$row_id) %in% names(header_of),
  unname(header_of[levels(fig$row_id)]),
  unname(labels[levels(fig$row_id)])
)

f5_forest <- ggplot(fig, aes(x = pct, y = row_id)) +
  geom_vline(xintercept = 0, color = stat_colors["zero_line"]) +
  geom_errorbar(
    data = function(d) d[!d$is_header, ],
    aes(xmin = lo, xmax = hi),
    orientation = "y", width = 0.18, linewidth = 0.45, color = "#374151"
  ) +
  geom_point(
    data = function(d) d[!d$is_header, ],
    size = 2.2, color = "#111827"
  ) +
  scale_y_discrete(labels = axis_lab, drop = FALSE) +
  labs(x = "Change in boundary separation per SD of predictor (%)", y = NULL) +
  theme_ms() +
  theme(axis.text.y = element_text(face = axis_face, color = "#111827"))

f5_elpd <- ggplot(fig, aes(x = 1, y = row_id, label = elpd_lab)) +
  geom_text(data = function(d) d[!d$is_header, ], size = 3.1, hjust = 0.5) +
  scale_y_discrete(labels = axis_lab, drop = FALSE) +
  scale_x_continuous(limits = c(0.55, 1.45), expand = c(0, 0)) +
  labs(title = "\u0394ELPD \u00b1 SE", x = NULL, y = NULL) +
  theme_ms() +
  theme(
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line = element_blank(),
    axis.ticks.x = element_blank(),
    axis.text.x = element_blank(),
    plot.title = element_text(size = 11, face = "bold", hjust = 0.5)
  )

f5 <- f5_forest + f5_elpd + plot_layout(widths = c(4.6, 1.15)) +
  plot_annotation(caption = "\u0394ELPD relative to a baseline model fit to the same trials.")

save_manuscript_fig(f5, "F5_pupil_boundary", 10.4, 5.4, dpi = 300, out_dir = FIG, also_legacy = FALSE)
if (capabilities("cairo")) {
  ggsave(
    file.path(FIG, "F5_pupil_boundary.pdf"), f5,
    width = 10.4, height = 5.4, device = grDevices::cairo_pdf
  )
}
writeLines(
  paste(
    "tables/final/T8_pupil_ordering.csv from r8_20261017_015218.",
    "Group names are y-axis headings in the left margin, above the rows in that group.",
    "P3 is compared with the full-sample P0. P5 is compared with P0_base.",
    "P3_rt, P6, P7, and P8 use P0_rt, P0_lag, P0_pre, and P0_grip.",
    "The right-hand column is delta ELPD to one decimal place, plus or minus its standard error.",
    sep = " "
  ),
  file.path(FIG, "F5_pupil_boundary_source.txt")
)
message("F5 written")
