# BAP DDM Pipeline - Comprehensive Logging System

## 🎯 **OVERVIEW**

I've created a **comprehensive logging system** that captures every detail of your pipeline execution. This system provides:

- ✅ **Detailed process tracking** with timestamps and durations
- ✅ **Model information logging** including formulas, convergence, and file sizes
- ✅ **System resource monitoring** (memory, CPU, loaded packages)
- ✅ **Error and warning tracking** with full context
- ✅ **Performance metrics** and trend analysis
- ✅ **Automatic log management** (rotation, cleanup)
- ✅ **JSON and markdown reports** for easy analysis

---

## 📁 **NEW FILES CREATED**

### **Core Logging System**
- **`scripts/logging_system.R`** - Complete logging infrastructure
- **`scripts/run_bap_analysis_with_logging.R`** - Enhanced pipeline with detailed logging
- **`scripts/analyze_pipeline_logs.R`** - Log analysis and visualization tool

### **Documentation**
- **`LOGGING_SYSTEM_DOCUMENTATION.md`** - This comprehensive guide

---

## 🚀 **HOW TO USE THE LOGGING SYSTEM**

### **1. Run Pipeline with Detailed Logging**
```bash
# Run full pipeline with comprehensive logging
Rscript scripts/run_bap_analysis_with_logging.R

# Skip heavy models but still log everything
Rscript scripts/run_bap_analysis_with_logging.R --skip-heavy

# Force rerun everything with full logging
Rscript scripts/run_bap_analysis_with_logging.R --force-rerun
```

### **2. Analyze Logs After Execution**
```bash
# Generate performance analysis and visualizations
Rscript scripts/analyze_pipeline_logs.R
```

---

## 📊 **WHAT GETS LOGGED**

### **Process-Level Logging**
For each script execution, the system logs:
- **Process ID** and unique session identifier
- **Start/end timestamps** with precise duration calculation
- **Script path** and expected outputs
- **Execution status** (SUCCESS, FAILED, SKIPPED, WARNING)
- **System resources** before and after execution
- **Detailed error messages** with full context

### **Model Information Logging**
For each model file, the system captures:
- **Model formula** and family type
- **Convergence diagnostics** (Rhat, ESS, divergent transitions)
- **File size** and modification time
- **Data information** used for fitting
- **Chain and iteration details**

### **Data Processing Logging**
For data operations, the system logs:
- **Input/output file paths** and sizes
- **Processing operation** type and parameters
- **Data summary statistics** (rows, columns, missing values)
- **Feature extraction details** and transformations

### **System Monitoring**
The system tracks:
- **Memory usage** (before/after each process)
- **CPU core count** and utilization
- **R version** and platform information
- **Loaded packages** and their versions
- **Working directory** and file system status

---

## 📈 **LOG OUTPUTS**

### **1. Detailed Log Files**
- **Location**: `output/logs/`
- **Format**: `bap_pipeline_detailed_YYYYMMDD_HHMMSS.log`
- **Content**: Real-time execution logs with timestamps and details

### **2. JSON Summary Files**
- **Location**: `output/logs/`
- **Format**: `bap_pipeline_detailed_YYYYMMDD_HHMMSS_summary.json`
- **Content**: Structured data for programmatic analysis

### **3. Performance Visualizations**
- **Location**: `output/figures/`
- **Files**:
  - `pipeline_performance_by_process.png` - Duration by process type
  - `pipeline_success_rate.png` - Success rate trends
  - `pipeline_duration_trends.png` - Performance over time

### **4. Analysis Report**
- **Location**: `output/results/`
- **File**: `pipeline_log_analysis_report.md`
- **Content**: Comprehensive analysis with recommendations

---

## 🔍 **EXAMPLE LOG ENTRIES**

### **Process Start Log**
```
[2025-09-15 16:30:15] [INFO] Starting process: HDDM Pupillometry Model
Details: {
  "process_id": "PROC_3",
  "details": {
    "script_name": "fit_hierarchical_ddm_pupillometry.R",
    "script_path": "scripts/fit_hierarchical_ddm_pupillometry.R",
    "expected_outputs": ["HDDM_Pupillometry_Final.rds", "HDDM_Pupillometry_Fixed_Effects.csv"],
    "timeout_minutes": 45
  }
}
```

### **Model Information Log**
```
[2025-09-15 16:35:22] [INFO] Model information: HDDM_Pupillometry_Final
Details: {
  "name": "HDDM_Pupillometry_Final",
  "formula": "rt_clean | dec(choice_binary) ~ 1 + difficulty_level + effort_condition + TONIC_BASELINE_scaled + PHASIC_TER_PEAK_scaled + (1 | participant)",
  "family": "wiener",
  "convergence_info": {
    "rhat_max": 1.001,
    "ess_min": 0.85,
    "divergent_transitions": 0
  },
  "file_size_mb": 4.23
}
```

### **Process Completion Log**
```
[2025-09-15 16:38:45] [INFO] Completed process: HDDM Pupillometry Model (SUCCESS)
Details: {
  "process_id": "PROC_3",
  "duration_seconds": 210.5,
  "status": "SUCCESS",
  "results": {
    "output_status": {
      "HDDM_Pupillometry_Final.rds": {
        "exists": true,
        "type": "brms",
        "file_size_mb": 4.23,
        "convergence_info": {...}
      }
    }
  }
}
```

---

## 📊 **LOG ANALYSIS FEATURES**

### **Performance Metrics**
- **Duration tracking** for each process type
- **Success rate analysis** across sessions
- **Trend identification** for performance degradation
- **Resource usage patterns** over time

### **Quality Assurance**
- **Convergence monitoring** for all models
- **Error pattern detection** across runs
- **Output validation** for expected files
- **Dependency checking** between processes

### **Optimization Insights**
- **Bottleneck identification** (longest-running processes)
- **Failure analysis** (most common errors)
- **Resource recommendations** (memory, CPU usage)
- **Efficiency suggestions** (parallelization opportunities)

---

## 🛠️ **CONFIGURATION OPTIONS**

### **Log Levels**
- **DEBUG**: All information (most verbose)
- **INFO**: Standard operational messages
- **WARNING**: Non-critical issues
- **ERROR**: Process failures
- **CRITICAL**: System-level problems

### **Log Management**
- **Maximum log file size**: 50 MB (configurable)
- **Maximum log files**: 10 (configurable)
- **Automatic cleanup**: Old logs removed automatically
- **Timestamp format**: YYYY-MM-DD HH:MM:SS

### **Performance Monitoring**
- **Memory tracking**: Before/after each process
- **CPU monitoring**: Core count and utilization
- **File system**: Disk usage and access patterns
- **Timeout controls**: Prevents infinite hangs

---

## 📋 **TYPICAL WORKFLOW**

### **1. Run Pipeline with Logging**
```bash
Rscript scripts/run_bap_analysis_with_logging.R
```

### **2. Monitor Real-Time Progress**
The system provides real-time console output:
```
[2025-09-15 16:30:15] [INFO] Starting BAP DDM Analysis Pipeline
[2025-09-15 16:30:15] [INFO] Checking required data files
[2025-09-15 16:30:16] [INFO] Found data file: BAP_analysis_ready_BEHAVIORAL_full.csv
[2025-09-15 16:30:16] [INFO] Starting process: Pupillometry Feature Extraction
[2025-09-15 16:32:45] [INFO] Completed process: Pupillometry Feature Extraction (SUCCESS)
```

### **3. Analyze Results**
```bash
Rscript scripts/analyze_pipeline_logs.R
```

### **4. Review Generated Reports**
- **Performance plots**: Visual analysis of execution patterns
- **Markdown report**: Detailed analysis with recommendations
- **JSON summaries**: Machine-readable performance data

---

## 🎯 **BENEFITS FOR DEBUGGING**

### **1. Complete Audit Trail**
- **Every process** is logged with full context
- **All errors** are captured with stack traces
- **System state** is recorded at each step
- **File operations** are tracked with timestamps

### **2. Performance Analysis**
- **Identify bottlenecks** in your pipeline
- **Track performance degradation** over time
- **Monitor resource usage** patterns
- **Optimize execution** based on data

### **3. Quality Assurance**
- **Verify model convergence** for all analyses
- **Check output completeness** automatically
- **Monitor error rates** across sessions
- **Ensure reproducibility** with full logs

### **4. Troubleshooting Support**
- **Pinpoint exact failure locations** with timestamps
- **Compare successful vs failed runs** systematically
- **Identify common error patterns** across sessions
- **Provide context** for debugging efforts

---

## 🔧 **CUSTOMIZATION OPTIONS**

### **Modify Log Levels**
```r
# In scripts/logging_system.R
LOG_CONFIG <- list(
    log_levels = c("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"),
    # Change default level here
    default_level = "INFO"  # or "DEBUG" for maximum detail
)
```

### **Adjust Timeout Settings**
```r
# In scripts/run_bap_analysis_with_logging.R
pipeline_scripts = list(
    list(
        name = "your_script.R",
        timeout_minutes = 60  # Adjust as needed
    )
)
```

### **Custom Log Directory**
```r
# Change log storage location
LOG_CONFIG <- list(
    log_dir = "custom/log/path"
)
```

---

## 📈 **MONITORING DASHBOARD**

The logging system generates several visualization files that serve as a monitoring dashboard:

### **Performance Dashboard**
- **`pipeline_performance_by_process.png`**: Box plots showing duration distributions by process type
- **`pipeline_success_rate.png`**: Success rate trends over time
- **`pipeline_duration_trends.png`**: Performance trends for each process

### **Quality Dashboard**
- **Convergence monitoring**: Rhat and ESS tracking for all models
- **Error rate tracking**: Failure patterns across sessions
- **Resource usage**: Memory and CPU utilization patterns

---

## 🎉 **SUMMARY**

### **What You Get:**
1. ✅ **Complete process tracking** with timestamps and durations
2. ✅ **Model information logging** including formulas and convergence
3. ✅ **System resource monitoring** for optimization
4. ✅ **Error and warning tracking** for debugging
5. ✅ **Performance analysis** with visualizations
6. ✅ **Automatic log management** and cleanup
7. ✅ **JSON and markdown reports** for analysis

### **How to Use:**
1. **Run**: `Rscript scripts/run_bap_analysis_with_logging.R`
2. **Analyze**: `Rscript scripts/analyze_pipeline_logs.R`
3. **Review**: Check generated plots and reports in `output/`

### **Benefits:**
- 🔍 **Complete debugging information** for every process
- 📊 **Performance optimization** insights
- 🛡️ **Quality assurance** with convergence monitoring
- 📈 **Trend analysis** for long-term monitoring
- 🎯 **Reproducibility** with full audit trails

**Your BAP DDM pipeline now has enterprise-level logging and monitoring capabilities!** 🚀
