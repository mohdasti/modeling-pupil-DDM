suppressPackageStartupMessages({
  library(ggplot2)
  library(grid)
  library(dplyr)
})

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

# Simulate a drift diffusion process for visualization
# Parameters
a <- 1.5  # boundary separation
z <- 0.6  # starting point bias (0.6 = closer to upper boundary "different")
v <- 0.8  # drift rate (positive = drift toward "different")
ndt <- 0.25  # non-decision time (250ms)

# Simulate evidence accumulation (Wiener process)
set.seed(123)
dt <- 0.005  # Smaller time step for smoother simulation
max_time <- 2
time_points <- seq(0, max_time, by = dt)
evidence <- numeric(length(time_points))
evidence[1] <- z * a  # start at biased position

# Simulate drift with noise (Wiener process)
hit_index <- NA
hit_boundary <- NA

for (i in 2:length(time_points)) {
  # Drift component + noise (Wiener process)
  new_evidence <- evidence[i-1] + v * dt + rnorm(1, 0, sqrt(dt))
  
  # Check if boundary would be crossed
  if (new_evidence >= a && evidence[i-1] < a) {
    # Would cross upper boundary - interpolate exact crossing point
    # Linear interpolation: find where evidence = a between evidence[i-1] and new_evidence
    fraction <- (a - evidence[i-1]) / (new_evidence - evidence[i-1])
    hit_index <- i - 1 + fraction
    hit_boundary <- a
    # Store the point just before crossing (keep it below boundary)
    evidence[i-1] <- evidence[i-1]  # Keep previous point as is
    break
  }
  if (new_evidence <= 0 && evidence[i-1] > 0) {
    # Would cross lower boundary - interpolate exact crossing point
    fraction <- (0 - evidence[i-1]) / (new_evidence - evidence[i-1])
    hit_index <- i - 1 + fraction
    hit_boundary <- 0
    break
  }
  
  # Store this point (it's still within boundaries)
  evidence[i] <- new_evidence
}

# If boundary was hit, truncate to points before crossing and add final boundary point
if (!is.na(hit_index)) {
  # Get the index of the last point before crossing
  last_safe_index <- floor(hit_index)
  
  # Truncate to points strictly before the boundary
  if (last_safe_index > 0) {
    evidence <- evidence[1:last_safe_index]
    time_points <- time_points[1:last_safe_index]
    
    # Calculate exact crossing time
    exact_time <- time_points[length(time_points)] + (hit_index - last_safe_index) * dt
    
    # Add the exact boundary crossing point as final point
    time_points <- c(time_points, exact_time)
    evidence <- c(evidence, hit_boundary)
  }
  decision_time <- exact_time
} else {
  # No boundary hit (shouldn't happen with reasonable parameters)
  decision_time <- time_points[length(time_points)]
}

total_rt <- ndt + decision_time

# Create data frame for plotting
df <- data.frame(
  time = c(rep(0, length(time_points)), time_points),
  evidence = c(rep(z * a, length(time_points)), evidence),
  phase = c(rep("ndt", length(time_points)), rep("decision", length(time_points)))
)

# Calculate arrow positions for drift rate label
arrow_start_x <- ndt + 0.2
arrow_end_x <- ndt + 0.35
arrow_mid_x <- (arrow_start_x + arrow_end_x) / 2
arrow_start_y <- z * a + 0.05
arrow_end_y <- z * a + 0.25
arrow_mid_y <- (arrow_start_y + arrow_end_y) / 2

# Create the plot with improved label positioning
p <- ggplot() +
  # Non-decision time region (shaded)
  annotate("rect", xmin = 0, xmax = ndt, ymin = -0.15, ymax = a + 0.15, 
           fill = "gray90", alpha = 0.3, color = NA) +
  annotate("text", x = ndt/2, y = a/2, label = "Non-decision\ntime (t₀)", 
           size = 3.8, color = "gray40", fontface = "italic") +
  
  # Decision time region
  annotate("rect", xmin = ndt, xmax = total_rt, ymin = -0.15, ymax = a + 0.15, 
           fill = "lightblue", alpha = 0.2, color = NA) +
  
  # Upper boundary ("different") - labels on right side
  geom_hline(yintercept = a, linetype = "solid", linewidth = 2, color = "#E74C3C") +
  annotate("text", x = total_rt + .4, y = a + 0.05, label = '"Different"', 
           size = 4.8, color = "#E74C3C", fontface = "bold", hjust = 0, vjust = 0) +
  annotate("text", x = total_rt + 0.4, y = a - 0.08, label = "Upper boundary (a)", 
           size = 3.5, color = "#E74C3C", hjust = 0, vjust = 1) +
  
  # Lower boundary ("same") - labels on right side
  geom_hline(yintercept = 0, linetype = "solid", linewidth = 2, color = "#3498DB") +
  annotate("text", x = total_rt + 0.4, y = 0 - 0.05, label = '"Same"', 
           size = 4.8, color = "#3498DB", fontface = "bold", hjust = 0, vjust = 1) +
  annotate("text", x = total_rt + 0.4, y = 0 + 0.08, label = "Lower boundary", 
           size = 3.5, color = "#3498DB", hjust = 0, vjust = 0) +
  
  # Evidence accumulation path (draw first so other elements overlay)
  # Only include points up to and including the boundary hit
  geom_line(data = data.frame(
              time = time_points + ndt,
              evidence = evidence
            ),
            aes(x = time, y = evidence), 
            linewidth = 2, color = "#2C3E50") +
  
  # Starting point (bias) - label BELOW the point
  geom_point(aes(x = ndt, y = z * a), size = 5, color = "#9B59B6", fill = "white", stroke = 2.5, shape = 21) +
  annotate("segment", x = ndt, xend = ndt, y = 0, yend = z * a, 
           linetype = "dashed", linewidth = 1, color = "#9B59B6", alpha = 0.7) +
  annotate("text", x = ndt, y = z * a - 0.25, label = "z (starting point bias)", 
           size = 3.8, color = "#9B59B6", fontface = "bold", hjust = 0.5, vjust = 1.5 ) +
  
  # Drift direction arrow - label BELOW the arrow
  annotate("segment", 
           x = arrow_start_x, xend = arrow_end_x, 
           y = arrow_start_y, yend = arrow_end_y,
           arrow = arrow(length = unit(0.18, "inches"), type = "closed"),
           linewidth = 1.2, color = "#27AE60") +
  annotate("text", x = arrow_mid_x, y = arrow_mid_y - 0.25, 
           label = "Drift rate (v)", size = 3.8, color = "#27AE60", fontface = "bold", 
           hjust = 1.1, vjust = 1) +
  
  # Decision time marker - already below, improve spacing
  geom_vline(xintercept = total_rt, linetype = "dashed", linewidth = 1.2, color = "#E67E22") +
  annotate("text", x = total_rt, y = -0.25, label = "RT", 
           size = 4, color = "#E67E22", fontface = "bold", hjust = 1.2, vjust = 0) +
  annotate("text", x = total_rt, y = -0.4, 
           label = paste0("= t₀ + decision time\n≈ ", round(total_rt, 2), " s"), 
           size = 3.2, color = "#E67E22", hjust = -0.2, vjust = 0) +
  
  # Time axis labels - improve spacing
  annotate("segment", x = 0, xend = 0, y = -0.15, yend = -0.2, linewidth = 1) +
  annotate("text", x = 0, y = -0.3, label = "0", size = 3.5, hjust = 0.5, vjust = 0) +
  annotate("segment", x = ndt, xend = ndt, y = -0.15, yend = -0.2, linewidth = 1) +
  annotate("text", x = ndt, y = -0.3, label = paste0("t₀\n(", round(ndt, 2), "s)"), 
           size = 3.5, hjust = 0.5, vjust = 0.6) +
  
  # Labels and theme
  labs(
    x = "Time (seconds)",
    y = "Evidence Accumulation",
    title = "Drift Diffusion Model: Evidence Accumulation Process"
  ) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.3)), limits = c(-0.1, total_rt + 0.6)) +
  scale_y_continuous(expand = expansion(mult = c(0.2, 0.15)), limits = c(-0.6, a + 0.4)) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(size = 15, face = "bold", hjust = 0.5, margin = margin(b = 20)),
    axis.title = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 10),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "gray90", linewidth = 0.5),
    panel.grid.major.y = element_line(color = "gray90", linewidth = 0.5),
    plot.margin = margin(25, 50, 30, 25),
    plot.background = element_rect(fill = "white", color = NA)
  )

# Save figure
ggsave("output/figures/fig_ddm_process.pdf", p, width = 10, height = 6.5, device = "pdf")
ggsave("output/figures/fig_ddm_process.png", p, width = 10, height = 6.5, dpi = 300, device = "png")

cat("✓ Created DDM process figure: output/figures/fig_ddm_process.pdf\n")
cat("✓ Created DDM process figure: output/figures/fig_ddm_process.png\n")

