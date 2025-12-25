# Task Log Timestamp Definitions

Based on the MATLAB task code (`cogdisc_task_v11c_1_eyetrack_AS.m`), here are the definitions of each timestamp:

## Timestamp Definitions

**TrialST**: Screen flip onset for the grip gauge display (handgrip force feedback screen).

**blankST**: Screen flip onset for the blank screen that appears after the grip gauge period.

**fixST**: Screen flip onset for the fixation dot display (pre-stimulus fixation period).

**A/V_ST**: Screen flip onset that coincides with stimulus pair onset (audio playback start for ADT, or Gabor 1 display onset for VDT).

**relaxST**: Screen flip onset for the relax screen (blue frame indicating grip relaxation period).

**Resp1ST**: Screen flip onset for the Response 1 screen ("Different?" question with Yes/No buttons).

**Resp1ET**: Screen flip offset that ends the Response 1 window (canonical end time after Resp1_Duration, not the actual keypress time).

**Resp2ST / Resp2ET**: Screen flip onset (Resp2ST) and offset (Resp2ET) for the Response 2 screen (confidence rating with 1-4 buttons).

## Notes

- All timestamps are screen flip times from `Screen('Flip', ...)` except where noted.
- Response end times (Resp1ET, Resp2ET) are canonical window end times, not actual keypress times.
- Actual keypress times are recorded separately in `ButtonRT` and `ButtonRT2` (reaction times relative to Resp1ST/Resp2ST).
- All times are relative to `ExpStartTimeP` (experiment start time) in the log file.



