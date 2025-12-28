# MATLAB Hardening Files - Directory Locations

This document lists the exact file paths for all critical hardening scripts that control the MATLAB pipeline behavior.

## Core Hardening Functions

### 1. `parse_logP_file.m`
**Location**: `01_data_preprocessing/matlab/parse_logP_file.m`

**Purpose**: Parses logP.txt files to extract PTB trial times (TrialST, BlankST, FixST, etc.)

**Key Features**:
- Handles header lines starting with `%`
- Case-insensitive column matching
- Trims whitespace from headers
- Returns struct with trial timing information

---

### 2. `convert_timebase.m`
**Location**: `01_data_preprocessing/matlab/convert_timebase.m`

**Purpose**: Converts pupil timestamps to PTB reference frame (same as logP times)

**Key Features**:
- Detects if timestamps are already PTB (absolute) or relative
- Three alignment methods:
  1. Already PTB (if timestamps > 1e6)
  2. Marker-based alignment (if available)
  3. Offset fitting (minimizes window_oob)
- Returns alignment diagnostics with confidence levels

---

### 3. `process_single_run_improved()`
**Location**: `01_data_preprocessing/matlab/BAP_Pupillometry_Pipeline.m` (lines 577-1433)

**Purpose**: Main function that processes a single run with fully corrected trial windows and phase labeling

**Key Features**:
- **Dual-mode segmentation**:
  - Primary: Event-code segmentation (validated against logP if available)
  - Fallback: logP-driven segmentation (if event-code fails)
- **Falsification checks**:
  - LogP plausibility validation
  - Anti-copy/paste checks (duplicate segment detection)
  - Timebase validation
  - Metadata integrity checks
- **Hardening behaviors**:
  - No silent defaults for session/run (fails hard if can't parse)
  - Only processes sessions 2-3 (InsideScanner tasks)
  - Validates run numbers (1-5)
  - Preserves `trial_in_run_raw` for behavioral merging
  - Uses PTB-aligned timestamps for trial extraction

**Function Signature**:
```matlab
function [run_data, run_quality] = process_single_run_improved(cleaned_data, raw_data, file_info, trial_offset, CONFIG)
```

---

### 4. `matlab_comprehensive_audit.m`
**Location**: `scripts/matlab_comprehensive_audit.m`

**Purpose**: Discovery/validation script for event codes, timebase, and segmentation

**Key Features**:
- Task A1: Searches task code repository for event marker definitions
- Task A2: Inspects marker stream from raw data
- Task A3: Parses logP and validates alignment
- Creates codebook of event codes
- Generates diagnostic outputs

---

## Supporting Functions

### 5. `parse_filename.m`
**Location**: `01_data_preprocessing/matlab/parse_filename.m`

**Purpose**: Standalone helper to parse subject, task, session, and run from filenames

**Key Features**:
- Strict validation: Only allows sessions 2-3, runs 1-5
- Lenient parsing: Handles spaces, case variations
- Fails hard: Returns empty metadata if parsing fails (no silent defaults)

---

### 6. `validate_logP_plausibility.m`
**Location**: `01_data_preprocessing/matlab/validate_logP_plausibility.m`

**Purpose**: Validates logP timing intervals for plausibility

**Key Features**:
- Checks trial count (should be ~30)
- Validates timing intervals are monotonic
- Checks for reasonable durations

---

## Audit Scripts

### 7. `run_matlab_audit.m`
**Location**: `01_data_preprocessing/matlab/run_matlab_audit.m`

**Purpose**: Main audit runner that executes all audit functions

**Calls**:
- `audit_discovery.m` - Discovery audit (Task A)
- `audit_parse_failures.m` - Parse failure logging
- `audit_qc_crosscheck.m` - Cross-check against BAP_QC spreadsheet (Task B)
- `audit_logp_integrity.m` - logP integrity validation (Task C)
- `audit_timebase_iti.m` - Timebase and ITI validation (Task D)
- `audit_regenerate_qc.m` - Regenerate QC artifacts (Task E)
- `generate_signoff_report.m` - Generate sign-off report (Task F)

---

## File Structure Summary

```
modeling-pupil-DDM/
├── 01_data_preprocessing/
│   └── matlab/
│       ├── BAP_Pupillometry_Pipeline.m          (Main pipeline, contains process_single_run_improved)
│       ├── parse_logP_file.m                     (logP parsing)
│       ├── convert_timebase.m                    (Timebase alignment)
│       ├── parse_filename.m                      (Filename parsing)
│       ├── validate_logP_plausibility.m         (logP validation)
│       ├── run_matlab_audit.m                    (Audit runner)
│       ├── audit_discovery.m                     (Discovery audit)
│       ├── audit_parse_failures.m                (Parse failure logging)
│       ├── audit_qc_crosscheck.m                 (QC cross-check)
│       ├── audit_logp_integrity.m                (logP integrity)
│       ├── audit_timebase_iti.m                  (Timebase/ITI checks)
│       ├── audit_regenerate_qc.m                 (QC regeneration)
│       └── generate_signoff_report.m              (Sign-off report)
│
└── scripts/
    └── matlab_comprehensive_audit.m               (Comprehensive audit script)
```

---

## Quick Reference: What Each File Controls

| File | Controls |
|------|----------|
| `parse_logP_file.m` | How logP.txt files are parsed (trial timing extraction) |
| `convert_timebase.m` | How pupil timestamps are aligned to PTB reference frame |
| `process_single_run_improved()` | **Main processing logic**: segmentation, trial extraction, QC flags |
| `parse_filename.m` | How session/run are extracted from filenames (strict validation) |
| `validate_logP_plausibility.m` | Whether logP data passes plausibility checks |
| `matlab_comprehensive_audit.m` | Discovery and validation of event codes and timebase |

---

## Notes

- **`process_single_run_improved()`** is the most critical function - it contains all the hardening logic
- All functions are in `01_data_preprocessing/matlab/` except `matlab_comprehensive_audit.m` which is in `scripts/`
- The main pipeline file (`BAP_Pupillometry_Pipeline.m`) contains both the pipeline runner and `process_single_run_improved()`

