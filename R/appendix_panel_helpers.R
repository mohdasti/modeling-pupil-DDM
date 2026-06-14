#' Retrieve a ggplot stored by a hidden appendix build chunk.
appendix_get_stored_plot <- function(obj_name) {
  if (exists(obj_name, envir = .GlobalEnv, inherits = FALSE)) {
    return(get(obj_name, envir = .GlobalEnv, inherits = FALSE))
  }
  if (exists(obj_name, inherits = TRUE)) {
    return(get(obj_name, inherits = TRUE))
  }
  NULL
}

#' Reserve top margin and optional subtitle for patchwork panel tags.
appendix_panel_prepare <- function(plot, subtitle = NULL) {
  if (!is.null(subtitle) && nzchar(subtitle)) {
    plot <- plot +
      labs(title = subtitle) +
      theme(
        plot.title = element_text(
          size = 11,
          face = "bold",
          hjust = 0,
          margin = margin(t = 2, b = 4)
        ),
        plot.title.position = "plot"
      )
  }
  plot +
    theme(plot.margin = margin(t = 18, r = 6, b = 4, l = 6))
}

#' Combine ggplot panels with patchwork A/B tags and one shared legend.
appendix_combine_panels <- function(
    plots,
    ncol = 1L,
    heights = NULL,
    widths = NULL,
    subtitles = NULL,
    hide_legend_except_last = TRUE
) {
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    stop("patchwork is required for appendix panel figures.", call. = FALSE)
  }
  if (is.null(subtitles)) {
    subtitles <- rep(NULL, length(plots))
  }
  prepared <- Map(appendix_panel_prepare, plots, subtitles)
  if (isTRUE(hide_legend_except_last) && length(prepared) > 1L) {
    prepared[-length(prepared)] <- lapply(
      prepared[-length(prepared)],
      function(p) p + theme(legend.position = "none")
    )
  } else if (identical(hide_legend_except_last, FALSE) && length(prepared) > 1L) {
    prepared <- lapply(
      prepared,
      function(p) p + theme(legend.position = "none")
    )
  }

  layout_args <- list(guides = "collect", tag_level = "new")
  if (!is.null(heights)) layout_args$heights <- heights
  if (!is.null(widths)) layout_args$widths <- widths

  combined <- if (ncol > 1L) {
    Reduce(`+`, prepared)
  } else {
    Reduce(`/`, prepared)
  }
  combined <- combined + do.call(patchwork::plot_layout, layout_args)
  combined & theme(
    plot.tag = element_text(size = 13, face = "bold"),
    plot.tag.position = c(0.01, 0.99),
    legend.position = "bottom",
    legend.box = "horizontal"
  )
}

#' Always print a ggplot (or a placeholder) so Quarto registers the figure label.
appendix_emit_figure <- function(plot, context = "Figure") {
  if (is.null(plot) || !inherits(plot, "ggplot")) {
    message("Appendix figure unavailable (", context, "); rendering placeholder.")
    plot <- ggplot2::ggplot() +
      ggplot2::annotate(
        "text", x = 0.5, y = 0.5, size = 4,
        label = paste0(context, " unavailable.")
      ) +
      ggplot2::theme_void()
  }
  print(plot)
  invisible(plot)
}

#' Print a ggplot stored in the global environment by a hidden build chunk.
appendix_print_stored_figure <- function(obj_name, save_name = NULL, width = NULL, height = NULL) {
  plt <- appendix_emit_figure(appendix_get_stored_plot(obj_name), obj_name)
  if (!is.null(save_name) && exists("save_manuscript_fig", mode = "function")) {
    save_manuscript_fig(plt, save_name, width %||% 8, height %||% 6)
  }
  invisible(plt)
}
