# Supplementary Material S1: Participant and Data Screening Flow

## Figure S1. Participant and Analytic Sample Flow

![Participant flow](figures/s1_participant_flow.png)

*Note.* This figure is embedded in the chapter report as **Appendix A2.1** (`@fig-participant-flow` in `reports/chap3_ddm_results.qmd`). Regenerate with `Rscript 07_manuscript/scripts/plot_participant_flow.R` after updating pipeline outputs.

### Caption

Participant and analytic-sample flow for the BAP older-adult effort study (Chapter 3 DDM). Sixty-nine individuals enrolled; two were excluded post-enrollment (suspected MCI; possible essential tremor), yielding an analytic cohort of 67 older adults. After artifact screening, 18,097 behavioral trials were available; 240 trials with cue-locked RT < 0.20 s were excluded, leaving 17,857 trials for the primary behavioral DDM (probe-onset-locked RT; *N* = 67). Task-specific behavioral samples were *N* = 64 (ADT; 8,774 trials) and *N* = 65 (VDT; 9,083 trials). Pupil-linked DDM models required valid Decision-Response TEPR on the same behavioral subset (*N* = 59; 12,287 trials pooled; ADT *N* = 47, VDT *N* = 54).

### Screening Criteria

**Participant level**

- **Enrollment**: Community-recruited older adults meeting study inclusion criteria
- **Post-enrollment exclusion**: Suspected MCI or possible essential tremor (*n* = 2)

**Behavioral DDM (primary)**

- **Missed/invalid responses**: Excluded before DDM-ready export
- **Non-positive RT**: Excluded before DDM-ready export
- **Cue-locked RT lower bound**: RT < 0.20 s (primary threshold; sensitivity at 0.15 s and 0.25 s in appendix)
- **Task participation**: Participants with fewer than 100 analyzable trials in a task contributed to the other task only (reported in main text)

**Pupil-linked DDM**

- **Behavioral inclusion**: Same RT and choice criteria as primary behavioral DDM
- **Pupil QC**: Valid baseline and cognitive-window quality metrics; valid Decision-Response TEPR (*z*-scored within participant)
- **Nested comparison set**: All pupil-augmented models fit on the same pupil-available trial subset

### Retention Statistics

| Screening step | Participants | Trials | Notes |
|---|---:|---:|---|
| Enrolled | 69 | — | Initial consent |
| Post-enrollment excluded | 2 | — | MCI; essential tremor |
| Analytic cohort | **67** | 18,097 | After behavioral artifact screening |
| Cue-locked RT < 0.20 s excluded | 67 | 240 | Anticipatory/fast responses |
| Primary behavioral DDM | **67** | **17,857** | Probe-onset-locked specification |
| ADT (behavioral) | 64 | 8,774 | Auditory task |
| VDT (behavioral) | 65 | 9,083 | Visual task |
| Pupil QC / missing TEPR excluded | 59 | 5,570 | Relative to behavioral RT-filtered set |
| Pooled pupil-linked DDM | **59** | **12,287** | Nested pupil-augmented models |
| ADT (pupil-linked) | 47 | 5,654 | |
| VDT (pupil-linked) | 54 | 6,633 | |
