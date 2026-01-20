# Utility functions for file I/O and path resolution
# Used in Results section for robust file loading

#' Find first existing file from candidate paths
#' @param paths Character vector of candidate file paths
#' @return First existing path, or NULL if none exist
first_existing <- function(paths) {
  for (path in paths) {
    if (file.exists(path)) {
      return(path)
    }
  }
  return(NULL)
}

#' Safe CSV reader with error handling
#' @param file_path Path to CSV file
#' @param ... Additional arguments to read_csv
#' @return Data frame or NULL on error
safe_read_csv <- function(file_path, ...) {
  if (is.null(file_path) || !file.exists(file_path)) {
    return(NULL)
  }
  tryCatch({
    readr::read_csv(file_path, show_col_types = FALSE, ...)
  }, error = function(e) {
    warning(paste("Error reading", file_path, ":", e$message))
    return(NULL)
  })
}
