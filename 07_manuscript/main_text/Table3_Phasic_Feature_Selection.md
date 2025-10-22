# Table 3. Phasic Feature Selection

| Feature | # Models | Total AIC Weight | Stacking Weight | Best Model ID |
|---|---|---|---|---|
| **slope** | 1 | **0.922** | **0.922** | slope_wp_resid |
| peak | 1 | 0.016 | 0.016 | peak_wp_resid |
| AUC | 1 | 0.020 | 0.020 | AUC_wp_resid |
| early | 1 | 0.021 | 0.021 | early_wp_resid |
| late | 1 | 0.021 | 0.021 | late_wp_resid |

*Note*: **Slope** feature (200–900 ms) dominates model selection with 92.2% AIC weight. All alternative features (peak, AUC, early, late) show minimal support (≤2.1%). Timing window: slope = 200–900 ms, early = 200–700 ms, late = 700–1500 ms, peak/AUC = 300–1200 ms.
