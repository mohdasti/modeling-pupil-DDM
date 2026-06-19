#!/usr/bin/env python3
"""Patch exported Google Doc plain text to match latest manuscript fixes."""

from __future__ import annotations

import re
import sys
from pathlib import Path

LIMITATIONS_REPLACEMENT = """Several limitations constrain the interpretation of these findings. First, the standard Wiener DDM assumes constant drift within each trial and does not include across-trial variability in drift (s_v), starting point (s_z), or non-decision time (s_t0). Second, the response-signal design enforced a fixed delay before overt responding; probe-onset RT alignment and an intercept-only t_0 identify condition effects within that shared timing regime but do not support strong claims about pure encoding or motor t_0 in isolation (Section 2.10). Reaction times are measured from response-screen onset rather than stimulus onset, confining the interpretation of t_0 to motor execution and response selection rather than early perceptual encoding. These design choices were necessary given the MRI-compatible grip-force paradigm but limit generalizability to free-response paradigms where t_0 reflects the full encoding-decision-motor chain. Posterior predictive checks flagged all 12 experimental cells against pre-specified KS/QP thresholds (Table 10), with deviations concentrated in fast RT tails (worst in Easy/VDT). Mid-body quantile–probability alignment was nevertheless acceptable (Appendix A3, Table 11), and key effort contrasts were stable across alternative RT lower-bound thresholds (Appendix A4.2, Table 14). Future extensions incorporating across-trial variability, a fast-guess contaminant mixture, or urgency-collapsing boundaries may improve absolute fit (Ratcliff & McKoon, 2008).

Third, the primary trial-wise pupil predictor—the Decision-Response AUC—spans both pre- and post-response epochs (Section 3.3). We repeated the nested pupil-DDM comparisons using the Truncated Decision-Response AUC (0.3–1.3 s post-probe; 12,150 trials with valid truncated TEPR) and Cavanagh-style pupil→a extensions on both windows; conclusions were unchanged (|ΔELPD| < 4; near-zero or small coefficients without LOO advantage). Remaining ambiguity likely reflects concurrent motor–autonomic confounds under sustained grip rather than window choice alone.

Fourth, Hard-trial accuracy fell near or below chance for many participants (Appendix A7), indicating that some Hard offsets sat near perceptual threshold rather than forming a clean graded difficulty manipulation above chance. Parameter estimates for Hard conditions should be interpreted with this floor effect in mind. Complementary sensitivity analyses for task-on-drift pooling and related robustness checks are reported in Appendix A4 (Table 16, Table 14) where already completed; a Standard+Easy-only primary refit excluding Hard trials remains planned.

Fifth, the concurrent isometric handgrip manipulation (40% MVC) may interact with motor execution in ways not fully captured by small fixed effects on t_0; future work integrating EMG or kinematic measures could disentangle central resource competition from peripheral motor interference. Linear Ballistic Accumulator or race models may also better accommodate the fast-tail RT dynamics observed in Easy-difficulty conditions, and future work could explore whether these model families yield the same substantive pattern of effort and difficulty effects on decision parameters.

Sixth, exploratory LC-MRI and neuropsychological correlates (Appendices A8 and A9) were underpowered for individual-differences moderation and did not enter the primary inferential framework; they are reported as descriptive context for sample characterization and do not alter the group-level DDM conclusions below."""


def patch(text: str) -> tuple[str, list[str]]:
    changes: list[str] = []

    # Figure 6 cross-reference
    old = "LOOIC = 38,662.7; Table 4)"
    new = "LOOIC = 38,662.7; Table 3)"
    if old in text:
        text = text.replace(old, new)
        changes.append("Figure 6 caption: Table 4 → Table 3")

    # Pupil section wording
    old = "The pupil → bias () test was pre-specified."
    new = "The pupil → bias (z) test was pre-specified as the primary pupil-linked contrast."
    if old in text:
        text = text.replace(old, new)
        changes.append("§3.3: expanded pre-specified pupil contrast wording")

    # Table 17 note minor fix
    old = "All pupil-augmented specifications on the same trial subset"
    new = "All pupil-augmented specifications use the same trial subset"
    if old in text:
        text = text.replace(old, new)
        changes.append("Table 17 note: on → use")

    old = "LOOIC values for m0–m3 equal"
    new = "LOOIC for m0–m3 equals"
    if old in text:
        text = text.replace(old, new)
        changes.append("Table 17 note: LOOIC wording")

    # A4.2 opening sentence
    old = "(Table 15, Table 14 and figures below)."
    new = "(Table 14 and figures below)."
    if old in text:
        text = text.replace(old, new)
        changes.append("A4.2: dropped Table 15 from opening sentence")

    # Remove LOOIC-by-cutoff figure block
    fig12_pat = re.compile(
        r"\s*Figure 12: LOOIC values across RT cutoff thresholds\.[\s\S]*?choice of RT cutoff\.\s*",
        re.MULTILINE,
    )
    if fig12_pat.search(text):
        text = fig12_pat.sub("\n\n", text)
        changes.append("Removed Figure 12 (LOOIC across cutoffs)")

    # Replace Table 15 with caption-only stub (drop misleading LOOIC columns)
    tbl15_pat = re.compile(
        r"Table 15: Full sensitivity analysis results across RT cutoffs \(0\.15, 0\.20, 0\.25 s\)\.[\s\S]*?(?=Figure 12:|Figure 13:|A4\.3 Task)",
    )
    tbl15_repl = (
        "Table 15: Full sensitivity analysis results across RT cutoffs (0.15, 0.20, 0.25 s). "
        "LOOIC columns are omitted because trial counts differ across cutoffs and prior exports "
        "mixed baseline-model LOOIC with additive refits; see Table 13 and Table 14 for trial counts "
        "and H1/H2 contrasts.\n\n"
    )
    if tbl15_pat.search(text):
        text = tbl15_pat.sub(tbl15_repl, text)
        changes.append("Table 15: replaced body with LOOIC-omission note")

    # Replace entire limitations body
    lim_pat = re.compile(
        r"Several limitations constrain the interpretation of these findings\.[\s\S]*?(?=4\.8 Conclusions)",
    )
    if lim_pat.search(text):
        text = lim_pat.sub(LIMITATIONS_REPLACEMENT + "\n\n", text)
        changes.append("Limitations §4.7: replaced with clean numbered version (no duplicates)")

    return text, changes


def main() -> int:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/gdoc_export.txt")
    dst = Path(
        sys.argv[2]
        if len(sys.argv) > 2
        else "reports/chap3_ddm_results_GDOC_PATCHED.txt"
    )
    text = src.read_text(encoding="utf-8-sig")
    patched, changes = patch(text)
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(patched, encoding="utf-8")

    print(f"Patched export written to: {dst}")
    print("Changes applied:")
    for c in changes:
        print(f"  - {c}")
    if not changes:
        print("  (no changes matched — export may already be patched)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
