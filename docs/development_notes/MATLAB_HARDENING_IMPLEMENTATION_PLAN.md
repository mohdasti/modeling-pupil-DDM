# MATLAB Hardening Implementation Plan

## Overview

This document outlines the comprehensive hardening of the MATLAB pipeline to guarantee trial extraction reliability and provide full transparency through QC outputs.

## Key Changes Required

### 1. Event Code Discovery (Task A)
- **Current**: Hard-coded event codes (3040, 3041, 3042, 3044, 3048)
- **New**: Data-driven discovery with validation
- **Implementation**: 
  - Search task code repo for SetMarker/Datapixx calls
  - Validate against marker stream in data
  - Create codebook CSV

### 2. Timebase Reconciliation (Task B)
- **Current**: Assumes marker times and pupil times are in same timebase
- **New**: Explicit timebase conversion with validation
- **Implementation**:
  - Detect timebase type (PTB vs relative vs system)
  - Compute offset using logP alignment
  - Convert all times to PTB reference frame

### 3. Robust Trial Segmentation (Task C) - **CRITICAL**
- **Current**: Event-code only (fails if codes missing/wrong)
- **New**: Dual-mode with automatic fallback
  - **Mode 1**: Event-code segmentation (if validated)
  - **Mode 2**: logP-driven segmentation (always available if logP exists)
- **Implementation**:
  - Try event-code segmentation first
  - Validate: n_trials in [28, 30] and alignment residuals < 20ms
  - If fails, fall back to logP TrialST values
  - Never silently fail - always document reason

### 4. Comprehensive QC Outputs (Task D)
- **Current**: Limited QC visibility
- **New**: Full truth tables for every run
- **Outputs**:
  - `qc_matlab_run_trial_counts.csv`: Per-run extraction summary
  - `qc_matlab_marker_counts_by_run.csv`: Marker statistics
  - `qc_matlab_skip_reasons.csv`: Why runs were skipped
  - `qc_matlab_trial_level_flags.csv`: Per-trial QC flags
  - `MATLAB_AUDIT_REPORT.md`: Comprehensive audit report

## Implementation Strategy

### Phase 1: Helper Functions (DONE)
- ✅ `parse_logP_file.m`: Parse logP.txt to extract PTB times
- ✅ `discover_event_codes.m`: Discover event codes from repo/data

### Phase 2: Core Hardening (IN PROGRESS)
- ⏳ Update `process_single_run_improved()` to:
  - Try event-code segmentation
  - Fall back to logP if needed
  - Handle timebase conversion
  - Never drop trials silently

### Phase 3: QC Outputs (PENDING)
- ⏳ Create QC output functions
- ⏳ Generate audit report

## Key Design Decisions

1. **logP is ground truth**: If logP exists and has 30 trials, we should extract 30 trials
2. **Never silent failure**: If extraction fails, document why in skip_reasons.csv
3. **Timebase conversion**: All times converted to PTB reference frame for consistency
4. **Trial window**: Use logP TrialST as anchor, then apply fixed window offsets

## Expected Outcomes

After hardening:
- ≥95% of runs with logP should extract 28-30 trials
- All extraction failures documented with reasons
- Full transparency through QC outputs
- logP-driven fallback ensures robustness even if event codes fail

