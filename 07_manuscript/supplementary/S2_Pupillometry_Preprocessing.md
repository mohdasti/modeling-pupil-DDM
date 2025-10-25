# Supplementary Material S2: Pupillometry Preprocessing Details

## Preprocessing Pipeline

### 1. Raw Data Collection
- **Sampling Rate**: 1000 Hz
- **Trial Window**: -500 ms to +2000 ms relative to stimulus onset
- **Baseline Window**: -500 ms to 0 ms (pre-stimulus)
- **Analysis Window**: 0 ms to +1500 ms (post-stimulus)

### 2. Artifact Detection and Correction
- **Blink Detection**: Velocity threshold > 1000 pixels/sample
- **Missing Data**: Interpolated using cubic spline interpolation
- **Outlier Removal**: Values > 3 SD from participant mean
- **Trial Exclusion**: >40% missing data within trial window

### 3. Feature Extraction

#### TONIC Features
- **TONIC_BASELINE**: Mean pupil diameter in [-500, 0] ms window
- **Z-scoring**: Within participant and task

#### PHASIC Features
- **PHASIC_SLOPE** (PRIMARY): OLS slope of pupil dilation in [200, 900] ms window (pre-registered primary metric)
- **PHASIC_TER_PEAK** (SENSITIVITY): Peak baseline-corrected dilation in [300, 1200] ms
- **PHASIC_TER_AUC** (SENSITIVITY): Trapezoidal AUC of baseline-corrected pupil in [300, 1200] ms
- **PHASIC_EARLY_PEAK** (SENSITIVITY): Peak in [200, 700] ms window
- **PHASIC_LATE_PEAK** (SENSITIVITY): Peak in [700, 1500] ms window

### 4. State/Trait Decomposition
- **Between-Person (*_bp)**: Participant mean across all trials
- **Within-Person (*_wp)**: Trial value minus participant mean
- **Z-scoring**: Within-person values standardized within participant

### 5. Residualization
- **PHASIC residualization**: PHASIC_wp ~ TONIC_wp + difficulty + effort
- **Orthogonalization**: Early vs Late phasic features made orthogonal

## Quality Assurance

### Missing Data Patterns
- **Mean missing per trial**: 12.3% (SD = 8.7%)
- **Trials with >40% missing**: 215/987 (21.8%)
- **Participants with <10 valid trials**: 0/26 (0%)

### Feature Reliability
- **TONIC_BASELINE**: ICC = 0.73 (excellent)
- **PHASIC_SLOPE** (PRIMARY): ICC = 0.68 (good; model comparison AIC weight ≈ 0.92)
- **PHASIC_TER_PEAK** (sensitivity): ICC = 0.71 (good)

### Preprocessing Validation
- **VIF Analysis**: All VIF < 1.01 (no multicollinearity)
- **Residualization Check**: Coefficients stable after residualization
- **Orthogonalization Check**: Early/Late features uncorrelated (r = 0.02)

## Software and Parameters
- **Pupil Processing**: Custom R scripts
- **Interpolation**: `zoo::na.spline()` with cubic splines
- **Feature Extraction**: `signal::findpeaks()` for peak detection
- **State/Trait**: Custom decomposition functions
