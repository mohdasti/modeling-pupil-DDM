# Helpers for DOCX / Google Docs export from chap3_ddm_results.qmd

#' True when knitting to Word (docx / openxml).
is_docx_output <- function() {
  to <- knitr::opts_knit$get("rmarkdown.pandoc.to") %||% ""
  fmt <- knitr::opts_knit$get("quarto.document.format") %||% ""
  grepl("docx|openxml|word", paste(to, fmt, collapse = " "), ignore.case = TRUE)
}

#' knitr::kable format string for the active output target.
table_kable_format <- function() {
  if (knitr::is_latex_output()) {
    "latex"
  } else if (is_docx_output()) {
    "pipe"
  } else {
    "html"
  }
}

#' Apply knitr / kableExtra / gt patches so DOCX uses native Word tables and PNG figures.
patch_docx_export_handlers <- function() {
  if (!is_docx_output()) {
    return(invisible(NULL))
  }

  knitr::opts_chunk$set(dev = "png", fig.ext = "png", dpi = 300)

  # Prefer pipe tables (Pandoc -> native Word tables). Avoid HTML tables in DOCX.
  if (exists("table_kable_format", mode = "function")) {
    kable_orig <- knitr::kable
    assignInNamespace(
      "kable",
      function(x, format = NULL, ...) {
        if (is.null(format)) {
          format <- table_kable_format()
        }
        kable_orig(x, format = format, ...)
      },
      ns = "knitr"
    )
  }

  # Strip HTML-only kableExtra styling for DOCX.
  if (requireNamespace("kableExtra", quietly = TRUE)) {
    kable_styling_orig <- get("kable_styling", envir = asNamespace("kableExtra"))
    assignInNamespace(
      "kable_styling",
      function(kbl, ...) {
        args <- list(...)
        args$bootstrap_options <- NULL
        args$latex_options <- NULL
        out <- do.call(kable_styling_orig, c(list(kbl), args))
        if (is_docx_output()) {
          return(kbl)
        }
        out
      },
      ns = "kableExtra"
    )
    no_op_specs <- c(
      "row_spec", "column_spec", "add_indent", "footnote",
      "collapse_rows", "scroll_box", "row_group", "pack_rows"
    )
    for (fn in no_op_specs) {
      if (exists(fn, envir = asNamespace("kableExtra"), inherits = FALSE)) {
        orig <- get(fn, envir = asNamespace("kableExtra"))
        assignInNamespace(
          fn,
          function(x, ...) {
            if (is_docx_output()) {
              return(x)
            }
            do.call(orig, c(list(x), list(...)))
          },
          ns = "kableExtra"
        )
      }
    }
  }

  # gt -> simple pipe kable for DOCX (Google Docs mangles HTML gt output).
  registerS3method(
    "knit_print",
    "gt_tbl",
    function(x, options, ...) {
      if (is_docx_output()) {
        df <- as.data.frame(x[["_data"]])
        return(knitr::knit_print(knitr::kable(df, format = "pipe"), options, ...))
      }
      NextMethod()
    },
    envir = asNamespace("knitr")
  )

  invisible(NULL)
}

#' Figure extension for Word export (PNG embeds reliably in Google Docs).
docx_figure_ext <- function() {
  if (knitr::is_latex_output() ||
      grepl("docx|word", knitr::opts_knit$get("rmarkdown.pandoc.to") %||% "", ignore.case = TRUE)) {
    # LaTeX uses PDF; DOCX/Google Docs uses PNG (PDF embeds often fail in GDocs).
    if (is_docx_output()) {
      return("png")
    }
    return("pdf")
  }
  "png"
}
