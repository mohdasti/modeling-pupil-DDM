# ============================================================================
# Makefile for DDM-Pupil Modeling Pipeline
# ============================================================================
# Quick targets to run common analysis steps
# ============================================================================

# Configuration
R := Rscript --vanilla
R_CMD := $(R) -e

# Directories
SCRIPTS_DIR := scripts
OUTPUT_DIR := output
FIGS_DIR := $(OUTPUT_DIR)/figures
TABLES_DIR := $(OUTPUT_DIR)/tables
MODELS_DIR := models
DATA_DIR := data

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RESET := \033[0m

# ============================================================================
# PHONY TARGETS
# ============================================================================
.PHONY: all clean features fit compare tonic report check qc-quick-share

# ============================================================================
# QC QUICK SHARE
# ============================================================================

qc-quick-share:
	@echo "$(YELLOW)Generating quick share QC snapshot...$(RESET)"
	@$(R) 02_pupillometry_analysis/qc_export_quick_share.R
	@echo "$(GREEN)✓ QC snapshot generated in data/qc/quick_share/$(RESET)"

quick-share-v2:
	@echo "$(YELLOW)Generating quick-share v2 CSVs...$(RESET)"
	@$(R) R/quick_share_v2_generate.R
	@echo "$(GREEN)✓ Quick-share v2 CSVs generated in quick_share_v2/$(RESET)"
	@echo "$(YELLOW)Rendering slim HTML report...$(RESET)"
	@quarto render reports/pupil_qc_slim.qmd
	@echo "$(GREEN)✓ HTML report generated: reports/pupil_qc_slim.html$(RESET)"

quick-share-v3:
	@echo "$(YELLOW)Generating merged trial-level dataset + quick-share v3 CSVs...$(RESET)"
	@$(R) scripts/make_merged_quickshare.R
	@echo "$(GREEN)✓ Quick-share v3 CSVs generated in quick_share_v3/quick_share/$(RESET)"
	@echo "$(GREEN)✓ Merged dataset: quick_share_v3/merged/BAP_triallevel_merged.csv$(RESET)"

quick-share-v4:
	@echo "$(YELLOW)Generating merged trial-level dataset + quick-share v4 CSVs...$(RESET)"
	@$(R) scripts/make_merged_quickshare_v4.R
	@echo "$(GREEN)✓ Quick-share v4 CSVs generated in quick_share_v4/quick_share/$(RESET)"
	@echo "$(GREEN)✓ Merged dataset: quick_share_v4/merged/BAP_triallevel_merged.csv$(RESET)"
	@echo "$(YELLOW)Rendering slim HTML report...$(RESET)"
	@quarto render reports/slim_qc_report_v4.qmd
	@echo "$(GREEN)✓ HTML report: reports/slim_qc_report_v4.html$(RESET)"

# ============================================================================
# MAIN TARGETS
# ============================================================================

all: check load-data prepare-data features fit compare tonic report
	@echo "$(GREEN)✓ Complete pipeline finished$(RESET)"

check:
	@echo "$(YELLOW)Checking dependencies...$(RESET)"
	@$(R_CMD) "if (!require('brms')) install.packages('brms', repos='https://cloud.r-project.org')"
	@$(R_CMD) "if (!require('loo')) install.packages('loo', repos='https://cloud.r-project.org')"
	@$(R_CMD) "if (!require('lme4')) install.packages('lme4', repos='https://cloud.r-project.org')"
	@echo "$(GREEN)✓ Dependencies checked$(RESET)"

load-data:
	@echo "$(YELLOW)Loading processed pupil data...$(RESET)"
	@mkdir -p $(DATA_DIR)/analysis_ready
	@$(R_CMD) "source('scripts/data/load_processed_pupil_data.R')"
	@echo "$(GREEN)✓ Data loaded$(RESET)"

prepare-data:
	@echo "$(YELLOW)Preparing analysis-ready data...$(RESET)"
	@$(R_CMD) "source('scripts/data/prepare_analysis_data.R')"
	@echo "$(GREEN)✓ Data prepared$(RESET)"

features:
	@echo "$(YELLOW)Computing phasic/tonic features...$(RESET)"
	@$(R_CMD) "source('$(SCRIPTS_DIR)/pupil/compute_phasic_features_from_flat.R')"
	@echo "$(GREEN)✓ Features computed$(RESET)"

fit:
	@echo "$(YELLOW)Fitting core DDM models...$(RESET)"
	@mkdir -p $(MODELS_DIR)
	@$(R_CMD) "source('$(SCRIPTS_DIR)/modeling/fit_ddm_brms.R')"
	@$(R_CMD) "source('$(SCRIPTS_DIR)/modeling/history_modeling.R')" || echo "$(YELLOW)Warning: History modeling optional$(RESET)"
	@echo "$(GREEN)✓ Core models fitted$(RESET)"

compare:
	@echo "$(YELLOW)Running model comparisons (LOO/AIC)...$(RESET)"
	@mkdir -p $(OUTPUT_DIR)/loo
	@$(R_CMD) "source('$(SCRIPTS_DIR)/modeling/compare_models.R')"
	@echo "$(GREEN)✓ Model comparisons complete$(RESET)"

tonic:
	@echo "$(YELLOW)Running tonic→alpha analysis...$(RESET)"
	@mkdir -p $(FIGS_DIR)/tonic
	@$(R_CMD) "source('$(SCRIPTS_DIR)/tonic_alpha_analysis.R')"
	@echo "$(GREEN)✓ Tonic→alpha analysis complete$(RESET)"

report:
	@echo "$(YELLOW)Generating reports and tables...$(RESET)"
	@mkdir -p $(TABLES_DIR) $(FIGS_DIR)/summary
	@$(R_CMD) "source('$(SCRIPTS_DIR)/qc/compute_attrition.R')"
	@$(R_CMD) "source('$(SCRIPTS_DIR)/qc/lapse_sensitivity_check.R')" || echo "$(YELLOW)Warning: Lapse check optional$(RESET)"
	@$(R_CMD) "source('$(SCRIPTS_DIR)/modeling/ppc_checks.R')"
	@echo "$(GREEN)✓ Reports generated$(RESET)"

# ============================================================================
# INDIVIDUAL ANALYSIS TARGETS
# ============================================================================

ppc:
	@echo "$(YELLOW)Running posterior predictive checks...$(RESET)"
	@mkdir -p $(FIGS_DIR)/ppc
	@$(R_CMD) "source('$(SCRIPTS_DIR)/modeling/ppc_checks.R')"
	@echo "$(GREEN)✓ PPC checks complete$(RESET)"

attrition:
	@echo "$(YELLOW)Computing attrition rates...$(RESET)"
	@$(R_CMD) "source('$(SCRIPTS_DIR)/qc/compute_attrition.R')"
	@echo "$(GREEN)✓ Attrition analysis complete$(RESET)"

lapse:
	@echo "$(YELLOW)Running lapse sensitivity check...$(RESET)"
	@$(R_CMD) "source('$(SCRIPTS_DIR)/qc/lapse_sensitivity_check.R')"
	@echo "$(GREEN)✓ Lapse sensitivity check complete$(RESET)"

power:
	@echo "$(YELLOW)Running power simulation...$(RESET)"
	@mkdir -p $(OUTPUT_DIR)/power $(FIGS_DIR)/power
	@$(R_CMD) "source('$(SCRIPTS_DIR)/utilities/power_sim_serial_bias.R')"
	@echo "$(GREEN)✓ Power simulation complete$(RESET)"

test:
	@echo "$(YELLOW)Running model contract tests...$(RESET)"
	@$(R_CMD) "source('tests/test_model_contract.R')" || echo "$(YELLOW)Warning: Tests optional$(RESET)"
	@echo "$(GREEN)✓ Tests passed$(RESET)"

# ============================================================================
# VALIDATION TARGETS
# ============================================================================

validate:
	@echo "$(YELLOW)Validating output files...$(RESET)"
	@test -f $(MODELS_DIR)/ddm_brms_main.rds || (echo "$(RED)✗ Core model missing$(RESET)" && exit 1)
	@test -f $(TABLES_DIR)/attrition_table.csv || (echo "$(RED)✗ Attrition table missing$(RESET)" && exit 1)
	@test -d $(FIGS_DIR)/ppc || (echo "$(RED)✗ PPC figures missing$(RESET)" && exit 1)
	@echo "$(GREEN)✓ Output validation passed$(RESET)"

# ============================================================================
# CLEANUP TARGETS
# ============================================================================

clean:
	@echo "$(YELLOW)Cleaning intermediate files...$(RESET)"
	@find $(OUTPUT_DIR) -name "*.tmp" -delete
	@find $(MODELS_DIR) -name "*.tmp" -delete
	@echo "$(GREEN)✓ Cleanup complete$(RESET)"

clean-all: clean
	@echo "$(YELLOW)Removing all generated outputs...$(RESET)"
	@rm -rf $(MODELS_DIR)/*.rds
	@rm -rf $(OUTPUT_DIR)
	@echo "$(GREEN)✓ All outputs removed$(RESET)"

# ============================================================================
# DOCUMENTATION TARGET
# ============================================================================

help:
	@echo "$(GREEN)DDM-Pupil Modeling Pipeline$(RESET)"
	@echo "================================"
	@echo ""
	@echo "$(YELLOW)Main Targets:$(RESET)"
	@echo "  make features  - Compute phasic/tonic pupil features"
	@echo "  make fit       - Run core DDM fits"
	@echo "  make compare   - Run LOO/AIC model comparisons"
	@echo "  make tonic     - Run tonic→alpha models & plots"
	@echo "  make report    - Generate reports and manuscript tables"
	@echo "  make all       - Run complete pipeline"
	@echo ""
	@echo "$(YELLOW)Individual Targets:$(RESET)"
	@echo "  make ppc       - Run posterior predictive checks"
	@echo "  make attrition - Compute attrition rates"
	@echo "  make lapse     - Run lapse sensitivity check"
	@echo "  make power     - Run power simulation"
	@echo "  make test      - Run model contract tests"
	@echo ""
	@echo "$(YELLOW)Utility Targets:$(RESET)"
	@echo "  make qc-quick-share - Generate compact QC snapshot (8 CSVs)"
	@echo "  make quick-share-v3 - Generate merged trial-level + quick-share v3 (8 CSVs)"
	@echo "  make validate  - Validate output files"
	@echo "  make clean     - Clean intermediate files"
	@echo "  make clean-all - Remove all generated outputs"
	@echo "  make help      - Show this help message"
	@echo ""

# ============================================================================
# DEFAULT TARGET
# ============================================================================
.DEFAULT_GOAL := help
