# R/fig_v_standard_posterior.R

suppressPackageStartupMessages({
  library(brms); library(ggplot2); library(readr); library(dplyr); library(posterior)
})

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

m_std <- readRDS("output/publish/fit_standard_bias_only.rds")
draws <- as_draws_df(m_std)

v_draws <- data.frame(v = draws$`b_Intercept`)

# Prior overlay (Normal(0, 0.03))
x <- seq(-0.2, 0.2, length.out=400)
prior <- dnorm(x, mean=0, sd=0.03)

# Scale prior to match posterior density for visibility
# Get max density of posterior
post_density <- density(v_draws$v)
max_post_density <- max(post_density$y)
max_prior_density <- max(dnorm(x, mean=0, sd=0.03))
prior_scaled <- prior * (max_post_density / max_prior_density)

p <- ggplot(v_draws, aes(x=v)) +
  geom_histogram(aes(y=after_stat(density)), bins=60, alpha=0.6, fill="steelblue", color="white") +
  geom_line(aes(x=x, y=prior_scaled), data=data.frame(x=x, prior_scaled=prior_scaled), 
            color="darkred", linewidth=1.2, linetype="dashed") +
  geom_vline(xintercept=0, linetype="dotted", color="gray50", alpha=0.7) +
  labs(x="v(Standard) (drift)", y="Density",
       title="Posterior v(Standard) with tight prior overlay",
       subtitle="Prior: Normal(0, 0.03) | Posterior mean ≈ -0.036") +
  theme_minimal(base_size=11) +
  theme(plot.subtitle=element_text(size=9, color="gray40"))

ggsave("output/figures/fig_v_standard_posterior.png", p, width=6, height=4, dpi=300)
ggsave("output/figures/fig_v_standard_posterior.pdf", p, width=6, height=4)

cat("✓ Wrote output/figures/fig_v_standard_posterior.png\n")
cat("✓ Wrote output/figures/fig_v_standard_posterior.pdf\n")

# Print summary statistics
cat("\nPosterior summary:\n")
cat("  Mean:", round(mean(v_draws$v), 4), "\n")
cat("  SD:", round(sd(v_draws$v), 4), "\n")
cat("  95% CrI: [", round(quantile(v_draws$v, 0.025), 4), ", ", 
    round(quantile(v_draws$v, 0.975), 4), "]\n", sep="")
cat("  Prior: Normal(0, 0.03)\n")

