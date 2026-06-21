# CONSORT-inspired participant / analytic-sample flow diagram (Chapter 3 DDM).

flow_box <- function(id, cx, cy, w, h, label, fill, border, size = 3.1) {
  tibble::tibble(
    id = id, x = cx, y = cy, w = w, h = h,
    label = label, fill = fill, border = border, size = size
  )
}

flow_edge <- function(from_id, to_id, boxes, style = "straight") {
  f <- boxes[boxes$id == from_id, , drop = FALSE]
  t <- boxes[boxes$id == to_id, , drop = FALSE]
  if (!nrow(f) || !nrow(t)) {
    return(NULL)
  }
  tibble::tibble(
    from_id = from_id,
    to_id = to_id,
    style = style,
    x = f$x[1],
    y = f$y[1] - f$h[1] / 2,
    xend = t$x[1],
    yend = t$y[1] + t$h[1] / 2
  )
}

flow_edges_for <- function(pairs, boxes) {
  out <- lapply(
    seq_len(nrow(pairs)),
    function(i) {
      flow_edge(pairs$from[i], pairs$to[i], boxes, pairs$style[i])
    }
  )
  dplyr::bind_rows(out)
}

draw_flow_edges <- function(edges) {
  if (!nrow(edges)) {
    return(list())
  }
  straight <- edges[edges$style == "straight", , drop = FALSE]
  merge <- edges[edges$style == "merge", , drop = FALSE]

  layers <- list()
  if (nrow(straight)) {
    layers[[length(layers) + 1L]] <- ggplot2::geom_segment(
      data = straight,
      ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
      colour = "#6B7280",
      linewidth = 0.45,
      arrow = grid::arrow(length = grid::unit(0.12, "cm"), type = "closed")
    )
  }
  if (nrow(merge)) {
    merge <- merge %>%
      dplyr::mutate(
        y_mid = y - 0.35,
        x_mid = xend
      )
    layers[[length(layers) + 1L]] <- ggplot2::geom_segment(
      data = merge,
      ggplot2::aes(x = x, y = y, xend = x, yend = y_mid),
      colour = "#6B7280",
      linewidth = 0.45
    )
    layers[[length(layers) + 1L]] <- ggplot2::geom_segment(
      data = merge,
      ggplot2::aes(x = x, y = y_mid, xend = x_mid, yend = y_mid),
      colour = "#6B7280",
      linewidth = 0.45
    )
    layers[[length(layers) + 1L]] <- ggplot2::geom_segment(
      data = merge,
      ggplot2::aes(x = x_mid, y = y_mid, xend = xend, yend = yend),
      colour = "#6B7280",
      linewidth = 0.45,
      arrow = grid::arrow(length = grid::unit(0.12, "cm"), type = "closed")
    )
  }
  layers
}

plot_ch3_participant_flow <- function(flow, task_colors = NULL) {
  if (is.null(task_colors)) {
    if (file.exists(file.path(getOption("ch3.repo_root", "."), "R", "colors_manuscript.R"))) {
      source(file.path(getOption("ch3.repo_root", "."), "R", "colors_manuscript.R"), local = TRUE)
    }
    if (!exists("task_colors")) {
      task_colors <- c(ADT = "#1D9E75", VDT = "#6B4F8C")
    }
  }

  adt_col <- unname(task_colors["ADT"])
  vdt_col <- unname(task_colors["VDT"])
  excl_fill <- "#F3F4F6"
  excl_border <- "#9CA3AF"
  beh_fill <- "#EEF6FF"
  pupil_fill <- "#F4F0FA"
  pooled_fill <- "#FFFBEB"
  text_col <- "#1F2937"

  thr_label <- sprintf("%.2f", flow$primary_thr)
  adt_beh <- flow$behavioral$adt
  vdt_beh <- flow$behavioral$vdt
  adt_pup <- flow$pupil$adt
  vdt_pup <- flow$pupil$vdt

  adt_subs_excl <- adt_beh$n_sub - adt_pup$n_sub
  vdt_subs_excl <- vdt_beh$n_sub - vdt_pup$n_sub

  center_x <- 2.0
  adt_x <- 0.85
  vdt_x <- 3.15
  excl_x <- 3.85
  bw <- 0.88
  bw_lg <- 1.35
  bh_sm <- 0.52
  bh_md <- 0.62
  bh_lg <- 0.74

  y_enroll <- 11.0
  y_excl_enroll <- 9.55
  y_cohort <- 8.15
  y_rt <- 6.85
  y_beh_hdr <- 5.95
  y_beh <- 4.85
  y_pup_ex <- 3.55
  y_pup <- 2.35
  y_pool <- 0.95

  boxes <- dplyr::bind_rows(
    flow_box(
      "enrolled", center_x, y_enroll, bw_lg, bh_sm,
      sprintf("Enrolled\nN = %s", format_flow_n(flow$enrolled)),
      "#FFFFFF", "#374151", 3.35
    ),
    flow_box(
      "post_excl", excl_x, y_excl_enroll, bw, bh_lg,
      sprintf(
        "Excluded post-enrollment\nn = %s\n(MCI; essential tremor)",
        format_flow_n(flow$post_enroll_excluded)
      ),
      excl_fill, excl_border, 2.85
    ),
    flow_box(
      "cohort", center_x, y_cohort, bw_lg, bh_sm,
      sprintf("Analytic cohort\nN = %s", format_flow_n(flow$analytic_cohort)),
      "#FFFFFF", "#374151", 3.35
    ),
    flow_box(
      "rt_excl", excl_x, y_rt, bw, bh_lg,
      sprintf(
        "Cue-locked RT excluded\nn = %s trials\n(< %s s)",
        format_flow_n(flow$trials_rt_excluded),
        thr_label
      ),
      excl_fill, excl_border, 2.85
    ),
    flow_box(
      "beh_pool", center_x, y_rt, bw_lg, bh_md,
      sprintf(
        "Behavioral trials retained\nn = %s\n(%s participants;\n%s collected pre-RT)",
        format_flow_n(flow$trials_behavioral),
        format_flow_n(flow$subs_behavioral),
        format_flow_n(flow$trials_collected)
      ),
      beh_fill, "#2563EB", 2.85
    ),
    flow_box(
      "beh_adt", adt_x, y_beh, bw, bh_md,
      sprintf(
        "Primary behavioral DDM\nN = %s\nn = %s trials",
        format_flow_n(adt_beh$n_sub),
        format_flow_n(adt_beh$n_trials)
      ),
      beh_fill, adt_col, 2.95
    ),
    flow_box(
      "beh_vdt", vdt_x, y_beh, bw, bh_md,
      sprintf(
        "Primary behavioral DDM\nN = %s\nn = %s trials",
        format_flow_n(vdt_beh$n_sub),
        format_flow_n(vdt_beh$n_trials)
      ),
      beh_fill, vdt_col, 2.95
    ),
    flow_box(
      "pup_ex_adt", adt_x, y_pup_ex, bw, bh_lg,
      sprintf(
        "Excluded (pupil QC)\nn = %s participants\n(%s trials)",
        format_flow_n(adt_subs_excl),
        format_flow_n(adt_beh$n_trials - adt_pup$n_trials)
      ),
      excl_fill, excl_border, 2.75
    ),
    flow_box(
      "pup_ex_vdt", vdt_x, y_pup_ex, bw, bh_lg,
      sprintf(
        "Excluded (pupil QC)\nn = %s participants\n(%s trials)",
        format_flow_n(vdt_subs_excl),
        format_flow_n(vdt_beh$n_trials - vdt_pup$n_trials)
      ),
      excl_fill, excl_border, 2.75
    ),
    flow_box(
      "pup_adt", adt_x, y_pup, bw, bh_md,
      sprintf(
        "Pupil-linked DDM\nN = %s\nn = %s trials",
        format_flow_n(adt_pup$n_sub),
        format_flow_n(adt_pup$n_trials)
      ),
      pupil_fill, adt_col, 2.95
    ),
    flow_box(
      "pup_vdt", vdt_x, y_pup, bw, bh_md,
      sprintf(
        "Pupil-linked DDM\nN = %s\nn = %s trials",
        format_flow_n(vdt_pup$n_sub),
        format_flow_n(vdt_pup$n_trials)
      ),
      pupil_fill, vdt_col, 2.95
    ),
    flow_box(
      "pup_pool", center_x, y_pool, 1.75, bh_lg,
      sprintf(
        "Pooled pupil-linked DDM\nN = %s participants\nn = %s trials\n(valid TEPR + behavioral inclusion)",
        format_flow_n(flow$subs_pupil),
        format_flow_n(flow$trials_pupil)
      ),
      pooled_fill, "#B45309", 3.05
    )
  )

  edge_pairs <- tibble::tibble(
    from = c(
      "enrolled", "enrolled",
      "cohort", "cohort",
      "beh_pool", "beh_pool",
      "beh_adt", "beh_vdt",
      "pup_ex_adt", "pup_ex_vdt",
      "pup_adt", "pup_vdt"
    ),
    to = c(
      "post_excl", "cohort",
      "rt_excl", "beh_pool",
      "beh_adt", "beh_vdt",
      "pup_ex_adt", "pup_ex_vdt",
      "pup_adt", "pup_vdt",
      "pup_pool", "pup_pool"
    ),
    style = c(
      "straight", "straight",
      "straight", "straight",
      "straight", "straight",
      "straight", "straight",
      "straight", "straight",
      "merge", "merge"
    )
  )

  edges <- flow_edges_for(edge_pairs, boxes)

  column_headers <- tibble::tibble(
    x = c(adt_x, vdt_x),
    y = c(y_beh_hdr, y_beh_hdr),
    label = c("Auditory (ADT)", "Visual (VDT)")
  )

  stream_labels <- tibble::tibble(
    x = c(center_x, center_x, center_x),
    y = c(y_excl_enroll + 0.55, y_rt + 0.75, y_pup + 0.85),
    label = c(
      "Participant screening",
      "Behavioral DDM path",
      "Pupil-linked DDM path"
    )
  )

  edge_layers <- draw_flow_edges(edges)

  p <- ggplot2::ggplot()
  for (layer in edge_layers) {
    p <- p + layer
  }
  p +
    ggplot2::geom_rect(
      data = boxes,
      ggplot2::aes(
        xmin = x - w / 2,
        xmax = x + w / 2,
        ymin = y - h / 2,
        ymax = y + h / 2,
        fill = fill,
        colour = border
      ),
      linewidth = 0.55
    ) +
    ggplot2::geom_text(
      data = boxes,
      ggplot2::aes(x = x, y = y, label = label, size = size),
      lineheight = 0.92,
      colour = text_col
    ) +
    ggplot2::geom_text(
      data = stream_labels,
      ggplot2::aes(x = x, y = y, label = label),
      size = 2.9,
      colour = "#4B5563",
      fontface = "italic"
    ) +
    ggplot2::geom_text(
      data = column_headers,
      ggplot2::aes(x = x, y = y, label = label),
      size = 3.6,
      colour = text_col,
      fontface = "bold"
    ) +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_size_identity() +
    ggplot2::coord_cartesian(xlim = c(-0.05, 4.55), ylim = c(0, 11.8), expand = FALSE) +
    ggplot2::labs(
      title = "Participant and Analytic Sample Flow",
      subtitle = paste0(
        "Behavioral primary DDM: probe-onset-locked RT, cue-locked RT >= ",
        thr_label,
        " s; pupil-linked models require valid Decision-Response TEPR"
      )
    ) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold", size = 13, hjust = 0.5, margin = ggplot2::margin(b = 2)
      ),
      plot.subtitle = ggplot2::element_text(
        size = 9.5, hjust = 0.5, colour = "#4B5563", margin = ggplot2::margin(b = 8)
      ),
      plot.margin = ggplot2::margin(10, 12, 10, 12)
    )
}
