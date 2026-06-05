# R/fig_bias_forest.R

suppressPackageStartupMessages({
  library(ggplot2); library(readr); library(dplyr); library(here)
})
source(here::here("R", "colors_manuscript.R"))
source(here::here("R", "fig_save_utils.R"))

lev <- read_csv("output/publish/bias_standard_only_levels.csv", show_col_types = FALSE)

# Keep probability scale rows for readability
plotdf <- lev %>% filter(scale=="prob") %>%
  mutate(level = factor(param, 
                        levels=c("bias_ADT_Low","bias_ADT_High","bias_VDT_Low","bias_VDT_High"),
                        labels=c("ADT-Low","ADT-High","VDT-Low","VDT-High")))

plotdf <- plotdf %>% mutate(effort = if_else(grepl("High", level), "High", "Low"))
p <- ggplot(plotdf, aes(x=level, y=mean, ymin=q2.5, ymax=q97.5, color=effort)) +
  geom_pointrange(position=position_dodge(width=0.3)) +
  scale_color_manual(values=effort_colors, guide="none") +
  geom_hline(yintercept=0.5, linetype="dashed", color=unname(stat_colors["zero_line"])) +
  labs(x=NULL, y="Bias z (probability toward 'different')",
       title="Standard-only bias (z) by task/effort (95% CrI)") +
  coord_flip() + theme_minimal()

save_manuscript_fig(p, "fig_bias_forest", 6, 5)

