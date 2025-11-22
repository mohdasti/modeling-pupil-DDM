# Cursor Crash - Complete Fix Guide

## 🐛 The Real Problem

When you say "run the pipeline and monitor errors", you're likely:
1. Opening `run_full_pipeline.R` or similar scripts
2. Cursor's R language server starts indexing 34+ R files
3. It tries to parse complex brms/Stan code
4. This overwhelms Cursor's resources → instant crash

**The .cursorignore helped with .rds files, but R FILES still trigger the R language server**

---

## ✅ Complete Solution Applied

### 1. `.cursorignore` (Already Done)
Prevents indexing of:
- `.rds` model files
- `output/` directory
- Large data files

### 2. `.vscode/settings.json` (Just Created)
Disables R language server completely to prevent crashes.

---

## 🚨 CRITICAL NEXT STEPS

### Step 1: Disable R Extension in Cursor

**Manual Method (Best):**

1. Open Cursor
2. Go to Extensions (Cmd+Shift+X)
3. Search for "R" 
4. Find "R Editor Support" or similar
5. Click **Disable** or **Uninstall**
6. Restart Cursor (Cmd+Q, wait 10s, reopen)

### Step 2: Verify R Processes Stopped

After restarting Cursor:

```bash
ps aux | grep "languageServer\|helpServer" | grep -v grep
```

Should show: **Nothing** (no R processes running)

### Step 3: Test Opening R Files

After disabling:
1. Open `scripts/02_statistical_analysis/02_ddm_analysis.R`
2. Cursor should NOT crash
3. You'll lose autocomplete for R, but no crashes

---

## 🚀 How to Run Analysis Now

**WITHOUT R extension (NO autocomplete, NO crashes):**

### Option 1: Use Terminal Outside Cursor

```bash
# Open Terminal.app (NOT Cursor's terminal!)
# Navigate to project
cd /path/to/project

# Run the safe script
./run_ddm_no_cursor.sh

# Monitor in same terminal or new one
./MONITOR_ANALYSIS.sh
```

### Option 2: Use Cursor's Terminal (After Disabling R Extension)

Once R extension is disabled:
1. Open Cursor
2. Open integrated terminal (`` ` `` or Ctrl+`)
3. Run: `./run_ddm_no_cursor.sh`
4. No crashes!

---

## ⚠️ What You'll Lose

After disabling R extension:
- ❌ R code autocomplete
- ❌ R syntax highlighting (basic one might remain)
- ❌ R package documentation hover
- ❌ R debugger features

**But you gain:**
- ✅ Cursor stability
- ✅ Can edit R files without crashes
- ✅ Can run analysis via terminal
- ✅ Can use Cursor for other tasks

---

## 📋 Alternative: Use RStudio Instead

If you need R autocomplete:

1. Keep R extension **disabled in Cursor**
2. Use **RStudio** for writing/editing R code
3. Use **Terminal** for running long analyses
4. Use **Cursor** for Git, documentation, Python, etc.

This is a common workflow in data science:
- **RStudio**: R development
- **Terminal**: Long-running analyses
- **Cursor/VSCode**: Other languages, Git, docs

---

## 🔍 Why This Happens

**Technical Explanation:**

Cursor (like VSCode) uses language servers for code intelligence:
- Python → Python language server
- R → R language server (reditorsupport.r extension)
- TypeScript → TypeScript language server

The R language server is **heavyweight** because:
1. It needs to load R binary
2. Parse complex R syntax
3. Index R packages
4. Handle brms/Stan DSL

When you have:
- Large R files (400+ lines)
- Complex brms formulas
- Many R files (34+)
- Large datasets nearby

The language server tries to **index everything** → memory exhaustion → crash

---

## ✅ Summary

**Problem:** R language server in Cursor overloads and crashes

**Solution:** Disable R extension in Cursor

**Workflow:**
1. Cursor: Git, docs, Python (stable)
2. RStudio: R editing (full features)  
3. Terminal: Long analyses (no crash risk)

---

## 🆘 Still Having Issues?

### Try Minimal R File Test

Create a simple test file:

```bash
echo 'print("Hello")' > test.R
```

Open it in Cursor. If it crashes:
- R extension might still be enabled
- Restart Cursor completely (Cmd+Q, wait 30s, reopen)
- Check Extensions panel for R extension

### Nuclear Option: Disable ALL Extensions Temporarily

1. Cmd+Shift+P
2. Type: "Extensions: Disable All Installed Extensions"
3. Restart Cursor
4. Open R files - should NOT crash
5. Enable extensions one by one to find culprit

### Check System Resources

```bash
# See what's using memory
top -o mem

# Check available RAM
vm_stat

# If system is low on RAM, close other apps
```

---

**Bottom Line:** Cursor + R language server = crashes with your large/complex codebase. Disable R extension, use RStudio for R coding, Terminal for running.








