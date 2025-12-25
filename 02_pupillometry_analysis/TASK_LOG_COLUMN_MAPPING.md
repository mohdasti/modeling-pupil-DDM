# Task Log Column Mapping: MATLAB fprintf to Column Names

## Complete fprintf Statements from Trial Loop

### Auditory Task (taskType == 1)

**Format String:**
```
'%d\t %d\t %d\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %d\t %d\t %d\t %8.3f\t %8.3f\t %d\t %d\t %8.3f\t %d\t %8.3f\t %8.3f\t %8.3f\t %8.3f\n'
```

**Argument List:**
```
trial,
isoddball(trial),
isStrengthHi(trial),
stimulusStartTimeP(trial)-ExpStartTimeP,
blankStartTimeP(trial)-ExpStartTimeP,
fixStartTimeP(trial)-ExpStartTimeP,
SoundStartTimeP(trial)-ExpStartTimeP,
audiocompleteTimeP(trial)-ExpStartTimeP,
relaxStartTimeP(trial)-ExpStartTimeP,
Resp1StartTimeP(trial)-ExpStartTimeP,
Resp2StartTimeP(trial)-ExpStartTimeP,
EndofTrial_timeP(trial)-ExpStartTimeP,
Bpressed,
ButtonResponse(trial),
iscorr(trial),
trial_offset(trial),
ButtonRT(trial),
Bpressed2,
ConfidenceRate(trial),
ButtonRT2(trial),
TrialinTRsP(trial),
stimulusStartTimeP(trial)-ExpStartTimeP,
fixOffsetP(trial)-ExpStartTimeP,
Resp1EndTimeP(trial)-ExpStartTimeP,
Resp2EndTimeP(trial)-ExpStartTimeP
```

### Visual Task (taskType == 2)

**Format String:**
```
'%d\t %d\t %d\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %d\t %d\t %d\t %8.3f\t %8.3f\t %d\t %d\t %8.3f\t %d\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\t %8.3f\n'
```

**Argument List:**
```
trial,
isoddball(trial),
isStrengthHi(trial),
stimulusStartTimeP(trial)-ExpStartTimeP,
blankStartTimeP(trial)-ExpStartTimeP,
fixStartTimeP(trial)-ExpStartTimeP,
SoundStartTimeP(trial)-ExpStartTimeP,
audiocompleteTimeP(trial)-ExpStartTimeP,
relaxStartTimeP(trial)-ExpStartTimeP,
Resp1StartTimeP(trial)-ExpStartTimeP,
Resp2StartTimeP(trial)-ExpStartTimeP,
EndofTrial_timeP(trial)-ExpStartTimeP,
Bpressed,
ButtonResponse(trial),
iscorr(trial),
trial_offset(trial),
ButtonRT(trial),
Bpressed2,
ConfidenceRate(trial),
ButtonRT2(trial),
TrialinTRsP(trial),
stimulusStartTimeP(trial)-ExpStartTimeP,
fixOffsetP(trial)-ExpStartTimeP,
Resp1EndTimeP(trial)-ExpStartTimeP,
Resp2EndTimeP(trial)-ExpStartTimeP,
g1_OffsetTimeP(trial)-ExpStartTimeP,
g2_OnsetTimeP(trial)-ExpStartTimeP,
g2_OffsetTimeP(trial)-ExpStartTimeP
```

## Column Name → MATLAB Expression Mapping

| LOG COLUMN NAME | MATLAB EXPRESSION | Notes |
|----------------|-------------------|-------|
| Trial# | `trial` | Trial number (1-indexed) |
| Oddball? | `isoddball(trial)` | 1 = oddball, 0 = standard |
| Hi Grip? | `isStrengthHi(trial)` | 1 = high grip (40% MVC), 0 = low grip (5% MVC) |
| TrialST | `stimulusStartTimeP(trial)-ExpStartTimeP` | Grip gauge onset (relative to experiment start) |
| blankST | `blankStartTimeP(trial)-ExpStartTimeP` | Blank screen onset (relative to experiment start) |
| fixST | `fixStartTimeP(trial)-ExpStartTimeP` | Fixation onset (relative to experiment start) |
| A/V_ST | `SoundStartTimeP(trial)-ExpStartTimeP` | Stimulus pair onset (audio or visual G1) (relative to experiment start) |
| A/V_CT | `audiocompleteTimeP(trial)-ExpStartTimeP` | Stimulus pair completion/offset (relative to experiment start) |
| relaxST | `relaxStartTimeP(trial)-ExpStartTimeP` | Relax screen onset (relative to experiment start) |
| Resp1ST | `Resp1StartTimeP(trial)-ExpStartTimeP` | Response 1 ("Different?") onset (relative to experiment start) |
| Resp2ST | `Resp2StartTimeP(trial)-ExpStartTimeP` | Response 2 (Confidence rating) onset (relative to experiment start) |
| EoT | `EndofTrial_timeP(trial)-ExpStartTimeP` | End of trial (relative to experiment start) |
| BPressed? | `Bpressed` | Whether button was pressed (1 = yes, 0 = no) |
| BResp(r1g3) | `ButtonResponse(trial)` | Button response: 1 = Red (oddball), 3 = Green (standard) |
| isCorrect? | `iscorr(trial)` | Response correctness (1 = correct, 0 = incorrect, NaN = missed) |
| Freq_Offset | `trial_offset(trial)` | Frequency offset (auditory) or contrast offset (visual) |
| Trial_RT | `ButtonRT(trial)` | Reaction time for Response 1 (seconds) |
| BPressed2(CR)? | `Bpressed2` | Whether button was pressed for confidence rating (1 = yes, 0 = no) |
| CR | `ConfidenceRate(trial)` | Confidence rating (1-4) |
| CR_RT | `ButtonRT2(trial)` | Reaction time for Response 2 / confidence rating (seconds) |
| TrialinTRsD/P | `TrialinTRsP(trial)` | Trial duration in TRs (PTB time) |
| TrialSTD/P | `stimulusStartTimeP(trial)-ExpStartTimeP` | Duplicate of TrialST (PTB time) |
| fixOFSTP | `fixOffsetP(trial)-ExpStartTimeP` | Fixation offset (relative to experiment start) |
| Resp1ET | `Resp1EndTimeP(trial)-ExpStartTimeP` | Response 1 end time (relative to experiment start) |
| Resp2ET | `Resp2EndTimeP(trial)-ExpStartTimeP` | Response 2 end time (relative to experiment start) |
| G1_OFST | `g1_OffsetTimeP(trial)-ExpStartTimeP` | Gabor 1 offset (visual only) (relative to experiment start) |
| G2_ONST | `g2_OnsetTimeP(trial)-ExpStartTimeP` | Gabor 2 onset (visual only) (relative to experiment start) |
| G2_OFST | `g2_OffsetTimeP(trial)-ExpStartTimeP` | Gabor 2 offset (visual only) (relative to experiment start) |

## Notes

1. **Time Reference**: All time columns are relative to `ExpStartTimeP` (experiment start time in PTB/GetSecs time).

2. **Visual-Specific Columns**: The last 3 columns (G1_OFST, G2_ONST, G2_OFST) are only present in visual task logs.

3. **Duplicate Column**: `TrialSTD/P` is a duplicate of `TrialST` (both contain `stimulusStartTimeP(trial)-ExpStartTimeP`).

4. **Variable Naming**: 
   - Variables ending in `P` use PTB/GetSecs time
   - Variables ending in `D` use Datapixx time (when available)
   - The log file uses PTB time (`ExpStartTimeP`)

5. **Response Coding**:
   - `ButtonResponse`: 1 = Red (oddball response), 3 = Green (standard response)
   - `ConfidenceRate`: 1-4 scale (1 = low confidence, 4 = high confidence)

6. **Missing Data**: 
   - `iscorr(trial)` = NaN if no response was given
   - `ConfidenceRate(trial)` = NaN if no confidence rating was given



