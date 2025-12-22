# F) PRE-COMMIT HYGIENE

## .gitignore Status

### Current .gitignore Rules
**Location**: `.gitignore` (root)

**Relevant Rules**:
```
*.mat
*.csv
*.h5
*.hdf5
output/
results/
figures/
logs/
models/
```

**Status**: ✅ **PASS** - Large data files are excluded

### Additional Rules Needed
**Add to .gitignore**:
```
# MATLAB-specific
01_data_preprocessing/matlab/paths_config.m  # User-specific config
BAP_cleaned/
BAP_processed/
data/raw/
data/BAP_cleaned/
data/BAP_processed/
```

## Files to Stage (Commit)

### Code Files
```
01_data_preprocessing/matlab/
  ├─ BAP_Pupillometry_Pipeline.m
  ├─ parse_filename.m
  ├─ parse_logP_filename.m
  ├─ parse_logP_file.m
  ├─ convert_timebase.m
  ├─ validate_logP_plausibility.m
  ├─ write_qc_outputs.m
  ├─ generate_falsification_summary.m
  ├─ generate_trial_level_flags.m
  ├─ write_manifest.m
  ├─ create_build_directory.m
  └─ [other helper functions]
```

### Documentation Files
```
docs/
  └─ [any new documentation]
A_repo_wiring.md
B_contamination_guard.md
C_falsification_checks.md
D_paths.md
E_min_repro.md
F_commit_plan.md
MATLAB_PRECOMMIT_AUDIT_REPORT.md
```

### Configuration Templates
```
config/
  └─ paths_config.m.example  # If created
```

## Files to NOT Stage (Exclude)

### Data Files
```
BAP_cleaned/
BAP_processed/
data/raw/
data/BAP_cleaned/
data/BAP_processed/
*.mat
*.csv (except small QC templates)
```

### User-Specific Config
```
01_data_preprocessing/matlab/paths_config.m  # If user creates this
```

### Build Artifacts
```
build_*/
*.log
*.out
```

### Large Outputs
```
output/
results/
figures/
models/
```

## Suggested Commit Messages

### Commit 1: Core Pipeline Hardening
```
feat(matlab): Harden preprocessing pipeline with contamination guards and falsification checks

- Add session 2-3 only filter (exclude session 1)
- Add location/practice run filters
- Implement residual validation (event-code vs logP)
- Add logP window event validation
- Create excluded files QC output
- Add session_inferred tracking

BREAKING: Pipeline now explicitly excludes session 1 and OutsideScanner runs
```

### Commit 2: Path Configuration and Portability
```
refactor(matlab): Make paths configurable and portable

- Add CONFIG section with clear instructions
- Create paths_config.m.example template
- Add path validation checks
- Support relative paths from script location

BREAKING: Users must configure paths (see paths_config.m.example)
```

### Commit 3: QC Artifacts and Falsification
```
feat(matlab): Add comprehensive QC artifacts and falsification validation

- Create qc_matlab_falsification_residuals_by_run.csv
- Update falsification_validation_summary.md with residual stats
- Add top 10 worst runs listing
- Enhance trial-level flags with timebase bug detection
```

### Commit 4: Documentation and Audit
```
docs: Add MATLAB preprocessing audit documentation

- A_repo_wiring.md: Function call chains and variable names
- B_contamination_guard.md: Filter rules and excluded patterns
- C_falsification_checks.md: Residual and window validation
- D_paths.md: Path configuration guide
- E_min_repro.md: Minimal reproduction steps
- F_commit_plan.md: Pre-commit hygiene
- MATLAB_PRECOMMIT_AUDIT_REPORT.md: Consolidated audit report
```

## Pre-Commit Checklist

- [ ] All hard-coded paths removed or made configurable
- [ ] .gitignore updated to exclude data directories
- [ ] No large files (>1MB) in staged files
- [ ] No user-specific paths in committed code
- [ ] All QC outputs go to build directories (excluded by .gitignore)
- [ ] Config templates created (paths_config.m.example)
- [ ] Documentation complete
- [ ] Test run successful (see E_min_repro.md)

## Verification Commands

### Check for Large Files
```bash
git ls-files | xargs ls -lh | awk '$5 ~ /M/ {print $5, $9}'
```

### Check for Hard-Coded Paths
```bash
grep -r "/Users/" 01_data_preprocessing/matlab/ --include="*.m" | grep -v ".example"
```

### Check for Data Files
```bash
git ls-files | grep -E "\.(mat|csv|h5|hdf5)$" | head -20
```

### Check Staged Files Size
```bash
git diff --cached --stat
```

## Files That Should Never Be Committed

1. **Raw data**: `*.mat` files in data directories
2. **Processed outputs**: `*_flat.csv` files in BAP_processed/
3. **Build artifacts**: `build_*/` directories
4. **User configs**: `paths_config.m` (user-specific)
5. **Logs**: `*.log`, `*.out` files
6. **Large QC exports**: Full `qc_matlab_*.csv` with all subjects

## Files That Can Be Committed (Small Examples)

1. **QC templates**: Empty or single-subject example QC files (< 10KB)
2. **Config examples**: `paths_config.m.example`
3. **Documentation**: All `.md` files
4. **Code**: All `.m` files

## Next Steps

1. **BEFORE COMMIT**: Run verification commands above
2. **BEFORE COMMIT**: Test minimal repro (E_min_repro.md)
3. **BEFORE COMMIT**: Review staged files with `git status`
4. **COMMIT**: Use suggested commit messages
5. **AFTER COMMIT**: Verify no large files in history with `git log --stat`

