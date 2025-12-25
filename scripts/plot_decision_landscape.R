# scripts/plot_decision_landscape.R
# Generate a 3D surface plot of the Wald (Inverse Gaussian) PDF
# for visualizing the "Crunch Point" in decision-making

library(grDevices)

# 1. Define the Wald PDF
# Formula: f(t|v,a) = (a / sqrt(2*pi*t^3)) * exp(-((a - v*t)^2)/(2*t))
wald_pdf <- function(t, v, a = 2.28) {
  # Avoid division by zero and negative values
  t <- pmax(t, 1e-5)
  
  term1 <- a / sqrt(2 * pi * t^3)
  term2 <- exp(-((a - v * t)^2) / (2 * t))
  
  return(term1 * term2)
}

# 2. Setup high-resolution grid
# X-axis: Reaction Time (t) from 0.1 to 2.5s
# Y-axis: Drift Rate (v) from 0 to 3.0
t_seq <- seq(0.1, 2.5, length.out = 100)
v_seq <- seq(0, 3.0, length.out = 100)

# Create grid and compute probability density
grid <- expand.grid(t = t_seq, v = v_seq)
z_vals <- matrix(wald_pdf(grid$t, grid$v), nrow = length(t_seq), ncol = length(v_seq))

# 3. Create Color Palette (Viridis-like)
n_colors <- 100
colors <- hcl.colors(n_colors, "Viridis")

# Compute facet centers for color mapping
z_facet_center <- (z_vals[-1, -1] + z_vals[-1, -ncol(z_vals)] + 
                   z_vals[-nrow(z_vals), -1] + z_vals[-nrow(z_vals), -ncol(z_vals)]) / 4
z_facet_range <- cut(z_facet_center, n_colors)

# 4. Save High-Res PNG (300 DPI)
output_dir <- "output/figures"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

png_file <- file.path(output_dir, "fig_decision_landscape_3d.png")
png(png_file, width = 3000, height = 2400, res = 300)

par(mar = c(4, 4, 3, 2))

# Create 3D surface plot
persp(t_seq, v_seq, z_vals,
      theta = 40, phi = 30, expand = 0.6,
      col = colors[z_facet_range],
      border = NA,
      shade = 0.5,
      ticktype = "detailed",
      xlab = "Reaction Time (s)", 
      ylab = "Drift Rate (v)", 
      zlab = "Probability Density",
      main = "The 'Crunch Point': Collapse of Decision Efficiency")

dev.off()

cat("3D decision landscape plot saved to:", png_file, "\n")













