# Opus Audit Packet — Pupil Framing vs. Appendix Placement
**Chapter:** Physical Effort Reduces Evidence Accumulation Quality in Older Adults (hierarchical DDM + pupillometry)  
**Run ID:** `20260226_092110`  
**Date:** 2026-06-07  
**Note:** Full PDF not attached (figure count limits). Use this packet + optional CSVs.

---

## 1. Author question (please adjudicate)

**Earlier audit (Phase D)** suggested moving pupil tables / exploratory pupil content toward the **appendix**, because behavioral DDM is the clean primary story and pupil evidence is weak.

**Author intent:** Pupil-linked hierarchical DDM is a **core novel contribution** — multimodal integration of trial-wise TEPR with decision parameters under concurrent physical effort in older adults — not optional supplementary material.

**Proposed hybrid (please evaluate):**
- **Keep** dedicated **Results §3.3** (Pupil-linked DDM models) in main text.
- **Main text minimum:** model sequence, hypotheses tested, one summary coefficient table, at most 1–2 figures, explicit inconclusive conclusion + measurement limits.
- **Appendix:** full pupil LOO, long fixef tables, convergence dumps, redundant interaction diagnostics.
- **Abstract / Discussion:** Lead with secured behavioral finding (H1: effort → drift); frame pupil as rigorously tested multimodal extension that was **not identifiable** with current TEPR under sustained grip.

**Do not recommend:** removing pupillometry from the chapter narrative or claiming pupil→parameter coupling without caveats.

---

## 2. Study design (brief)

- **Sample:** 67 older adults (ADT *N*≈64, VDT *N*≈65 after task-specific exclusions).
- **Task:** Response-signal auditory/visual same–different under concurrent isometric grip (Low 5% vs High 40% MVC).
- **Primary DDM:** probe-onset-locked RT; additive model (difficulty + effort → *v*, *a*; effort + task → *z*; *t₀* intercept-only).
- **Pupil metric:** Decision-Response AUC (baseline-corrected; 3.0 s window, 0.3–3.3 s post-probe); within-subject *z*-scored for pupil-DDM models.
- **Pupil models (nested):** (1) behavioral baseline, (2) pupil→bias, (3) pupil→drift+bias, (4) pupil×difficulty on *v*.

---

## 3. Phase A integrity fixes (completed)

| Issue | Resolution |
|-------|------------|
| RT threshold applied to cue-locked RT, not probe-onset RT | Pipeline fixed; probe & cue models now **17,857** trials (was 18,097 probe) |
| H4 reported from standard-only Δ*z* instead of primary logit | QMD fixed; primary from `bias_effort_conditionhigh` on logit link |
| Fig 3 caption hardcoded wrong stats | Dynamic from CSV / inline vars |
| Stale `table_effect_contrasts.csv` | Regenerated from new fit |
| PPC on misaligned trial set | Re-run on 17,857 trials, probe-onset RT |
| Publish gate / PPC extracts | Updated |

---

## 4. Key quantitative results (post-refit)

### Behavioral primary (additive, probe-onset, thr 0.20)

| Quantity | Value |
|----------|-------|
| *N* trials | 17,857 |
| *N* subjects | 67 |
| Max R̂ | 1.006 |
| Min bulk ESS | 745 |
| Divergences | 0 |

| Hypothesis | Estimate (link) | 95% CrI | Verdict |
|------------|-----------------|--------|---------|
| **H1** effort → drift *v* | β ≈ −0.057 | [−0.097, −0.017] | Supported (excludes 0) |
| **H2** effort → boundary *a* | β ≈ +0.017 (log) | [0.004, 0.029] | Small credible increase (CrI excludes 0) |
| **H4** effort → bias *z* (primary) | β ≈ −0.005 (logit) | [−0.046, 0.036] | Near zero; CrI spans 0 |
| H4 standard-only calibration | Δ*z* ≈ −0.005 | spans 0 | Reported separately (§3.2.2 / A2) |

Difficulty contrasts on drift (examples): Easy−Standard β ≈ +2.07; Hard−Standard β ≈ +0.57 (all CrIs exclude 0).

### PPC (subject-wise, post-fix)

- 12/12 cells fail strict pre-registered QP/KS gates.
- Max KS (conditional PPC) ≈ 0.343; max QP ≈ 0.225.
- Interpretation in manuscript: fast-tail / Easy–VDT misfit; does not overturn H1.

### Pupil-linked DDM

- Trial subset with valid pupil: **~5,000 trials** (not 17,857) — cross-*N* ELPD vs full behavioral model is **invalid**.
- Pooled TEPR → drift and TEPR → bias: posterior coefficients **near zero**, CrIs span zero.
- PSIS-LOO: max Pareto-*k* ≈ **0.91** for pupil-augmented models → **unreliable for model ranking**.
- Descriptive TEPR often **lower under High than Low effort** (motor/autonomic confound under sustained grip).

---

## 5. Current manuscript structure

### Introduction
- Aging, effort, DDM decomposition, pupillometry/TEPR as arousal index.
- Hypotheses H1–H4 + pupil extensions (bias reset, drift modulation, Yerkes–Dodson interaction).

### Methods
- Full pupillometry preprocessing; Decision-Response AUC specification.
- `@sec-pupil-ddm-models`: nested pupil-augmented specifications.

### Results
| Section | Content |
|---------|---------|
| **§3.1** | Sample, model selection, convergence (behavioral) |
| **§3.2** | Behavioral DDM; H1–H4; §3.2.2 standard-only bias |
| **§3.3** | **Pupil-linked DDM** (main Results — not appendix) |
| **§3.4–3.5** | Exploratory choice history & fatigue |

### Appendix
- A1: LOO (behavioral)
- A3: PPC diagnostics
- **A5:** Pupil LOO tables, full fixef, TEPR supplement figures

### Discussion
- Primary claim: effort degrades evidence accumulation (drift).
- Pupil: **inconclusive** (measurement-limited), contrast with de Gee et al. (phasic pupil bias reset in younger adults).

---

## 6. Results §3.3 opening (current prose excerpt)

> To examine whether trial-wise arousal fluctuations modulate decision parameters, we compared a nested sequence of four pupil-augmented DDM specifications: (1) behavioral baseline; (2) pupil→bias; (3) pupil→drift+bias; (4) pupil×difficulty. Pareto-*k* exceeded 0.7 for all pupil-augmented models (max *k* = 0.91), so ELPD differences are not a reliable basis for model selection; we interpret pupil effects primarily from posterior coefficients. Pooled TEPR coefficients were near zero with CrIs spanning zero.

---

## 7. Questions for Opus (required output)

1. **Verdict:** appendix-only vs **hybrid** vs full main-text pupil — and why?
2. **§3.3 outline:** bullets for main-text paragraphs, tables, figures vs appendix.
3. **Abstract template:** 2–3 sentences behavioral + 2–3 pupil (≤250 words total chapter abstract).
4. **Discussion template:** one paragraph on pupil contribution without overclaiming.
5. Should **H4** (effort→bias) be integrated with pupil bias-reset narrative in §3.3 or stay in §3.2.2?
6. Any **remaining integrity red flags** given Phase A fixes?
7. **Phase B priorities** (top 3) if pupil stays in main Results.

---

## 8. Optional CSV attachments (if upload allows)

```
output/ddm_refits/runs/20260226_092110/tables/
  convergence_summary.csv
  fixef_link_scale.csv
  table_effect_contrasts.csv
  loo_summary.csv

output/publish/
  table3_ppc_primary_subjectwise_censored.csv
  publish_gate_primary_censored.csv
```

---

## 9. Phase B still open (not required for placement advice)

- Reframe pupil LOO text (drop invalid cross-*N* ΔELPD claims).
- Export real pupil convergence + interaction fixef tables.
- Truncated Decision-Response AUC sensitivity analysis.
