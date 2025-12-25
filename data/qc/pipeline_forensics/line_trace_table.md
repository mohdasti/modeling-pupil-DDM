# Line Trace Table: Where ses/run Are Created/Overwritten

| Stage | Variable | Source | Exact Line(s) | Evidence | Risk |
|-------|----------|--------|---------------|----------|------|
| **MATLAB** | `session` | Filename regex | 254-259 | `session_match = regexp(filename, 'session(\d+)', 'tokens')` | Low - correct extraction |
| **MATLAB** | `run` | Filename regex | 261-266 | `run_match = regexp(filename, 'run(\d+)', 'tokens')` | Low - correct extraction |
| **MATLAB** | `session` (stored) | file_info.session | 189 | `sessions{i} = metadata.session` | Low - correct storage |
| **MATLAB** | `run` (stored) | file_info.run | 190 | `runs(i) = metadata.run` | Low - correct storage |
| **MATLAB** | **`ses` (output)** | **file_info.session** | **543** | **`trial_table.ses = repmat(str2double(file_info.session{1}), ...)`** | **FIXED - now outputs ses** |
| **MATLAB** | `run` (output) | file_info.run | 543 | `trial_table.run = repmat(file_info.run, ...)` | Low - correct |
| **R Merger** | `ses` (from behavioral) | `bap_beh_trialdata_v2.csv` session_num | 93 | `ses = session_num` | **FIXED - now maps correctly** |
| **R Merger** | `run` (merge key) | Flat files | 192 or 207 | Merge on `(ses, run, trial_in_run)` or `(ses, run, trial_index)` | **FIXED - includes ses** |
| **R Merger** | `ses` (after merge) | Behavioral or pupil | 267 | `ses = coalesce(ses, ses_behav, NA_integer_)` | **FIXED - gets from behavioral** |
| **R Merger** | `run` (preserved) | Pupil (preferred) | 269 | `run = coalesce(run, run_behav)` | **FIXED - preserves pupil run** |
| **QMD** | `ses` (from pupil_ready) | Flat files | ~422 | `ses = if("ses" %in% names(.)) as.integer(ses)` | **FIXED - extracts from flat** |
| **QMD** | `ses` (from behav_ready) | Behavioral session_num | ~6136 | `ses = if("ses" %in% names(.)) ses else if("session_num" %in% names(.)) session_num` | **FIXED - maps session_num** |
| **QMD** | `run` (join key) | Flat files | 6160 | `by = c("subject_id", "task", "ses", "run", "trial_index")` | **FIXED - includes ses in join** |
| **QMD** | `run` (preserved) | Pupil (preferred) | 6162-6164 | `run = coalesce(run_pupil, run_behav, run)` | **FIXED - preserves pupil run** |
| **QMD** | `ses` (preserved) | Behavioral (preferred) | 6162-6164 | `ses = coalesce(ses_behav, ses_pupil, ses)` | **FIXED - gets from behavioral** |
| **QMD** | `trial_id` | All identifiers | 827, 3350, 3489, 4153 | `paste(subject_id, task, ses, run, trial_index, sep = ":")` | **FIXED - includes ses** |

## Assertions Added

| Location | Assertion | Line |
|----------|-----------|------|
| **QMD** | `ses %in% c(2,3)` | ~6166 |
| **QMD** | `run %in% 1:5` | ~6167 |
| **QMD** | No NA ses | ~6169 |

## Summary of Fixes

1. **MATLAB:** Added `ses` column to flat file output (line 543)
2. **R Merger:** Maps `session_num` → `ses` in behavioral data (line 93)
3. **R Merger:** Includes `ses` in merge keys (lines 192, 207)
4. **R Merger:** Preserves `run` from pupil, gets `ses` from behavioral (lines 269, 267)
5. **QMD:** Extracts `ses` from flat files (line ~422)
6. **QMD:** Maps `session_num` → `ses` in behavioral (line ~6136)
7. **QMD:** Includes `ses` in join keys (line 6160)
8. **QMD:** Preserves `run` from pupil, gets `ses` from behavioral (lines 6162-6164)
9. **QMD:** Includes `ses` in `trial_id` (lines 827, 3350, 3489, 4153)
10. **QMD:** Adds assertions for ses and run validity (lines ~6166-6169)

