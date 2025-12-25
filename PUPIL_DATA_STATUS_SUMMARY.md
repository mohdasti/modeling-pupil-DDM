# Pupil Data Status Report

**Generated:** $(date)  
**Data Location:** `/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed`

## Executive Summary

- **Total Participants:** 34 unique participants
- **Total Tasks:** 2 (ADT, VDT)
- **Total Participant-Task-Run Combinations:** 224
- **Total Data Rows:** 46,116,485
- **Total Flat Files:** 59

## Task-Level Overview

| Task | # Participants | Total Runs | Total Rows |
|------|----------------|------------|------------|
| **ADT** | 28 | 107 | 20,711,806 |
| **VDT** | 31 | 117 | 25,404,679 |

## Participants with Both Tasks (Complete Data)

The following participants have data for **both ADT and VDT** tasks:

1. BAP003 (6 runs: 4 ADT, 2 VDT)
2. BAP102 (6 runs: 3 ADT, 3 VDT)
3. BAP104 (9 runs: 5 ADT, 4 VDT)
4. BAP106 (9 runs: 4 ADT, 5 VDT)
5. BAP144 (7 runs: 4 ADT, 3 VDT)
6. BAP145 (7 runs: 2 ADT, 5 VDT)
7. BAP146 (6 runs: 2 ADT, 4 VDT)
8. BAP147 (5 runs: 4 ADT, 1 VDT)
9. BAP149 (5 runs: 4 ADT, 1 VDT)
10. BAP151 (10 runs: 5 ADT, 5 VDT)
11. BAP156 (7 runs: 5 ADT, 2 VDT)
12. BAP157 (6 runs: 3 ADT, 3 VDT)
13. BAP159 (9 runs: 4 ADT, 5 VDT)
14. BAP166 (8 runs: 4 ADT, 4 VDT)
15. BAP169 (9 runs: 5 ADT, 4 VDT)
16. BAP170 (8 runs: 5 ADT, 3 VDT)
17. BAP171 (5 runs: 3 ADT, 2 VDT)
18. BAP177 (6 runs: 3 ADT, 3 VDT)
19. BAP178 (10 runs: 5 ADT, 5 VDT) ⭐ **Complete**
20. BAP180 (10 runs: 5 ADT, 5 VDT) ⭐ **Complete**
21. BAP183 (10 runs: 5 ADT, 5 VDT) ⭐ **Complete**
22. BAP193 (8 runs: 5 ADT, 3 VDT)
23. BAP199 (8 runs: 3 ADT, 5 VDT)
24. BAP201 (9 runs: 4 ADT, 5 VDT)
25. BAP202 (8 runs: 3 ADT, 5 VDT)

## Participants with ADT Only

1. **BAP101** (2 runs)
2. **BAP140** (1 run)
3. **BAP172** (5 runs)

## Participants with VDT Only

1. **BAP184** (3 runs)
2. **BAP186** (5 runs)
3. **BAP191** (3 runs)
4. **BAP194** (5 runs)
5. **BAP195** (5 runs)
6. **BAP196** (4 runs)

## Detailed Status by Participant and Task

See `pupil_data_status_report.csv` for detailed breakdown including:
- Number of runs per participant-task combination
- Run ranges (min-max run numbers)
- Total rows and trials per combination
- Source filenames

## Run-Level Detail

See `pupil_data_run_detail.csv` for complete run-by-run breakdown including:
- Individual run numbers
- Source filename for each run
- Row counts and trial counts per run

## Notes

- Files with `_flat_merged.csv` suffix contain multiple runs combined in a single file
- Files with `_flat.csv` suffix contain individual run data
- Run numbers may not be consecutive (e.g., runs 1, 3, 5) due to data availability
- Some participants have incomplete run sequences

## Next Steps

To identify missing data:
1. Compare this list against your master participant list
2. Check which participants are missing entirely
3. For participants with partial data, identify missing tasks or runs
4. Cross-reference with Google Drive to determine what needs to be downloaded









