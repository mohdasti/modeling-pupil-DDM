suppressPackageStartupMessages({ library(brms); library(bayesplot); library(dplyr); library(readr) })

fit <- readRDS("models/ddm_brms_main.rds")
d   <- readr::read_csv("data/derived/trials_with_pupil.csv")

# 1) Global RT distribution
png("models/ppc_rt_overall.png", width=1000, height=700, res=120)
pp_check(fit, type = "dens_overlay_grouped", resp = "rt")
dev.off()

# 2) Conditional accuracy function by RT quantiles
#    (rough sanity: faster errors in difficult conditions, etc.)
post_pred <- posterior_predict(fit, ndraws = 200)
# custom CAF omitted for brevity; add your CAF util if you have one

# 3) RT by evoked-pupil bins (monotonic trends)
d$evoked_bin <- cut_number(d$pupil_evoked_z, 5, labels = FALSE)
rt_obs <- d %>% group_by(evoked_bin) %>% summarize(m_rt = mean(rt))
readr::write_csv(rt_obs, "models/ppc_rt_by_evoked_bin.csv")
