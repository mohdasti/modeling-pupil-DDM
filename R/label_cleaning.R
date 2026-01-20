# Helper functions for cleaning parameter and contrast labels
# Used in Results tables and figures

#' Clean DDM parameter names for display
#' @param param Character vector of parameter names
#' @return Cleaned parameter names
clean_ddm_parameter <- function(param) {
  param <- as.character(param)
  param <- gsub("difficulty_levelHard", "Difficulty: Hard", param)
  param <- gsub("difficulty_levelEasy", "Difficulty: Easy", param)
  param <- gsub("difficulty_levelStandard", "Difficulty: Standard", param)
  param <- gsub("effort_conditionHigh_MVC", "Effort: High", param)
  param <- gsub("effort_conditionLow_5_MVC", "Effort: Low", param)
  param <- gsub("taskVDT", "Task: VDT", param)
  param <- gsub("taskADT", "Task: ADT", param)
  param <- gsub("_", " ", param)
  return(param)
}

#' Clean contrast names for display
#' @param contrast Character vector of contrast names
#' @return Cleaned contrast names
clean_contrast_name <- function(contrast) {
  contrast <- as.character(contrast)
  
  # Common contrast patterns
  contrast <- gsub("difficulty_levelHard", "Difficulty: Hard", contrast)
  contrast <- gsub("difficulty_levelEasy", "Difficulty: Easy", contrast)
  contrast <- gsub("difficulty_levelStandard", "Difficulty: Standard", contrast)
  contrast <- gsub("effort_conditionHigh_MVC", "Effort: High", contrast)
  contrast <- gsub("effort_conditionLow_5_MVC", "Effort: Low", contrast)
  contrast <- gsub("taskVDT", "Task: VDT", contrast)
  contrast <- gsub("taskADT", "Task: ADT", contrast)
  
  # Handle interactions
  contrast <- gsub(":", " × ", contrast)
  contrast <- gsub("_", " ", contrast)
  
  return(contrast)
}

#' Clean model names for LOO comparison
#' @param model Character vector of model names
#' @return Cleaned model names
clean_model_name <- function(model) {
  model <- as.character(model)
  
  # Single parameter models
  model <- ifelse(model == "v", "Difficulty → v (drift)", model)
  model <- ifelse(model == "z", "Difficulty → z (bias)", model)
  model <- ifelse(model == "a", "Difficulty → a (boundary)", model)
  
  # Two-parameter combinations
  model <- ifelse(model == "v_z", "Difficulty → v + z", model)
  model <- ifelse(model == "v_a", "Difficulty → v + a", model)
  model <- ifelse(model == "z_a", "Difficulty → z + a", model)
  
  # Three-parameter combination
  model <- ifelse(model == "v_z_a", "Difficulty → v + a + z", model)
  model <- ifelse(model == "v_a_z", "Difficulty → v + a + z", model)
  
  # Model number formats
  model <- gsub("Model3_Difficulty", "Difficulty → v (drift)", model)
  model <- gsub("Model4_Additive", "Additive (v + a + z)", model)
  model <- gsub("Model5_Interaction", "Interaction", model)
  model <- gsub("Model10_Param_v_bs", "v + a parameterized", model)
  
  # Remove common prefixes
  model <- gsub("^Difficulty_on_", "", model)
  model <- gsub("^difficulty_", "", model)
  
  # Format underscores as separators
  model <- gsub("_", " ", model)
  
  return(model)
}
