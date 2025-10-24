suppressPackageStartupMessages({ library(dplyr); library(readr) })

raw <- read_csv("data/raw/trials_with_eyetracking.csv")

# assume columns: pupil (raw), time_ms, trial_id, stim_on_ms, luminance, blink_flag, subj, condition
# define baseline (-500..0 ms) and evoked (300..1200 ms) windows relative to stimulus
feat <- raw %>%
  group_by(trial_id) %>%
  summarize(
    pupil_baseline = mean(pupil[time_ms >= (stim_on_ms-500) & time_ms <= stim_on_ms &
                                blink_flag == 0], na.rm = TRUE),
    pupil_evoked   = mean(pupil[time_ms >= (stim_on_ms+300) & time_ms <= (stim_on_ms+1200) &
                                blink_flag == 0], na.rm = TRUE),
    luminance      = first(luminance),
    subj = first(subj),
    condition = first(condition)
  ) %>%
  group_by(subj) %>%
  mutate(
    pupil_baseline_z = scale(pupil_baseline)[,1],
    pupil_evoked_z   = scale(pupil_evoked)[,1],
    luminance_z      = scale(luminance)[,1]
  ) %>% ungroup()

beh <- read_csv("data/raw/behavior.csv")  # must include trial_id, rt, choice, prev_choice, prev_outcome
out <- beh %>% inner_join(feat, by = "trial_id")

readr::write_csv(out, "data/derived/trials_with_pupil.csv")
