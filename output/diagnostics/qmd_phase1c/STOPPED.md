# Stopped at T13

The by-subject effort slope is singular for both the accuracy GLMM and the median-RT LMM. The chapter tables, inline keys, and docx files were not replaced. There is no fallback to a random-intercept-only model.

## Accuracy, 17,857 trials

Optimizer: bobyqa, maxfun = 2e5. Both versions converged (`conv$opt = 0`) onto the boundary. No lme4 warning text was stored; `isSingular()` is TRUE.

Correlated slope, `(1 + effort_condition | subject_id)`:

| Parameter | Estimate |
|---|---:|
| SD, intercept | 0.717 |
| SD, effort slope | 0.000 |
| Cholesky correlation | −0.031 |
| Function evaluations | 328 |

Uncorrelated slope, `(1 | subject_id) + (0 + effort_c | subject_id)` with `effort_c` = −0.5/0.5:

| Parameter | Estimate |
|---|---:|
| SD, intercept | 0.701 |
| SD, effort_c | 0.000 |
| Function evaluations | 254 |

A restart from an effort SD of 0.4, and `nloptwrap`, both returned an effort SD of 0.

## Median RT, 774 subject × task × difficulty × effort cells

Correlated slope: effort SD 0.011, correlation with the intercept 1.000. `isSingular()` is TRUE (`boundary (singular) fit`).

Uncorrelated slope: effort SD 0.000. `isSingular()` is TRUE.

## Not done

T13d was not written. `acc_high_low_Standard`, `acc_high_low_Hard`, and `acc_high_low_Easy` still hold the paired-t values. The docx files were not re-rendered.
