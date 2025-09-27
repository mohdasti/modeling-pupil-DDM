# =========================================================================
# MODELING PUPIL-DDM - R PACKAGE INSTALLATION
# =========================================================================
# This script installs all required R packages for the Modeling Pupil-DDM
# analysis pipeline. Run this script after setting up the conda environment.
# =========================================================================

# Function to install packages if not already installed
install_if_missing <- function(package_name) {
  if (!require(package_name, character.only = TRUE)) {
    cat("Installing", package_name, "...\n")
    install.packages(package_name, dependencies = TRUE)
  } else {
    cat("✓", package_name, "already installed\n")
  }
}

# Function to install packages from GitHub if not already installed
install_github_if_missing <- function(package_name, repo) {
  if (!require(package_name, character.only = TRUE)) {
    cat("Installing", package_name, "from GitHub...\n")
    if (!require(devtools)) {
      install.packages("devtools")
    }
    devtools::install_github(repo)
  } else {
    cat("✓", package_name, "already installed\n")
  }
}

cat("================================================================================\n")
cat("MODELING PUPIL-DDM - R PACKAGE INSTALLATION\n")
cat("================================================================================\n")

# Core data manipulation and analysis packages
cat("\n📦 Installing core data manipulation packages...\n")
core_packages <- c(
  "dplyr", "tidyr", "purrr", "stringr", "readr", "readxl",
  "lubridate", "forcats", "magrittr", "tibble"
)

for (pkg in core_packages) {
  install_if_missing(pkg)
}

# Statistical modeling packages
cat("\n📊 Installing statistical modeling packages...\n")
stats_packages <- c(
  "lme4", "lmerTest", "brms", "rstan", "rstanarm",
  "car", "emmeans", "effects", "sjstats", "performance"
)

for (pkg in stats_packages) {
  install_if_missing(pkg)
}

# Bayesian analysis packages
cat("\n🔮 Installing Bayesian analysis packages...\n")
bayesian_packages <- c(
  "bayesplot", "rstan", "brms", "loo", "bayestestR",
  "posterior", "cmdstanr"
)

for (pkg in bayesian_packages) {
  install_if_missing(pkg)
}

# Data visualization packages
cat("\n📈 Installing data visualization packages...\n")
viz_packages <- c(
  "ggplot2", "plotly", "ggthemes", "viridis", "RColorBrewer",
  "gridExtra", "cowplot", "patchwork", "gghalves", "ggridges"
)

for (pkg in viz_packages) {
  install_if_missing(pkg)
}

# Correlation and multivariate analysis
cat("\n🔗 Installing correlation and multivariate analysis packages...\n")
correlation_packages <- c(
  "corrplot", "Hmisc", "psych", "GPArotation", "factoextra"
)

for (pkg in correlation_packages) {
  install_if_missing(pkg)
}

# Time series and signal processing
cat("\n⏰ Installing time series and signal processing packages...\n")
timeseries_packages <- c(
  "signal", "pracma", "zoo", "xts", "forecast"
)

for (pkg in timeseries_packages) {
  install_if_missing(pkg)
}

# Machine learning packages
cat("\n🤖 Installing machine learning packages...\n")
ml_packages <- c(
  "randomForest", "e1071", "caret", "glmnet", "xgboost"
)

for (pkg in ml_packages) {
  install_if_missing(pkg)
}

# Utility and helper packages
cat("\n🛠️ Installing utility and helper packages...\n")
utility_packages <- c(
  "here", "fs", "usethis", "devtools", "roxygen2",
  "testthat", "knitr", "rmarkdown", "bookdown", "pkgdown"
)

for (pkg in utility_packages) {
  install_if_missing(pkg)
}

# JSON and data exchange
cat("\n📄 Installing JSON and data exchange packages...\n")
json_packages <- c(
  "jsonlite", "yaml", "xml2", "httr", "curl"
)

for (pkg in json_packages) {
  install_if_missing(pkg)
}

# Parallel processing
cat("\n⚡ Installing parallel processing packages...\n")
parallel_packages <- c(
  "parallel", "foreach", "doParallel", "future", "furrr"
)

for (pkg in parallel_packages) {
  install_if_missing(pkg)
}

# Specialized packages for pupillometry and DDM
cat("\n🧠 Installing specialized packages for pupillometry and DDM...\n")
specialized_packages <- c(
  "RWiener", "rtdists", "Rcpp", "RcppArmadillo"
)

for (pkg in specialized_packages) {
  install_if_missing(pkg)
}

# Install packages from GitHub if needed
cat("\n🌐 Installing packages from GitHub...\n")
github_packages <- list(
  "tidyverse" = "tidyverse/tidyverse",
  "broom" = "tidymodels/broom",
  "infer" = "tidymodels/infer"
)

for (pkg in names(github_packages)) {
  install_github_if_missing(pkg, github_packages[[pkg]])
}

# Verify installation
cat("\n✅ Verifying package installation...\n")
required_packages <- c(
  "dplyr", "tidyr", "ggplot2", "lme4", "brms", "bayesplot",
  "corrplot", "viridis", "cowplot", "jsonlite"
)

all_installed <- TRUE
for (pkg in required_packages) {
  if (require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat("✓", pkg, "installed and loaded successfully\n")
  } else {
    cat("❌", pkg, "failed to install or load\n")
    all_installed <- FALSE
  }
}

# Final status
cat("\n================================================================================\n")
if (all_installed) {
  cat("🎉 ALL PACKAGES INSTALLED SUCCESSFULLY!\n")
  cat("You can now run the Modeling Pupil-DDM analysis pipeline.\n")
} else {
  cat("⚠️  SOME PACKAGES FAILED TO INSTALL\n")
  cat("Please check the error messages above and install missing packages manually.\n")
}
cat("================================================================================\n")

# Save session info
cat("\n📋 Saving session information...\n")
session_info_file <- "r_package_installation_session_info.txt"
writeLines(capture.output(sessionInfo()), session_info_file)
cat("Session info saved to:", session_info_file, "\n")

# Create package list for documentation
package_list <- installed.packages()[, "Package"]
package_list_file <- "installed_packages.txt"
writeLines(package_list, package_list_file)
cat("Package list saved to:", package_list_file, "\n")
