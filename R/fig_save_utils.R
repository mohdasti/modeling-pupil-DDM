# fig_save_utils.R — save figures to manuscript_palette (+ optional legacy path)
# Source after colors_manuscript.R:
#   source(here::here("R", "fig_save_utils.R"))

save_manuscript_fig <- function(plot, name, width, height, dpi = 300,
                                out_dir = NULL, also_legacy = TRUE) {
  if (is.null(out_dir)) {
    out_dir <- file.path(here::here(), "output", "figures", "manuscript_palette")
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  png_path <- file.path(out_dir, paste0(name, ".png"))
  pdf_path <- file.path(out_dir, paste0(name, ".pdf"))
  ggsave(png_path, plot, width = width, height = height, dpi = dpi)
  ggsave(pdf_path, plot, width = width, height = height)
  if (also_legacy) {
    legacy_dir <- file.path(here::here(), "output", "figures")
    dir.create(legacy_dir, recursive = TRUE, showWarnings = FALSE)
    ggsave(file.path(legacy_dir, paste0(name, ".png")), plot, width = width, height = height, dpi = dpi)
    ggsave(file.path(legacy_dir, paste0(name, ".pdf")), plot, width = width, height = height)
  }
  message("Saved: ", name, " -> ", out_dir)
  invisible(plot)
}
