suppressPackageStartupMessages({library(brms); library(tidyverse); library(posterior)})
dir.create("output/figures", recursive=TRUE, showWarnings=FALSE)

# Try multiple possible locations for the model file
model_file <- if (file.exists("output/publish/fit_primary_vza.rds")) {
  "output/publish/fit_primary_vza.rds"
} else if (file.exists("output/publish/fit_primary_vza_vEff_censored.rds")) {
  "output/publish/fit_primary_vza_vEff_censored.rds"
} else {
  stop("Model file not found. Checked: output/publish/fit_primary_vza*.rds")
}

fit <- readRDS(model_file)

# Extract NDT parameters
ndt_vars <- names(as_draws_df(fit))[grepl("^b_ndt_", names(as_draws_df(fit)))]
cat("NDT parameters found:", paste(ndt_vars, collapse=", "), "\n")

draws <- as_draws_df(fit, variable="^b_ndt_", regex=TRUE)

# Get prior specifications from model
# NDT intercept: Normal(log(0.23), 0.12) on log scale
ndt_intercept_prior_mean <- log(0.23)
ndt_intercept_prior_sd <- 0.12

# Check if we have task/effort effects
has_task <- "b_ndt_taskVDT" %in% names(draws)
has_effort <- any(grepl("effort", names(draws), ignore.case=TRUE))

# Create prior vs posterior plot for intercept
ndt_intercept_draws <- draws |> select(b_ndt_Intercept) |> pull()

# Prior density on log scale
ndt_prior <- tibble(
  x_log = seq(log(0.1), log(0.4), length.out=400),
  d = dnorm(x_log, mean=ndt_intercept_prior_mean, sd=ndt_intercept_prior_sd),
  type = "Prior"
) |>
  mutate(x_natural = exp(x_log))

# Posterior on log scale (will transform to natural)
post_intercept <- tibble(x_log = as.numeric(ndt_intercept_draws)) |>
  mutate(x_natural = exp(x_log), type = "Posterior")

# Main plot: Intercept
p_intercept <- ggplot() +
  geom_line(data=ndt_prior, aes(x=x_natural, y=d, color="Prior"), 
            alpha=0.7, linewidth=0.8) +
  geom_density(data=post_intercept, aes(x=x_natural, color="Posterior", fill="Posterior"), 
               linewidth=0.8, alpha=0.3) +
  scale_color_manual(
    name=NULL,
    values=c("Prior"="gray50", "Posterior"="steelblue")
  ) +
  scale_fill_manual(
    name=NULL,
    values=c("Posterior"="steelblue"),
    guide="none"
  ) +
  labs(
    x="t0 (s)", 
    y="Density", 
    title="NDT Intercept: Prior vs Posterior",
    subtitle="Prior: Normal(log(0.23), 0.12) on log scale -> ~0.23 s on natural scale"
  ) +
  theme_minimal(base_size=11) +
  theme(
    plot.title = element_text(size=12, face="bold", hjust=0.5),
    plot.subtitle = element_text(size=9, color="gray50", hjust=0.5),
    legend.position="top"
  )

# If we have task/effort effects, create additional plots
plots_list <- list(p_intercept)

if (has_task) {
  task_draws <- draws |> select(contains("task")) |> pull()
  if (length(task_draws) > 0 && !all(is.na(task_draws))) {
    # Task effect prior: typically Normal(0, 0.15) on log scale
    task_prior <- tibble(
      x_log = seq(-0.3, 0.3, length.out=400),
      d = dnorm(x_log, mean=0, sd=0.15)
    ) |>
      mutate(x_natural = exp(x_log))
    
    post_task <- tibble(x_log = as.numeric(task_draws)) |>
      mutate(x_natural = exp(x_log))
    
    p_task <- ggplot() +
      geom_line(data=task_prior, aes(x=x_natural, y=d, color="Prior"), 
                alpha=0.7, linewidth=0.8) +
      geom_density(data=post_task, aes(x=x_natural, color="Posterior", fill="Posterior"), 
                   linewidth=0.8, alpha=0.3) +
      scale_color_manual(
        name=NULL,
        values=c("Prior"="gray50", "Posterior"="steelblue")
      ) +
      scale_fill_manual(name=NULL, values=c("Posterior"="steelblue"), guide="none") +
      labs(
        x="Multiplicative factor", 
        y="Density", 
        title="NDT Task Effect: Prior vs Posterior",
        subtitle="Prior: Normal(0, 0.15) on log scale"
      ) +
      theme_minimal(base_size=11) +
      theme(
        plot.title = element_text(size=12, face="bold", hjust=0.5),
        plot.subtitle = element_text(size=9, color="gray50", hjust=0.5),
        legend.position="top"
      )
    
    plots_list <- c(plots_list, list(p_task))
  }
}

if (has_effort) {
  effort_col <- names(draws)[grepl("effort", names(draws), ignore.case=TRUE)][1]
  effort_draws <- draws |> select(!!sym(effort_col)) |> pull()
  if (length(effort_draws) > 0 && !all(is.na(effort_draws))) {
    # Effort effect prior: typically Normal(0, 0.15) on log scale
    effort_prior <- tibble(
      x_log = seq(-0.3, 0.3, length.out=400),
      d = dnorm(x_log, mean=0, sd=0.15)
    ) |>
      mutate(x_natural = exp(x_log))
    
    post_effort <- tibble(x_log = as.numeric(effort_draws)) |>
      mutate(x_natural = exp(x_log))
    
    p_effort <- ggplot() +
      geom_line(data=effort_prior, aes(x=x_natural, y=d, color="Prior"), 
                alpha=0.7, linewidth=0.8) +
      geom_density(data=post_effort, aes(x=x_natural, color="Posterior", fill="Posterior"), 
                   linewidth=0.8, alpha=0.3) +
      scale_color_manual(
        name=NULL,
        values=c("Prior"="gray50", "Posterior"="steelblue")
      ) +
      scale_fill_manual(name=NULL, values=c("Posterior"="steelblue"), guide="none") +
      labs(
        x="Multiplicative factor", 
        y="Density", 
        title="NDT Effort Effect: Prior vs Posterior",
        subtitle="Prior: Normal(0, 0.15) on log scale"
      ) +
      theme_minimal(base_size=11) +
      theme(
        plot.title = element_text(size=12, face="bold", hjust=0.5),
        plot.subtitle = element_text(size=9, color="gray50", hjust=0.5),
        legend.position="top"
      )
    
    plots_list <- c(plots_list, list(p_effort))
  }
}

# Combine plots
if (length(plots_list) > 1) {
  library(patchwork)
  p <- wrap_plots(plots_list, ncol=1)
  ggsave("output/figures/fig_ndt_prior_posterior.pdf", p, width=6, height=3.8 * length(plots_list))
} else {
  ggsave("output/figures/fig_ndt_prior_posterior.pdf", p_intercept, width=6, height=3.8)
}

cat("Created NDT prior vs posterior plot: output/figures/fig_ndt_prior_posterior.pdf\n")

