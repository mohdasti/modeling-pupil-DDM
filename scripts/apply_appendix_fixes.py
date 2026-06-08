#!/usr/bin/env python3
"""Apply appendix restructuring fixes to chap3_ddm_results.qmd in one pass."""

from pathlib import Path
import re

QMD = Path(__file__).resolve().parents[1] / "reports" / "chap3_ddm_results.qmd"
text = QMD.read_text(encoding="utf-8")

# --- Simple renames ---
text = text.replace(
    "## A1. Model Diagnostics and Priors {.unnumbered}",
    "## A1. Model Selection and Convergence Diagnostics {.unnumbered}",
)
text = text.replace(
    "## A2. Individual Differences and Parameter Relationships {.unnumbered}",
    "## A2. Standard-Only Calibration and Supplementary Parameter Tables {.unnumbered}",
)

# --- Main methods: lme4 citation ---
text = text.replace(
    "using generalized linear mixed-effects models (GLMM, binomial family) for accuracy and linear mixed-effects models (LMM) for median RT, each with fixed effects for Difficulty, Effort, and Task and random intercepts for participant; these results are reported in Appendix A7.",
    "using generalized linear mixed-effects models (GLMM, binomial family) for accuracy and linear mixed-effects models (LMM) for median RT via `lme4` [@bates2015lme4], each with fixed effects for Difficulty, Effort, and Task and random intercepts for participant; fixed-effects summaries used `broom.mixed` [@broommixed]. Full results are reported in Appendix A7.",
)

# --- A3 restructure ---
a3_match = re.search(
    r"(## A3\. Posterior Predictive Checks and Diagnostics.*?)(\n## A4\. Sensitivity Analyses)",
    text,
    re.DOTALL,
)
if not a3_match:
    raise SystemExit("Could not find A3 section")

a3_body = a3_match.group(1)
a4_start = a3_match.group(2)

gate_m = re.search(
    r"(\n```\{r\}\n#\| label: tbl-convergence-ppc-gate-appendix.*?```\n)",
    a3_body,
    re.DOTALL,
)
caf_m = re.search(
    r"(\n\*\*Conditional Accuracy Function \(CAF\)\.\*\*.*?```\n)",
    a3_body,
    re.DOTALL,
)
heat_m = re.search(
    r"(\n\*\*PPC Residual Heatmaps\.\*\*.*?```\n\n)",
    a3_body,
    re.DOTALL,
)
if not all([gate_m, caf_m, heat_m]):
    raise SystemExit("Could not extract A3 sub-blocks")

gate_block = gate_m.group(1)
caf_block = caf_m.group(1)
heat_block = heat_m.group(1)

a3_intro = (
    "## A3. Posterior Predictive Checks and Diagnostics {#app-ch3-ppc .unnumbered}\n\n"
    "@tbl-convergence-ppc-gate-appendix summarizes convergence and PPC diagnostic metrics for the primary model; "
    "convergence criteria were strictly satisfied (PASS) while PPC threshold exceedances were driven by fast-tail misfit as discussed below.\n\n"
    "{{< include ch03_appA_ppc_diagnostics.qmd >}}\n\n"
    + gate_block.strip()
    + "\n\n"
    "{{< include ch03_appA_ppc_interpretation.qmd >}}\n\n"
    "### A3.3 Supplementary Diagnostic Figures {.unnumbered}\n"
    + caf_block
    + heat_block
)

text = text[: a3_match.start()] + a3_intro + a4_start + text[a3_match.end() :]

# --- A4 intro + remove #### Drift Rate by Task ---
text = text.replace(
    "## A4. Sensitivity Analyses {.unnumbered}\n\n### A4.1",
    "## A4. Sensitivity Analyses {.unnumbered}\n\n"
    "This appendix reports pre-specified and exploratory sensitivity analyses examining whether primary DDM conclusions "
    "are robust to participant exclusion, RT timing and cutoff definitions, and task-modality parameterization.\n\n"
    "### A4.1",
)
text = text.replace("#### Drift Rate by Task {.unnumbered}\n\n", "")

# --- A5 reorder: tables before figures with subsections ---
a5_match = re.search(
    r"(## A5\. Pupil-DDM Fixed Effects and TEPR Visualization.*?)(\n\\newpage\n\n\n## A6\.)",
    text,
    re.DOTALL,
)
if not a5_match:
    raise SystemExit("Could not find A5 section")

a5_body = a5_match.group(1)
a6_start = a5_match.group(2)

intro_m = re.search(r"(## A5\..*?\n\n)", a5_body, re.DOTALL)
tepr_tc_m = re.search(
    r"(\n```\{r\}\n#\| label: fig-tepr-timecourse-supp.*?```\n)",
    a5_body,
    re.DOTALL,
)
tepr_sl_m = re.search(
    r"(\n```\{r\}\n#\| label: fig-tepr-slopes-supp.*?```\n)",
    a5_body,
    re.DOTALL,
)
loo_m = re.search(
    r"(\n```\{r\}\n#\| label: tbl-pupil-loo-appendix.*?```\n)",
    a5_body,
    re.DOTALL,
)
key_m = re.search(
    r"(\n```\{r\}\n#\| label: tbl-pupil-key-effects-appendix.*?```\n)",
    a5_body,
    re.DOTALL,
)
if not all([intro_m, tepr_tc_m, tepr_sl_m, loo_m, key_m]):
    raise SystemExit("Could not extract A5 sub-blocks")

a5_new = (
    intro_m.group(1)
    + "### A5.1 Fixed Effects and Model Comparison {.unnumbered}\n\n"
    + loo_m.group(1).strip()
    + "\n\n"
    + key_m.group(1).strip()
    + "\n\n"
    + "### A5.2 TEPR Visualization {.unnumbered}\n\n"
    + tepr_tc_m.group(1).strip()
    + "\n\n"
    + tepr_sl_m.group(1).strip()
    + "\n"
)

text = text[: a5_match.start()] + a5_new + a6_start + text[a5_match.end() :]

# --- A6: renumber subsections, merge priors, trim A6.5, move RT validation from A7.4 ---
text = text.replace(
    "### A6.0 Response-Signal Timing Structure {.unnumbered}",
    "### A6.1 Response-Signal Timing Structure {.unnumbered}",
)
text = text.replace(
    "### A6.1 Link Functions and Parameter Constraints {.unnumbered}",
    "### A6.2 Link Functions and Parameter Constraints {.unnumbered}",
)
text = text.replace(
    "### A6.2 Hierarchical Model Structure {.unnumbered}",
    "### A6.3 Hierarchical Model Structure {.unnumbered}",
)
text = text.replace(
    "### A6.3 Prior Specification {.unnumbered}",
    "### A6.4 Prior Specification {.unnumbered}",
)
text = text.replace(
    "### A6.4 Computational Details {.unnumbered}",
    "### A6.5 Computational Details {.unnumbered}",
)

# Remove duplicate priors paragraph in A6.4
text = re.sub(
    r"\*\*Priors\.\*\* All priors were weakly informative and specified on the link scale\. For intercepts, drift rate.*?@fig-ndt-prior-posterior, confirming adequate identifiability for the group-level intercept despite the response-signal design\.\n\n",
    "",
    text,
    count=1,
)

# Trim duplicated LOO/PPC in A6.5
text = re.sub(
    r"\n\*\*Model comparison\.\*\* We compared a small set of pre-specified behavioral DDM variants.*?@fig-loo-comparison\)\.\n\n",
    "\n",
    text,
    count=1,
)
text = re.sub(
    r"\n\*\*Posterior predictive checks\.\*\* Model fit was evaluated using posterior predictive checks \(PPC\).*?complete assessment\.\)\n\n\n",
    "\nModel comparison and posterior predictive checks are reported in Appendix A1 (@tbl-loo-comparison, @fig-loo-comparison) and Appendix A3 (@tbl-convergence-ppc-gate-appendix, @fig-ch3app-ppc-rt-overlay).\n\n\n",
    text,
    count=1,
)

# Move fig-rt-distributions from A7 to A6.1 (after fig-timing-supp)
rt_val_narrative = (
    "\nAs described in Methods, we adopted probe-onset-locked RT as our primary timing convention. "
    "@fig-rt-distributions confirms the expected 0.35-s rightward shift between cue-locked and probe-onset-locked RT distributions, "
    "validating correct implementation of the timing transformation. The probe-onset distribution incorporates the fixed post-probe delay (0.35 s) "
    "plus the response-window RT component, whereas cue-locked RT reflects only the response-window component. "
    "Subsequent DDM analyses use probe-onset-locked RT, with cue-locked RT serving as a sensitivity check (Appendix~A4.2).\n\n"
)

fig_rt_dist_m = re.search(
    r"(\n```\{r\}\n#\| label: fig-rt-distributions\n.*?```\n)",
    text,
    re.DOTALL,
)
if not fig_rt_dist_m:
    raise SystemExit("Could not find fig-rt-distributions chunk")

fig_rt_dist_block = fig_rt_dist_m.group(1)
text = text.replace(fig_rt_dist_block, "", 1)

text = text.replace(
    'include_graphics_safe(fig_path("AUC_timeline_v2.png"))\n```',
    'include_graphics_safe(fig_path("AUC_timeline_v2.png"))\n```'
    + rt_val_narrative
    + fig_rt_dist_block.strip()
    + "\n",
    1,
)

# Add RWiener/bayesplot to A6.5 if PPC mentioned - check computational section
text = text.replace(
    "Posterior analysis used `posterior` [@burkner2022posterior]. The manuscript was rendered using Quarto [@quarto].",
    "Posterior analysis used `posterior` [@burkner2022posterior]. Trial-level Wiener simulations for PPC used `RWiener` [@wabersich2014rwiener]; diagnostic plots used `bayesplot` [@gabry2019bayesplot]. The manuscript was rendered using Quarto [@quarto].",
)

# --- A7 rebuild ---
a7_match = re.search(
    r"## A7\. Manipulation Checks: Behavioral Validation.*?(\n## A8\. Exploratory LC Structural Correlates)",
    text,
    re.DOTALL,
)
if not a7_match:
    raise SystemExit("Could not find A7 section")

a7_body = a7_match.group(0)
a8_marker = a7_match.group(1)

def extract_block(pattern, body, name):
    m = re.search(pattern, body, re.DOTALL)
    if not m:
        raise SystemExit(f"Could not extract {name}")
    return m.group(1)

mc_sample = extract_block(r"(\n```\{r mc-sample-size\}.*?```\n)", a7_body, "mc-sample-size")
acc_compute = extract_block(
    r"(\n```\{r\}\n#\| include: false\n# Compute accuracy means for narrative.*?```\n)",
    a7_body,
    "acc compute",
)
acc_narrative = (
    "Hard trials were significantly less accurate than Easy trials, $\\beta = -2.97$, 95% CI [−3.07, −2.88], $p < .001$, "
    "with mean accuracies of `r acc_hard_mean`% (Hard) and `r acc_easy_mean`% (Easy) (@tbl-accuracy-glmm, @fig-accuracy-distribution). "
    "Accuracy was lowest in Hard+High effort cells (`r acc_hard_min`%), indicating that difficulty and effort effects combine additively. "
    "High-effort trials showed lower accuracy than Low-effort trials ($\\beta = -0.16$, 95% CI [−0.24, −0.07], $p < .001$), "
    "with mean accuracy of `r acc_high_mean`% (High) versus `r acc_low_mean`% (Low).\n\n"
)
tbl_acc = extract_block(
    r"(\n```\{r\}\n#\| label: tbl-accuracy-glmm.*?```\n)",
    a7_body,
    "tbl-accuracy-glmm",
)
fig_acc = extract_block(
    r"(\n```\{r\}\n#\| label: fig-accuracy-distribution.*?```\n)",
    a7_body,
    "fig-accuracy-distribution",
)
overall_compute = extract_block(
    r"(\n```\{r overall-accuracy-compute\}.*?```\n)",
    a7_body,
    "overall-accuracy-compute",
)
overall_narrative = (
    "Across Easy and Hard trials, older adults showed moderate overall accuracy (*M* = `r overall_acc_mean`%, *SD* = `r overall_acc_sd`%; @tbl-overall-accuracy). "
    "When including Standard trials (which had near-perfect performance), overall accuracy was `r overall_acc_with_standard`%. "
    "Accuracy varied substantially across individuals (range = `r overall_acc_min`–`r overall_acc_max`%), "
    "consistent with the strong effects of difficulty and effort documented above.\n\n"
)
tbl_overall = extract_block(
    r"(\n```\{r\}\n#\| label: tbl-overall-accuracy.*?```\n)",
    a7_body,
    "tbl-overall-accuracy",
)
rt_compute = extract_block(
    r"(\n```\{r rt-medians-compute\}.*?```\n)",
    a7_body,
    "rt-medians-compute",
)
rt_narrative = (
    "Hard trials were slower than Easy trials, $\\beta = 0.23 \\,\\text{s}$, 95% CI [0.20, 0.27], $p < .001$, "
    "with median RTs of `r rt_hard_median` s and `r rt_easy_median` s, respectively (@tbl-rt-lmm, @fig-rt-distribution). "
    "The effort manipulation did not reliably affect RT ($\\beta = 0.02 \\,\\text{s}$, 95% CI [−0.02, 0.05]).\n\n"
)
tbl_rt = extract_block(
    r"(\n```\{r\}\n#\| label: tbl-rt-lmm.*?```\n)",
    a7_body,
    "tbl-rt-lmm",
)
fig_rt = extract_block(
    r"(\n```\{r\}\n#\| label: fig-rt-distribution\n.*?```\n)",
    a7_body,
    "fig-rt-distribution",
)
closing = (
    "Difficulty reliably affected both accuracy ($\\beta = -2.97$, 95% CI [−3.07, −2.88], $p < .001$) "
    "and RT ($\\beta = 0.23$ s, 95% CI [0.20, 0.27], $p < .001$). Effort reduced accuracy "
    "($\\beta = -0.16$, 95% CI [−0.24, −0.07], $p < .001$) without reliably affecting RT "
    "($\\beta = 0.02$ s, 95% CI [−0.02, 0.05]). These patterns were consistent with successful experimental "
    "manipulation of perceptual difficulty and concurrent physical effort.\n"
)

a7_methods = """## A7. Manipulation Checks: Behavioral Validation {#sec-appendix-a7 .unnumbered}

To confirm that the difficulty and effort manipulations produced the expected behavioral effects prior to and independent of DDM estimation, we conducted mixed-effects analyses on accuracy and RT. These analyses are reported here as pre-modeling validation; primary DDM results do not depend on them.

### A7.1 Methods {.unnumbered}

Accuracy and RT were analyzed with mixed-effects models independent of DDM assumptions using `lme4` [@bates2015lme4]; fixed-effects summaries used `broom.mixed` [@broommixed].

**Accuracy analysis.** Accuracy was modeled using mixed-effects logistic regression (GLMM, binomial family) with fixed effects for difficulty, effort, and task (including interactions as needed), and random intercepts for subject. Analyses were restricted to Easy and Hard trials only (excluding Standard trials), as the difficulty manipulation is only meaningful within "different" trials where stimulus offsets vary.

**Reaction time analysis.** Reaction time was modeled using mixed-effects linear regression on cue-locked RT (median RT per subject-condition), with the same fixed and random effects structure as the accuracy model. Standard trials were excluded to focus on trials where difficulty manipulation is meaningful.

Full results are reported in Sections A7.2 and A7.3 below.
"""

a7_new = (
    a7_methods
    + mc_sample.strip()
    + "\n\n"
    + "### A7.2 Accuracy Results {.unnumbered}\n\n"
    + "We confirmed that the difficulty and effort manipulations affected accuracy as intended, "
    + "restricted to Easy and Hard trials (N = `r format(n_trials_mc, big.mark = \",\")`).\n\n"
    + acc_compute.strip()
    + "\n\n"
    + acc_narrative
    + tbl_acc.strip()
    + "\n\n"
    + fig_acc.strip()
    + "\n\n"
    + overall_compute.strip()
    + "\n\n"
    + overall_narrative
    + tbl_overall.strip()
    + "\n\n"
    + "### A7.3 Reaction Time Results {.unnumbered}\n\n"
    + rt_compute.strip()
    + "\n\n"
    + rt_narrative
    + tbl_rt.strip()
    + "\n\n"
    + fig_rt.strip()
    + "\n\n"
    + closing
    + a8_marker
)

text = text[: a7_match.start()] + a7_new + text[a7_match.end() :]

# --- Verify no duplicate labels ---
for label in ["fig-accuracy-distribution", "fig-rt-distribution", "fig-rt-distributions"]:
    count = len(re.findall(rf"#\| label: {re.escape(label)}\n", text))
    if count != 1:
        raise SystemExit(f"Expected 1 occurrence of {label}, found {count}")

QMD.write_text(text, encoding="utf-8")
print(f"Successfully updated {QMD}")
print(f"Lines: {len(text.splitlines())}")
