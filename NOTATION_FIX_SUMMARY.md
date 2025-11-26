# Notation Fix Summary: Main Effects vs Interactions

## Issue

The report was incorrectly mixing notation for main effects and interactions:
- Main effects should use ":" between factor name and level (e.g., "Difficulty: Hard")
- Interactions should use "×" between different factors (e.g., "Difficulty: Hard × Task: VDT")

The problem was a catch-all rule that converted ANY colon to ×, which incorrectly converted main effects like "Difficulty: Hard" to "Difficulty × Hard".

## Files Fixed

### 1. `reports/chap3_ddm_results.qmd`

**Functions Fixed:**

1. **`clean_term_name`** (lines ~338, ~427) - Used in manipulation check tables
   - Fixed: Handle interactions FIRST, then main effects
   - Interactions use × between factors
   - Main effects preserve : between factor name and level

2. **`clean_ddm_parameter`** (lines ~854, ~991, ~1396) - Used in fixed effects and contrasts tables
   - Fixed: Check if term is interaction BEFORE cleaning
   - If interaction: Split by colon, clean each part, join with ×
   - If main effect: Clean normally, preserve colons

**Correct Notation:**
- Main effects: `Difficulty: Hard`, `Effort: High (40% MVC)`, `Task: VDT`
- Interactions: `Difficulty: Hard × Task: VDT`, `Difficulty: Easy × Effort: Low`

## Testing

All functions tested with:
- Main effects: ✓ Preserve colons (correct)
- Interactions: ✓ Use × between factors (correct)

## Result

✅ **All notation is now correct:**
- Main effects use ":" (factor name: level)
- Interactions use "×" (Factor: Level × Factor: Level)


