#!/usr/bin/env Rscript
# Script to organize repository files into folders
# Move markdown documentation files and intermediary R scripts

library(fs)

proj_root <- getwd()

# Create directories
dir_create("docs/development_notes")
dir_create("scripts/intermediary")

# Files to keep at root
keep_files <- c(
  "README.md",
  "START_HERE.md", 
  "CONTRIBUTING.md"
)

# Get all markdown files in root (excluding keep files)
md_files <- dir_ls(proj_root, glob = "*.md", type = "file")
md_files <- md_files[!basename(md_files) %in% keep_files]

cat(sprintf("Found %d markdown files to move\n", length(md_files)))

# Move markdown files
for (f in md_files) {
  dest <- path("docs/development_notes", basename(f))
  file_move(f, dest)
  cat(sprintf("Moved: %s -> %s\n", basename(f), dest))
}

# Get intermediary R scripts
intermediary_patterns <- c(
  "test_*.R",
  "check_*.R", 
  "verify_*.R",
  "audit_*.R",
  "update_*.R",
  "extract_*.R",
  "fix_*.R"
)

# Get all matching files
intermediary_files <- character()
for (pattern in intermediary_patterns) {
  files <- dir_ls(proj_root, glob = pattern, type = "file")
  intermediary_files <- c(intermediary_files, files)
}

# Remove duplicates
intermediary_files <- unique(intermediary_files)

cat(sprintf("\nFound %d intermediary R scripts to move\n", length(intermediary_files)))

# Move R scripts
for (f in intermediary_files) {
  dest <- path("scripts/intermediary", basename(f))
  file_move(f, dest)
  cat(sprintf("Moved: %s -> %s\n", basename(f), dest))
}

cat("\nOrganization complete!\n")















