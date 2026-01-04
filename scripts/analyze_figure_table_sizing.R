#!/usr/bin/env Rscript
# =========================================================================
# SYSTEMATIC FIGURE AND TABLE SIZING ANALYSIS
# =========================================================================
# This script analyzes all figures and tables in chap3_ddm_results.qmd
# to identify which ones need resizing for PDF output.
#
# It checks:
# 1. Current figure dimensions (width/height in pixels/inches)
# 2. Whether figures fit within PDF page boundaries (6.5" width max)
# 3. Caption lengths (to ensure they don't overlap page numbers)
# 4. Table widths (number of columns, content width)
# 5. Recommendations for resizing or landscape orientation
# =========================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(magick)  # For image dimension checking
  library(tools)
})

# Configuration
QMD_FILE <- "reports/chap3_ddm_results.qmd"
FIGURES_DIR <- "output/figures"
OUTPUT_FILE <- "output/diagnostics/figure_table_sizing_analysis.csv"
PDF_PAGE_WIDTH <- 6.5  # inches (with 1" margins on letter paper)
PDF_PAGE_HEIGHT <- 9.0  # inches (with 1" margins)
MAX_CAPTION_LINES <- 3  # Approximate max lines before wrapping issues

# Create output directory
dir.create("output/diagnostics", recursive = TRUE, showWarnings = FALSE)

cat("========================================\n")
cat("Figure and Table Sizing Analysis\n")
cat("========================================\n\n")

# Read the QMD file line by line
cat("Reading QMD file...\n")
qmd_lines <- readLines(QMD_FILE, warn = FALSE)

# Extract all figure and table labels with their captions
extract_items <- function(qmd_lines) {
  items <- list()
  i <- 1
  
  while (i <= length(qmd_lines)) {
    # Look for label line
    if (str_detect(qmd_lines[i], "#\\| label: (fig-|tbl-)")) {
      label_match <- str_match(qmd_lines[i], "#\\| label: (fig-[^\\s]+|tbl-[^\\s]+)")
      
      if (!is.na(label_match[2])) {
        label <- str_trim(label_match[2])
        type <- ifelse(str_detect(label, "^fig-"), "figure", "table")
        caption <- ""
        caption_key <- ifelse(type == "figure", "fig-cap", "tbl-cap")
        
        # Look ahead for caption (within next 5 lines)
        for (j in (i+1):min(i+5, length(qmd_lines))) {
          if (str_detect(qmd_lines[j], paste0("#\\| ", caption_key, ":"))) {
            caption_match <- str_match(qmd_lines[j], paste0("#\\| ", caption_key, ": \"(.+)\""))
            if (!is.na(caption_match[2])) {
              caption <- caption_match[2]
            } else {
              # Multi-line caption - extract what we can
              caption <- str_replace(qmd_lines[j], paste0("#\\| ", caption_key, ": "), "")
              caption <- str_replace_all(caption, "^\"|\"$", "")
            }
            break
          }
        }
        
        items[[length(items) + 1]] <- list(
          label = label,
          type = type,
          caption = caption
        )
      }
    }
    i <- i + 1
  }
  
  return(items)
}

cat("Extracting figure and table labels...\n")
all_items <- extract_items(qmd_lines)
cat("Found", length(all_items), "items\n\n")

# Function to find figure file path
find_figure_file <- function(label, qmd_lines) {
  # Remove label prefix
  base_name <- str_replace(label, "^(fig-|tbl-)", "")
  
  # Look for include_graphics or similar in the chunk
  # Find the chunk containing this label
  label_line <- which(str_detect(qmd_lines, paste0("#\\| label: ", label)))[1]
  if (is.na(label_line)) return(NA_character_)
  
  # Look in next 20 lines for file reference
  chunk_end <- min(label_line + 20, length(qmd_lines))
  chunk_text <- paste(qmd_lines[label_line:chunk_end], collapse = "\n")
  
  # Extract file name from fig_path() or include_graphics()
  file_match <- str_match(chunk_text, 
    "(?:fig_path|include_graphics)\\([\"']([^\"']+)[\"']\\)")
  
  if (!is.na(file_match[2])) {
    file_name <- file_match[2]
    # Try to find the actual file
    candidates <- c(
      file.path(FIGURES_DIR, file_name),
      file.path(FIGURES_DIR, basename(file_name)),
      file.path("output/figures", file_name),
      file.path("output/figures", basename(file_name))
    )
    
    for (candidate in candidates) {
      if (file.exists(candidate)) {
        return(candidate)
      }
    }
  }
  
  # Fallback: try common patterns
  base_clean <- str_replace_all(base_name, "-", "_")
  candidates <- c(
    paste0(base_clean, ".pdf"),
    paste0(base_clean, ".png"),
    paste0("fig_", str_replace(base_clean, "^fig_", ""), ".pdf"),
    paste0("fig_", str_replace(base_clean, "^fig_", ""), ".png"),
    paste0("plot", str_extract(base_clean, "\\d+"), "_", 
           str_replace(base_clean, "^.*?plot\\d+_?", ""), ".png")
  )
  
  for (candidate in candidates) {
    path <- file.path(FIGURES_DIR, candidate)
    if (file.exists(path)) {
      return(path)
    }
  }
  
  return(NA_character_)
}

# Function to get image dimensions
get_image_dimensions <- function(file_path) {
  if (is.na(file_path) || !file.exists(file_path)) {
    return(list(width_in = NA, height_in = NA, width_px = NA, height_px = NA, 
                aspect_ratio = NA, dpi = NA))
  }
  
  tryCatch({
    ext <- tolower(tools::file_ext(file_path))
    
    if (ext %in% c("png", "jpg", "jpeg")) {
      img <- magick::image_read(file_path)
      info <- magick::image_info(img)
      width_px <- info$width
      height_px <- info$height
      
      # Try to get DPI from metadata
      dpi <- tryCatch({
        density <- magick::image_info(img)$density
        if (is.character(density) && density != "") {
          as.numeric(strsplit(density, "x")[[1]][1])
        } else {
          300  # Default
        }
      }, error = function(e) 300)
      
      # Convert to inches
      width_in <- width_px / dpi
      height_in <- height_px / dpi
      aspect_ratio <- width_in / height_in
      
      return(list(
        width_in = width_in,
        height_in = height_in,
        width_px = width_px,
        height_px = height_px,
        aspect_ratio = aspect_ratio,
        dpi = dpi
      ))
    } else if (ext == "pdf") {
      # For PDF, we can't easily get dimensions without additional tools
      # Return NA and note it needs manual checking
      return(list(
        width_in = NA,
        height_in = NA,
        width_px = NA,
        height_px = NA,
        aspect_ratio = NA,
        dpi = NA,
        note = "PDF - needs manual dimension check"
      ))
    }
  }, error = function(e) {
    return(list(width_in = NA, height_in = NA, width_px = NA, height_px = NA, 
                aspect_ratio = NA, dpi = NA, error = as.character(e)))
  })
}

# Function to estimate caption length impact
estimate_caption_lines <- function(caption, max_width_chars = 70) {
  if (is.na(caption) || caption == "") return(0)
  
  # Rough estimate: assume ~70 characters per line for 11pt font
  words <- strsplit(caption, "\\s+")[[1]]
  lines <- 1
  current_line_length <- 0
  
  for (word in words) {
    word_length <- nchar(word) + 1  # +1 for space
    if (current_line_length + word_length > max_width_chars) {
      lines <- lines + 1
      current_line_length <- nchar(word)
    } else {
      current_line_length <- current_line_length + word_length
    }
  }
  
  return(lines)
}

# Analyze each item
cat("Analyzing", length(all_items), "figures and tables...\n\n")

results <- list()

for (i in seq_along(all_items)) {
  item <- all_items[[i]]
  
  cat(sprintf("Processing %d/%d: %s\n", i, length(all_items), item$label))
  
  # Find figure file (for tables, this will be NA)
  fig_file <- if (item$type == "figure") {
    find_figure_file(item$label, qmd_lines)
  } else {
    NA_character_
  }
  
  # Get dimensions if figure file exists
  dims <- if (!is.na(fig_file) && file.exists(fig_file)) {
    get_image_dimensions(fig_file)
  } else {
    list(width_in = NA, height_in = NA, width_px = NA, height_px = NA, 
         aspect_ratio = NA, dpi = NA)
  }
  
  # Analyze caption
  caption_lines <- estimate_caption_lines(item$caption)
  caption_length <- nchar(item$caption)
  
  # Determine if resizing needed
  needs_resize <- FALSE
  resize_reason <- ""
  recommended_width <- NA_real_
  recommended_height <- NA_real_
  recommended_action <- ""
  
  if (item$type == "figure") {
    if (!is.na(dims$width_in)) {
      if (dims$width_in > PDF_PAGE_WIDTH) {
        needs_resize <- TRUE
        resize_reason <- paste0("Width (", round(dims$width_in, 2), 
                                " in) exceeds page width (", PDF_PAGE_WIDTH, " in)")
        recommended_width <- PDF_PAGE_WIDTH * 0.95  # Leave small margin
        # Maintain aspect ratio
        if (!is.na(dims$aspect_ratio) && dims$aspect_ratio > 0) {
          recommended_height <- recommended_width / dims$aspect_ratio
        }
        recommended_action <- "Resize to fit page width"
      } else if (dims$width_in > PDF_PAGE_WIDTH * 0.9) {
        # Close to limit
        recommended_action <- "Consider reducing slightly for margin"
        recommended_width <- PDF_PAGE_WIDTH * 0.85
        if (!is.na(dims$aspect_ratio) && dims$aspect_ratio > 0) {
          recommended_height <- recommended_width / dims$aspect_ratio
        }
      } else {
        recommended_action <- "Size OK"
      }
      
      # Check if very wide (might need landscape)
      if (!is.na(dims$aspect_ratio) && dims$aspect_ratio > 1.5) {
        recommended_action <- paste0(recommended_action, 
                                     " | Consider landscape orientation")
      }
    } else {
      if (is.na(fig_file)) {
        recommended_action <- "File not found - check path"
      } else {
        recommended_action <- "Check dimensions manually (PDF file)"
      }
    }
  } else {
    # For tables, we'll need to check the actual table content
    # This is harder to automate, so we'll flag for manual review
    recommended_action <- "Review table width manually (check column count and content)"
  }
  
  # Check caption length
  caption_issue <- ""
  if (caption_lines > MAX_CAPTION_LINES) {
    caption_issue <- paste0("Long caption (", caption_lines, 
                           " estimated lines) - may overlap page numbers")
  }
  
  results[[i]] <- data.frame(
    label = item$label,
    type = item$type,
    file_path = ifelse(is.na(fig_file), "N/A (table)", fig_file),
    current_width_in = round(dims$width_in, 2),
    current_height_in = round(dims$height_in, 2),
    aspect_ratio = round(dims$aspect_ratio, 2),
    dpi = dims$dpi,
    caption_length = caption_length,
    caption_lines_est = caption_lines,
    caption_issue = caption_issue,
    needs_resize = needs_resize,
    resize_reason = resize_reason,
    recommended_width_in = round(recommended_width, 2),
    recommended_height_in = round(recommended_height, 2),
    recommended_action = recommended_action,
    stringsAsFactors = FALSE
  )
}

# Combine results
results_df <- bind_rows(results)

# Add summary statistics
cat("\n========================================\n")
cat("Summary Statistics\n")
cat("========================================\n\n")

cat("Total items:", nrow(results_df), "\n")
cat("Figures:", sum(results_df$type == "figure"), "\n")
cat("Tables:", sum(results_df$type == "table"), "\n\n")

cat("Figures needing resizing:", sum(results_df$needs_resize, na.rm = TRUE), "\n")
cat("Figures with long captions:", sum(results_df$caption_lines_est > MAX_CAPTION_LINES, na.rm = TRUE), "\n")
cat("Figures with missing files:", sum(is.na(results_df$current_width_in) & results_df$type == "figure"), "\n\n")

# Save results
write_csv(results_df, OUTPUT_FILE)
cat("Results saved to:", OUTPUT_FILE, "\n\n")

# Print items needing attention
cat("========================================\n")
cat("Items Requiring Attention\n")
cat("========================================\n\n")

needs_attention <- results_df %>%
  filter(needs_resize | 
         caption_lines_est > MAX_CAPTION_LINES | 
         (is.na(current_width_in) & type == "figure") |
         str_detect(recommended_action, "landscape|Resize|Consider"))

if (nrow(needs_attention) > 0) {
  for (i in 1:nrow(needs_attention)) {
    item <- needs_attention[i, ]
    cat(sprintf("\n[%s] %s\n", item$type, item$label))
    if (!is.na(item$file_path) && item$file_path != "N/A (table)") {
      cat("  File:", item$file_path, "\n")
    }
    if (!is.na(item$current_width_in)) {
      cat(sprintf("  Current size: %.2f\" × %.2f\" (aspect ratio: %.2f)\n", 
                 item$current_width_in, item$current_height_in, 
                 item$aspect_ratio))
    }
    if (item$needs_resize) {
      cat("  ⚠️  NEEDS RESIZE:", item$resize_reason, "\n")
      if (!is.na(item$recommended_width_in)) {
        cat(sprintf("  Recommended: %.2f\" × %.2f\"\n", 
                   item$recommended_width_in, item$recommended_height_in))
      }
    }
    if (item$caption_issue != "") {
      cat("  ⚠️  CAPTION:", item$caption_issue, "\n")
    }
    cat("  Action:", item$recommended_action, "\n")
  }
} else {
  cat("✓ No items require immediate attention!\n")
}

cat("\n========================================\n")
cat("Analysis Complete\n")
cat("========================================\n")
cat("\nNext steps:\n")
cat("1. Review the CSV file:", OUTPUT_FILE, "\n")
cat("2. For figures needing resize, update figure generation scripts\n")
cat("3. For long captions, consider shortening or splitting\n")
cat("4. For wide figures, consider landscape orientation\n")
cat("========================================\n")
