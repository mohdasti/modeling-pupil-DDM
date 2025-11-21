# R/fig_ppc_small_multiples.R

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(ggplot2); library(tidyr)
})

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

ppc <- read_csv("output/publish/ppc_joint_minimal.csv", show_col_types = FALSE)

# Identify best/median/worst by qp_rmse
ord <- ppc %>% arrange(qp_rmse)

pick <- bind_rows(
  slice_head(ord, n=1) %>% mutate(rank = "Best"),
  slice(ord, floor(nrow(ord)/2)) %>% mutate(rank = "Median"),
  slice_tail(ord, n=1) %>% mutate(rank = "Worst")
)

# Create readable cell labels
pick <- pick %>%
  mutate(
    cell_label = paste0(task, "-", effort_condition, "\n", difficulty_level),
    cell_label = factor(cell_label, levels = cell_label[order(qp_rmse)])
  )

# Plot bars for QP and KS to highlight variation
pm <- pick %>%
  pivot_longer(cols=c(qp_rmse, ks), names_to="metric", values_to="value") %>%
  mutate(
    metric_label = ifelse(metric == "qp_rmse", "QP RMSE", "KS Statistic"),
    rank = factor(rank, levels = c("Best", "Median", "Worst"))
  )

# Add threshold lines
thresh_qp <- 0.12  # QP RMSE threshold
thresh_ks <- 0.20  # KS threshold

p <- ggplot(pm, aes(x=rank, y=value, fill=rank)) +
  geom_col(alpha=0.7, width=0.6) +
  geom_hline(data=data.frame(metric_label="QP RMSE", y=thresh_qp), 
             aes(yintercept=y), linetype="dashed", color="red", alpha=0.6) +
  geom_hline(data=data.frame(metric_label="KS Statistic", y=thresh_ks), 
             aes(yintercept=y), linetype="dashed", color="red", alpha=0.6) +
  facet_wrap(~metric_label, scales="free_y") +
  scale_fill_manual(values=c("Best"="darkgreen", "Median"="orange", "Worst"="darkred")) +
  labs(x=NULL, y="Value",
       title="PPC Summary: Best / Median / Worst Cells (by QP RMSE)",
       subtitle=paste0("Best: ", pick$cell_label[1], " | Median: ", pick$cell_label[2], " | Worst: ", pick$cell_label[3]),
       fill="Rank") +
  theme_minimal(base_size=11) +
  theme(
    plot.subtitle=element_text(size=9, color="gray40"),
    legend.position="none",
    strip.text=element_text(face="bold")
  )

ggsave("output/figures/fig_ppc_small_multiples.png", p, width=8, height=4.5, dpi=300)
ggsave("output/figures/fig_ppc_small_multiples.pdf", p, width=8, height=4.5)

cat("✓ Wrote output/figures/fig_ppc_small_multiples.png\n")
cat("✓ Wrote output/figures/fig_ppc_small_multiples.pdf\n")

# Print details
cat("\nSelected cells:\n")
for(i in 1:nrow(pick)) {
  cat(sprintf("  %s: %s (QP RMSE: %.4f, KS: %.4f)\n", 
              pick$rank[i], pick$cell[i], pick$qp_rmse[i], pick$ks[i]))
}

