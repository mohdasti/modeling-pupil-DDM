#!/usr/bin/env Rscript
# Convert PDF figures to PNG for HTML output
# Saves PNG files alongside original PDFs in output/figures/
# Tries multiple methods: magick R package, pdftools R package, or system tools

suppressPackageStartupMessages({
  library(fs)
})

fig_dir <- "output/figures"
if (!dir.exists(fig_dir)) {
  stop("Figure directory not found: ", fig_dir)
}

# Find all PDF figures
pdf_files <- list.files(fig_dir, pattern = "\\.pdf$", full.names = TRUE)

if (length(pdf_files) == 0) {
  message("No PDF files found in ", fig_dir)
  quit(status = 0)
}

message("Found ", length(pdf_files), " PDF file(s) to convert...\n")

# Function to convert using magick R package (preferred)
convert_with_magick <- function(pdf_path, png_path, dpi = 300) {
  if (!requireNamespace("magick", quietly = TRUE)) {
    return(FALSE)
  }
  img <- magick::image_read_pdf(pdf_path, density = dpi)
  magick::image_write(img, png_path, format = "png", density = dpi)
  return(TRUE)
}

# Function to convert using pdftools R package
convert_with_pdftools <- function(pdf_path, png_path, dpi = 300) {
  if (!requireNamespace("pdftools", quietly = TRUE)) {
    return(FALSE)
  }
  pdftools::pdf_convert(pdf_path, format = "png", dpi = dpi, filenames = png_path)
  return(TRUE)
}

# Function to convert using system command (macOS sips or ImageMagick convert)
convert_with_system <- function(pdf_path, png_path, dpi = 600) {
  # Try ImageMagick convert (best quality, respects DPI)
  if (Sys.which("convert") != "") {
    # Use high quality settings: density for resolution, quality for compression
    cmd <- paste0("convert -density ", dpi, " -quality 100 -colorspace RGB '", 
                  pdf_path, "' '", png_path, "'")
    result <- system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
    if (result == 0) return(TRUE)
  }
  
  # Try pdftoppm (poppler) - better quality than sips
  if (Sys.which("pdftoppm") != "") {
    # pdftoppm creates files with -1, -2 suffix, need to rename
    base_name <- tools::file_path_sans_ext(png_path)
    cmd <- paste0("pdftoppm -png -r ", dpi, " -scale-to-x -1 -scale-to-y -1 '", 
                  pdf_path, "' '", base_name, "'")
    result <- system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
    if (result == 0) {
      # Find the generated file and rename it
      generated <- paste0(base_name, "-1.png")
      if (file.exists(generated)) {
        file.rename(generated, png_path)
        return(TRUE)
      }
    }
  }
  
  # Try sips (macOS built-in) - lower quality but available
  if (Sys.which("sips") != "") {
    # sips doesn't support DPI directly, but we can resize after
    # First convert, then we'll need to check if we can improve quality
    cmd <- paste0("sips -s format png -s formatOptions high '", pdf_path, 
                  "' --out '", png_path, "'")
    result <- system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
    if (result == 0) {
      # Try to upscale if the result is too small
      # Get current dimensions
      info_cmd <- paste0("sips -g pixelWidth -g pixelHeight '", png_path, "'")
      info <- system(info_cmd, intern = TRUE, ignore.stderr = TRUE)
      # If dimensions are small, this is a limitation of sips
      # For now, return TRUE but note that quality might be lower
      return(TRUE)
    }
  }
  
  return(FALSE)
}

# Determine which method to use (prefer magick for best quality)
use_method <- NULL
if (requireNamespace("magick", quietly = TRUE)) {
  use_method <- "magick"
  message("Using 'magick' R package for high-quality conversion\n")
} else if (requireNamespace("pdftools", quietly = TRUE)) {
  use_method <- "pdftools"
  message("Using 'pdftools' R package for conversion\n")
} else if (Sys.which("convert") != "") {
  use_method <- "system"
  message("Using ImageMagick (convert) for conversion\n")
} else if (Sys.which("pdftoppm") != "") {
  use_method <- "system"
  message("Using pdftoppm for conversion\n")
} else if (Sys.which("sips") != "") {
  use_method <- "system"
  message("Using sips for conversion (lower quality - consider installing magick package)\n")
} else {
  stop("No conversion tool available. Please install:\n",
       "  - R package: install.packages('magick') [RECOMMENDED]\n",
       "  - Or system tool: brew install imagemagick poppler (macOS)")
}

# Convert each PDF
success_count <- 0
for (pdf_file in pdf_files) {
  png_file <- path_ext_set(pdf_file, "png")
  
  # Skip if PNG already exists and is newer
  if (file.exists(png_file) && file.mtime(png_file) > file.mtime(pdf_file)) {
    message("⏭  Skipping ", basename(pdf_file), " (PNG already exists and is newer)")
    success_count <- success_count + 1
    next
  }
  
  message("🔄 Converting: ", basename(pdf_file))
  
  success <- FALSE
  # Use 600 DPI for high quality (doubled from 300)
  target_dpi <- 600
  if (use_method == "magick") {
    tryCatch({
      success <- convert_with_magick(pdf_file, png_file, dpi = target_dpi)
    }, error = function(e) {
      message("    Error: ", conditionMessage(e))
    })
  } else if (use_method == "pdftools") {
    tryCatch({
      success <- convert_with_pdftools(pdf_file, png_file, dpi = target_dpi)
    }, error = function(e) {
      message("    Error: ", conditionMessage(e))
    })
  } else if (use_method == "system") {
    success <- convert_with_system(pdf_file, png_file, dpi = target_dpi)
  }
  
  if (success && file.exists(png_file)) {
    success_count <- success_count + 1
    file_size <- round(file.info(png_file)$size / 1024, 1)
    message("    ✓ Success (", file_size, " KB)\n")
  } else {
    message("    ✗ Failed\n")
  }
}

message("\n" , "=", rep("=", 50), "\n")
message("Conversion complete: ", success_count, "/", length(pdf_files), " files converted successfully")

if (success_count < length(pdf_files)) {
  message("\n⚠️  Some files failed to convert.")
  message("To install conversion tools:\n")
  message("  R packages: install.packages(c('magick', 'pdftools'))")
  message("  macOS system: brew install imagemagick poppler")
}

