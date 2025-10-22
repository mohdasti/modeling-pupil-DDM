#!/usr/bin/env Rscript

# Wrapper: Pupillometry feature extraction
# Calls scripts/utilities/data_integration.R (feature preparation pipeline)

suppressWarnings(suppressMessages({
  source(file.path('scripts','utilities','data_integration.R'))
}))
