# R/fig_bias_forest.R

suppressPackageStartupMessages({
  library(ggplot2); library(readr); library(dplyr)
})

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

lev <- read_csv("output/publish/bias_standard_only_levels.csv", show_col_types = FALSE)

# Keep probability scale rows for readability
plotdf <- lev %>% filter(scale=="prob") %>%
  mutate(level = factor(param, 
                        levels=c("bias_ADT_Low","bias_ADT_High","bias_VDT_Low","bias_VDT_High"),
                        labels=c("ADT-Low","ADT-High","VDT-Low","VDT-High")))

p <- ggplot(plotdf, aes(x=level, y=mean, ymin=q2.5, ymax=q97.5)) +
  geom_pointrange(position=position_dodge(width=0.3)) +
  geom_hline(yintercept=0.5, linetype="dashed") +
  labs(x=NULL, y="Bias z (probability toward 'different')",
       title="Standard-only bias (z) by task/effort (95% CrI)") +
  coord_flip() + theme_minimal()

ggsave("output/figures/fig_bias_forest.png", p, width=6, height=5, dpi=300)
ggsave("output/figures/fig_bias_forest.pdf", p, width=6, height=5)

cat("✓ Wrote output/figures/fig_bias_forest.png\n")
cat("✓ Wrote output/figures/fig_bias_forest.pdf\n")

