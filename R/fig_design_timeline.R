suppressPackageStartupMessages({library(ggplot2); library(grid)})
dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

# Timeline segments
df <- data.frame(
  segment = c("Standard\n(100 ms)","ISI\n(500 ms)","Target\n(100 ms)","Blank\n(250 ms)","Response window\n(3000 ms)"),
  start   = c(0, 100, 600, 700, 950),
  end     = c(100, 600, 700, 950, 3950),
  y_pos   = c(0, 0, 0, 0, 0),
  color   = c("#E8E8E8", "#D0D0D0", "#B8B8B8", "#A0A0A0", "#4A90E2")
)

# Time markers
time_marks <- data.frame(
  x = c(0, 100, 600, 700, 950, 3950),
  label = c("0", "100", "600", "700", "950", "3950")
)

p <- ggplot() +
  # Timeline segments
  geom_segment(data=df, aes(x=start, xend=end, y=y_pos, yend=y_pos, color=color), 
               linewidth=8, lineend="round", show.legend=FALSE) +
  scale_color_identity() +
  # Segment labels above
  geom_text(data=df[1:4,], aes(x=(start+end)/2, y=0.3, label=segment), 
            size=3.2, hjust=0.5, vjust=0) +
  geom_text(data=df[5,], aes(x=(start+end)/2, y=0.3, label=segment), 
            size=3.2, hjust=0.5, vjust=0) +
  # Time markers below
  geom_segment(data=time_marks, aes(x=x, xend=x, y=-0.15, yend=-0.25), linewidth=0.5) +
  geom_text(data=time_marks, aes(x=x, y=-0.35, label=paste0(label, " ms")), 
            size=2.8, hjust=0.5) +
  # Arrow indicating RT measurement
  annotate("segment", x=950, xend=3950, y=-0.6, yend=-0.6, 
           linewidth=1.5, color="#E74C3C", 
           arrow=arrow(length=unit(5,"pt"), type="closed")) +
  annotate("text", x=2450, y=-0.75, 
           label="RT measured from response-screen onset", 
           size=3.4, color="#E74C3C", fontface="italic") +
  # Vertical line at response screen onset
  geom_vline(xintercept=950, linetype="dashed", linewidth=0.8, color="#E74C3C", alpha=0.6) +
  annotate("text", x=950, y=0.5, label="Response\nscreen", size=2.8, color="#E74C3C", 
           hjust=0.5, vjust=0) +
  # Limits and theme
  xlim(-50, 4000) +
  ylim(-1.1, 0.6) +
  theme_minimal(base_size=11) + 
  theme(
    axis.text=element_blank(), 
    axis.title=element_blank(), 
    panel.grid=element_blank(), 
    plot.margin=margin(15,20,15,20),
    plot.background=element_rect(fill="white", color=NA)
  )

ggsave("output/figures/fig_design_timeline.pdf", p, width=10, height=3.5)

