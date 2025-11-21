# R/report_bias_contrasts.R

suppressPackageStartupMessages({
  library(brms); library(dplyr); library(readr); library(posterior); library(tibble)
})

dir.create("output/publish", recursive = TRUE, showWarnings = FALSE)

m_std  <- readRDS("output/publish/fit_standard_bias_only.rds")
m_joint <- readRDS("output/publish/fit_joint_vza_stdconstrained.rds")

to_prob <- function(x) 1/(1+exp(-x))

# -------- Standard-only (primary bias) --------
fx_std <- as_draws_df(m_std)  # contains b_bias_*
# Intercept is bias (logit) for baseline (task=ADT, effort=Low)
b0   <- fx_std$`b_bias_Intercept`
bVDT <- b0 + fx_std$`b_bias_taskVDT`
bHi  <- b0 + fx_std$`b_bias_effort_conditionHigh_MVC`

summarize_param <- function(draws, name, scale=c("logit","prob")) {
  scale <- match.arg(scale)
  v <- if (scale=="prob") to_prob(draws) else draws
  tibble(param=name, scale=scale,
         mean=mean(v), sd=sd(v),
         q2.5=quantile(v,0.025), q97.5=quantile(v,0.975))
}

S <- bind_rows(
  summarize_param(b0,   "bias_ADT_Low", "logit"),
  summarize_param(b0,   "bias_ADT_Low", "prob"),
  summarize_param(bVDT, "bias_VDT_Low", "logit"),
  summarize_param(bVDT, "bias_VDT_Low", "prob"),
  summarize_param(bHi,  "bias_ADT_High","logit"),
  summarize_param(bHi,  "bias_ADT_High","prob")
)

# Contrasts (logit scale)
d_VDT_vs_ADT <- bVDT - b0
d_Hi_vs_Low  <- (bHi - b0)

Pr_pos <- function(x) mean(x>0)
C <- tibble(
  contrast = c("VDT - ADT (bias, logit)", "High - Low (bias, logit)"),
  mean = c(mean(d_VDT_vs_ADT), mean(d_Hi_vs_Low)),
  sd   = c(sd(d_VDT_vs_ADT),   sd(d_Hi_vs_Low)),
  q2.5 = c(quantile(d_VDT_vs_ADT,0.025), quantile(d_Hi_vs_Low,0.025)),
  q97.5= c(quantile(d_VDT_vs_ADT,0.975), quantile(d_Hi_vs_Low,0.975)),
  Pr_gt_0 = c(Pr_pos(d_VDT_vs_ADT), Pr_pos(d_Hi_vs_Low))
)

write_csv(S, "output/publish/bias_standard_only_levels.csv")
write_csv(C, "output/publish/bias_standard_only_contrasts.csv")

# -------- Joint model (confirm consistency) --------
fx_joint <- as_draws_df(m_joint)
b0j   <- fx_joint$`b_bias_Intercept`
bVDTj <- b0j + fx_joint$`b_bias_taskVDT`

Cj <- tibble(
  contrast = "VDT - ADT (bias, logit, joint)",
  mean = mean(bVDTj - b0j),
  sd   = sd(bVDTj - b0j),
  q2.5 = quantile(bVDTj - b0j,0.025),
  q97.5= quantile(bVDTj - b0j,0.975),
  Pr_gt_0 = Pr_pos(bVDTj - b0j)
)
write_csv(Cj, "output/publish/bias_joint_contrast.csv")

cat("✓ Wrote bias tables to output/publish/ (levels, contrasts, joint confirm)\n")

