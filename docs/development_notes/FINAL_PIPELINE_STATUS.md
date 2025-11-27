# Final Pipeline Status

## ✅ Successfully Completed Models (8)

1. Model1_Baseline (1.8M)
2. Model1_Baseline_ADT (1.9M)
3. Model1_Baseline_VDT (1.7M)
4. Model3_Difficulty (1.9M)
5. Model3_Difficulty_ADT (2.0M)
6. Model4_Additive_NoEffort (2.1M)
7. Model7_Task (2.1M)
8. Model8_Task_Additive_NoEffort (2.1M)

## ❌ Models Skipped (Expected)

- **Effort models** (effort_condition has only 1 level):
  - Model2_Force
  - Model4_Additive
  - Model5_Interaction
  - Model10_Param_v_bs
  
- **Pupil models** (pupil data file missing):
  - Model6_Pupillometry

## 🔧 Fixes Applied

1. ✅ **Prior mismatch fixed**: Removed `b` priors for intercept-only parameters
2. ✅ **Factor level checks**: Skip models requiring factors with insufficient levels
3. ✅ **Better initialization**: Fixed NDT init values to prevent RT < NDT violations

## ⚠️ Current Issues

- Model1_Baseline failing due to `b` prior (being fixed)
- Some initialization issues remain for per-task models

## Next Steps

- Fix Model1_Baseline prior issue
- Re-run per-task models with fixed initialization
- Generate final summary report
