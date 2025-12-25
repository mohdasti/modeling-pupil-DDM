# Comprehensive Pipeline Audit Prompt for LLM

## Context

I am working on a pupillometry analysis pipeline for a dissertation. We've discovered several issues during data preparation and need a systematic audit to ensure we're not losing valid pupil data or incorrectly including invalid trials.

## The Study Design

- **Participants:** 50+ older adults
- **Sessions:** 3 sessions per participant
  - **Session 1:** Structural imaging only, NO tasks (ADT/VDT)
  - **Session 2:** ADT/VDT tasks (InsideScanner, with eye tracker)
  - **Session 3:** ADT/VDT tasks (InsideScanner, with eye tracker)
- **Tasks:** ADT (auditory) and VDT (visual)
- **Runs:** Each task divided into 5 runs (30 trials each = 150 trials total)
- **Practice/Outside-Scanner:** Collected WITHOUT eye tracker (should NOT be in pupil datasets)

## Current Dataset

- **Final TRIALLEVEL:** 1,425 trials
- **Sessions:** 2-3 only
- **Known issue:** `run` column equals `ses` (run information lost)

## The Pipeline (3 Stages)

### Stage 1: MATLAB Processing
**File:** `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m`

**What it does:**
1. Reads from: `BAP_cleaned/*_cleaned.mat` (cleaned pupil data)
2. Also reads: `data/sub-*/ses-*/InsideScanner/*_eyetrack.mat` (raw files for event codes)
3. Processes pupil time series, downsamples to 250Hz
4. Creates trial boundaries from event codes
5. Outputs: `BAP_processed/{subject}_{task}_flat.csv`

**Key questions to audit:**
1. Does it filter for `InsideScanner` only? (Line 296 shows it reads from InsideScanner, but does it filter BAP_cleaned files?)
2. Does it filter for sessions 2-3 only? (No explicit filtering found - processes all sessions in BAP_cleaned)
3. How does it extract run number? (From filename: `run(\d+)` - line 261-266)
4. How does it extract session? (From filename: `session(\d+)` - line 254-259)
5. Does it process practice/outside-scanner files if they're in BAP_cleaned? (Likely YES - no filtering)

**Files to examine:**
- `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m` (lines 1-750)
- Check `organize_files_by_session()` function (lines 150-230)
- Check `process_single_run_improved()` function (lines 350-550)

### Stage 2: R Merger
**File:** `01_data_preprocessing/r/Create merged flat file.R`

**What it does:**
1. Reads from: `BAP_processed/*_flat.csv` (pupil data from MATLAB)
2. Reads behavioral from: `bap_beh_trialdata_v2.csv` (17,971 trials, sessions 2-3)
3. Merges on: `(subject, task, run, trial_in_run)` or `(subject, task, run, trial_index)`
4. Outputs: `BAP_processed/{subject}_{task}_flat_merged.csv`

**Key questions to audit:**
1. Does it correctly match pupil to behavioral? (Uses trial_in_run when available)
2. What happens if a pupil trial has no behavioral match? (Left join - keeps pupil data)
3. What happens if a behavioral trial has no pupil match? (Dropped - only left join)
4. Could it include practice trials? (Only if they're in the flat files from MATLAB)

**Files to examine:**
- `01_data_preprocessing/r/Create merged flat file.R` (entire file)
- Check merge logic (lines 170-250)

### Stage 3: QMD Report
**File:** `02_pupillometry_analysis/generate_pupil_data_report.qmd`

**What it does:**
1. Reads from: `BAP_processed/*_flat_merged.csv` (preferred) or `*_flat.csv` (fallback)
2. Aggregates to trial level
3. Computes validity metrics, gates
4. Outputs: `BAP_analysis_ready_MERGED.csv` and `BAP_analysis_ready_TRIALLEVEL.csv`

**Key questions to audit:**
1. Where does `run` get set to equal `ses`? (Likely in line 6160 or when creating trial_id)
2. Does it filter for sessions 2-3? (Need to check)
3. Does it preserve run information from flat files? (Appears NO - run gets overwritten)

**Files to examine:**
- `02_pupillometry_analysis/generate_pupil_data_report.qmd` (lines 6150-6200)
- Check where `run` column is created/modified
- Check session filtering logic

## Critical Audit Questions

### 1. Practice/Outside-Scanner Trials

**Question:** How could practice/outside-scanner trials (collected WITHOUT eye tracker) have appeared in MERGED?

**Hypotheses:**
- A) MATLAB processed files from `BAP_cleaned` that were practice/outside-scanner
- B) R merger included behavioral data from practice sessions
- C) QMD didn't filter for sessions 2-3

**Action:** 
- Check if `BAP_cleaned` contains any `ses-1` or `OutsideScanner` files
- Check if MATLAB filters for InsideScanner (it doesn't - line 296 only reads from InsideScanner for raw files, but processes ALL files in BAP_cleaned)
- Check if R merger filters sessions
- Check if QMD filters sessions

### 2. Run/Session Mixup

**Question:** Where does `run` get set to equal `ses`?

**Hypotheses:**
- A) In QMD when creating MERGED (line 6160: join on `run` but `run` might be wrong)
- B) In R merger when creating flat_merged files
- C) In MATLAB (unlikely - extracts run from filename correctly)

**Action:**
- Trace `run` column through all three stages
- Check where `run` gets overwritten with `ses`
- Identify the exact line of code causing the issue

### 3. Data Loss

**Question:** Are we losing valid pupil data?

**Current situation:**
- MERGED has 1,425 unique trials
- Behavioral file has 17,971 trials
- Only 1,425 have pupil data (expected - goggles block tracking)

**Action:**
- Verify that all 1,425 trials in MERGED are valid scanner trials
- Check if any valid pupil trials were excluded
- Verify that practice/outside-scanner trials are NOT in MERGED

### 4. Session Filtering

**Question:** Is session filtering applied at each stage?

**Expected:**
- MATLAB: Should only process ses-2 and ses-3 (but doesn't filter - processes all)
- R Merger: Behavioral file only has ses-2 and ses-3 (good)
- QMD: Should filter for ses-2 and ses-3 (need to verify)

**Action:**
- Check each stage for session filtering
- Verify that ses-1 is excluded
- Verify that OutsideScanner is excluded

## Specific Code Locations to Audit

1. **MATLAB - File filtering:**
   - Line 83: `cleaned_files = dir(fullfile(CONFIG.cleaned_dir, '*_cleaned.mat'));`
   - Line 92: `file_groups = organize_files_by_session(cleaned_files);`
   - Line 231-267: `parse_filename()` function - extracts session and run
   - **Issue:** No filtering for InsideScanner or sessions 2-3

2. **R Merger - Behavioral source:**
   - Line 11: `behavioral_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"`
   - Line 187-194: Merge logic using `trial_in_run`
   - **Issue:** None identified - correctly uses behavioral file

3. **QMD - Run column:**
   - Line 6160: `by = c("subject_id", "task", "run", "trial_index")`
   - Line 825: `trial_id = paste(subject_id, task, run, trial_index, sep = ":")`
   - **Issue:** `run` might be wrong at this point

## Deliverables Requested

Please provide:

1. **Line-by-line audit** of the three pipeline stages
2. **Identification of exact locations** where:
   - Practice/outside-scanner trials could be included
   - Run information gets lost
   - Session filtering should be added
3. **Recommendations** for fixes:
   - Add session filtering to MATLAB
   - Fix run column in QMD
   - Verify no data loss
4. **Verification** that current 1,425 trials are all valid
5. **Confirmation** that we're not losing valid pupil data

## Files to Examine

1. `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m` (entire file)
2. `01_data_preprocessing/r/Create merged flat file.R` (entire file)
3. `02_pupillometry_analysis/generate_pupil_data_report.qmd` (lines 400-650, 6150-6200, 825)
4. Current dataset: `data/analysis_ready/BAP_analysis_ready_TRIALLEVEL.csv`

## Expected Outcomes

After audit, we should have:
- ✓ Clear understanding of where practice trials could enter
- ✓ Exact location where run gets lost
- ✓ Confirmation that 1,425 trials are all valid
- ✓ Recommendations for fixes
- ✓ Confidence that we're not losing valid data

---

**Please conduct a thorough, systematic audit of the entire pipeline and provide detailed findings.**

