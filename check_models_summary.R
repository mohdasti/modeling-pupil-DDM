# Quick model check
library(brms)
models <- c("Model1_Baseline", "Model2_Force", "Model3_Difficulty", 
            "Model4_Additive", "Model5_Interaction", "Model7_Task",
            "Model8_Task_Additive", "Model9_Task_Intx", "Model10_Param_v_bs")

cat("Loading models and checking convergence...\n\n")
for (m in models) {
  f <- paste0("output/models/", m, ".rds")
  if (file.exists(f)) {
    mod <- readRDS(f)
    rhat_max <- max(rhat(mod), na.rm = TRUE)
    cat(sprintf("%-25s R-hat: %.4f %s\n", m, rhat_max, 
                ifelse(rhat_max < 1.01, "✅", ifelse(rhat_max < 1.05, "⚠️", "❌"))))
  }
}
