# Part B. Archive the mixed-clock pupil files and copy r8 into final_20261016.
# Does not fit a model. Stops by writing output/diagnostics/r8_finalize/STOPPED.md.

import csv
import hashlib
import shutil
from pathlib import Path

ROOT = Path(".").resolve()
FINAL = ROOT / "output/ddm_refits/runs/final_20261016"
R8 = ROOT / "output/ddm_refits/runs/r8_20261017_015218"
ARCH_NAME = "archive_superseded_" + "r5r6"
ARCH = FINAL / ARCH_NAME
DIAG = ROOT / "output/diagnostics/r8_finalize"
DIAG.mkdir(parents=True, exist_ok=True)

PUPIL_IDS = [
    "P0", "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8",
    "P3_rt", "P0_r6", "P0_rt", "P0_lag", "P0_pre", "P0_grip",
]
R8_IDS = [
    "P0", "P1", "P2", "P3", "P0_base", "P4", "P5",
    "P0_rt", "P3_rt", "P0_lag", "P6", "P0_pre", "P7", "P0_grip", "P8",
]
EXPECTED_N = {
    "P0": 4952, "P1": 4952, "P2": 4952, "P3": 4952,
    "P0_base": 4612, "P4": 4612, "P5": 4612,
    "P0_rt": 3986, "P3_rt": 3986,
    "P0_lag": 3823, "P6": 3823,
    "P0_pre": 3678, "P7": 3678,
    "P0_grip": 4444, "P8": 4444,
}
ROLE = {
    "P0": "pupil", "P1": "pupil", "P2": "pupil", "P3": "pupil", "P4": "pupil",
    "P3_rt": "pupil-ordering", "P5": "pupil-ordering", "P6": "pupil-ordering",
    "P7": "pupil-ordering", "P8": "pupil-ordering",
    "P0_base": "pupil-ordering baseline", "P0_rt": "pupil-ordering baseline",
    "P0_lag": "pupil-ordering baseline", "P0_pre": "pupil-ordering baseline",
    "P0_grip": "pupil-ordering baseline",
}
FORMULA = {
    "P0": "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id) bs ~ difficulty_3 + task + effort_condition + (1 | subject_id) ndt ~ 1 bias ~ task + effort_condition + (1 | subject_id)",
    "P1": "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id) bs ~ difficulty_3 + task + effort_condition + (1 | subject_id) ndt ~ 1 bias ~ task + effort_condition + tepr_c + (1 | subject_id)",
    "P2": "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + tepr_c + tepr_c:stim_sign + (1 | subject_id) bs ~ difficulty_3 + task + effort_condition + (1 | subject_id) ndt ~ 1 bias ~ task + effort_condition + (1 | subject_id)",
    "P3": "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id) bs ~ difficulty_3 + task + effort_condition + tepr_c + (1 | subject_id) ndt ~ 1 bias ~ task + effort_condition + (1 | subject_id)",
    "P4": "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id) bs ~ difficulty_3 + task + effort_condition + (1 | subject_id) ndt ~ 1 bias ~ task + effort_condition + base_c + (1 | subject_id)",
    "P5": "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id) bs ~ difficulty_3 + task + effort_condition + base_c + (1 | subject_id) ndt ~ 1 bias ~ task + effort_condition + (1 | subject_id)",
    "P6": "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id) bs ~ difficulty_3 + task + effort_condition + lag_tepr_c + (1 | subject_id) ndt ~ 1 bias ~ task + effort_condition + (1 | subject_id)",
    "P7": "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id) bs ~ difficulty_3 + task + effort_condition + prechoice_c + (1 | subject_id) ndt ~ 1 bias ~ task + effort_condition + (1 | subject_id)",
    "P8": "rt | dec(choice_binary) ~ difficulty_3 * task + effort_condition + effort_x_stim + (1 | subject_id) bs ~ difficulty_3 + task + effort_condition + grip_c + (1 | subject_id) ndt ~ 1 bias ~ task + effort_condition + (1 | subject_id)",
}
FORMULA["P0_base"] = FORMULA["P0"]
FORMULA["P0_rt"] = FORMULA["P0"]
FORMULA["P0_lag"] = FORMULA["P0"]
FORMULA["P0_pre"] = FORMULA["P0"]
FORMULA["P3_rt"] = FORMULA["P3"]
FORMULA["P0_grip"] = FORMULA["P0"]


def stop(step, msg):
    (DIAG / "STOPPED.md").write_text(f"# Stopped at Part B, step {step}\n\n{msg}\n")
    raise SystemExit(msg)


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_csv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path, rows):
    if not rows:
        stop("B4", f"Refusing to write an empty table: {path}")
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)


# B1
for sub in ("models", "loo", "draws", "tables", "figures"):
    (ARCH / sub).mkdir(parents=True, exist_ok=True)
(ARCH / "README.md").write_text(
    "Pupil models fit on a mixed flat-file table (640 of 4,569 trials on a stretched clock). "
    "Invalid. Do not cite. Replaced by r8_20261017_015218.\n"
)

moved = []
for mid in PUPIL_IDS:
    src = FINAL / "models" / f"{mid}__probe_onset_locked__thr0.20.rds"
    if not src.exists():
        stop("B1", f"Missing pupil model to archive: {src}")
    dest = ARCH / "models" / src.name
    shutil.move(str(src), str(dest))
    moved.append(str(dest.relative_to(ROOT)))

loo_names = []
for p in (FINAL / "loo").iterdir():
    name = p.name
    if name.startswith("loo_P") and (name.endswith(".rds") or name.endswith("_status.csv")):
        loo_names.append(p)
for p in loo_names:
    dest = ARCH / "loo" / p.name
    shutil.move(str(p), str(dest))
    moved.append(str(dest.relative_to(ROOT)))

for p in list((FINAL / "draws").glob("draws_P*.csv")):
    dest = ARCH / "draws" / p.name
    shutil.move(str(p), str(dest))
    moved.append(str(dest.relative_to(ROOT)))

for folder, patterns in (
    (FINAL / "tables" / "final", ("T7_*", "T8_*", "T9_*")),
    (FINAL / "figures" / "final", ("F5_*", "S_tepr_timecourse*", "S_participant_flow*")),
):
    dest_dir = ARCH / ("tables" if "tables" in str(folder) else "figures")
    for pat in patterns:
        for p in folder.glob(pat):
            dest = dest_dir / p.name
            shutil.move(str(p), str(dest))
            moved.append(str(dest.relative_to(ROOT)))

# B2
md5_log = []
for mid in R8_IDS:
    src = R8 / "models" / f"{mid}__probe_onset_locked__thr0.20.rds"
    if not src.exists():
        stop("B2", f"Missing r8 model: {src}")
    dest = FINAL / "models" / src.name
    shutil.copy2(src, dest)
    a, b = md5(src), md5(dest)
    md5_log.append((mid, "model", a, b))
    if a != b:
        stop("B2", f"md5 mismatch for {mid} model: {a} vs {b}")
    for suffix in (f"loo_{mid}.rds", f"loo_{mid}_status.csv"):
        s = R8 / "loo" / suffix
        if not s.exists():
            stop("B2", f"Missing r8 loo file: {s}")
        d = FINAL / "loo" / suffix
        shutil.copy2(s, d)
        a, b = md5(s), md5(d)
        md5_log.append((mid, suffix, a, b))
        if a != b:
            stop("B2", f"md5 mismatch for {suffix}: {a} vs {b}")

draws_src = R8 / "draws"
if draws_src.exists():
    for p in draws_src.iterdir():
        if p.is_file():
            d = FINAL / "draws" / p.name
            shutil.copy2(p, d)
            a, b = md5(p), md5(d)
            if a != b:
                stop("B2", f"md5 mismatch for draws {p.name}")
else:
    (DIAG / "b2_draws_note.txt").write_text(
        "r8_20261017_015218 has no draws/ directory. Posterior draws are inside the model RDS files. "
        "No draws CSV was invented.\n"
    )

# B3
conv = {r["model"]: r for r in read_csv(R8 / "tables" / "convergence.csv")}
pareto = {r["model"]: r for r in read_csv(FINAL / "tables" / "final_r8" / "r8_pareto_k.csv")}
for mid, n_exp in EXPECTED_N.items():
    got = int(conv[mid]["n"])
    if got != n_exp:
        stop("B3", f"{mid} n_trials is {got}, expected {n_exp}")
    if int(pareto[mid]["n_pointwise"]) != n_exp:
        stop("B3", f"{mid} LOO pointwise length {pareto[mid]['n_pointwise']} != {n_exp}")

manifest_path = FINAL / "MANIFEST.csv"
with open(manifest_path, newline="") as f:
    reader = csv.DictReader(f)
    fields = reader.fieldnames
    rows = list(reader)

archive_ids = set(PUPIL_IDS)
for row in rows:
    if row["model_id"] in archive_ids:
        row["role"] = "superseded_mixed_clock"
        row["model_id"] = row["model_id"] + "__mixed_clock"
        name = Path(row["final_path"]).name
        row["final_path"] = f"output/ddm_refits/runs/final_20261016/{ARCH_NAME}/models/{name}"
        row["notes"] = (row.get("notes") or "").strip()
        extra = "Archived. Mixed flat-file clock. Do not cite."
        row["notes"] = (row["notes"] + " " + extra).strip()

new_rows = []
for mid in R8_IDS:
    src = f"output/ddm_refits/runs/r8_20261017_015218/models/{mid}__probe_onset_locked__thr0.20.rds"
    dest = f"output/ddm_refits/runs/final_20261016/models/{mid}__probe_onset_locked__thr0.20.rds"
    digest = next(a for m, kind, a, b in md5_log if m == mid and kind == "model")
    c = conv[mid]
    p = pareto[mid]
    new_rows.append({
        "model_id": mid,
        "role": ROLE[mid],
        "source_run": "r8_20261017_015218",
        "source_path": src,
        "final_path": dest,
        "md5_source": digest,
        "md5_final": digest,
        "n_trials": str(EXPECTED_N[mid]),
        "n_subjects": "42",
        "formula": FORMULA[mid],
        "chains": "8",
        "iter": "3000",
        "warmup": "1500",
        "save_pars_all": "TRUE",
        "max_rhat": c["rhat"],
        "min_bulk_ess": c["ess_bulk"],
        "passes_convergence_rule": "TRUE" if c["pass"] in ("TRUE", "True", "true") else c["pass"],
        "elpd_loo": p["elpd_loo"],
        "se_elpd_loo": p["se_elpd_loo"],
        "n_k_gt_0.7": p["n_k_gt_0.7"],
        "notes": f"Pareto-k (0.5, 0.7] = {p['n_k_0.5_0.7']}; loo_fix = {p['loo_fix']}; max_k = {p['max_k']}",
    })

with open(manifest_path, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=fields)
    w.writeheader()
    w.writerows(rows + new_rows)

# B4 tables
src_tab = FINAL / "tables" / "final_r8"
dst_tab = FINAL / "tables" / "final"

t7 = read_csv(src_tab / "T7_pupil_models.csv")
for r in t7:
    r["source_model"] = r["model"]
    if r["model"] == "P3":
        r["tier"] = "main"
    elif r["model"] in ("P0", "P1", "P2", "P4"):
        r["tier"] = "ms_supp"
write_csv(dst_tab / "T7_pupil_models.csv", t7)

t7e = read_csv(src_tab / "T7_P0_effort_terms.csv")
for r in t7e:
    r["source_model"] = "P0"
    r["tier"] = "ms_supp"
write_csv(dst_tab / "T7_P0_effort_terms.csv", t7e)

t8 = read_csv(src_tab / "T8_pupil_ordering.csv")
for r in t8:
    if r["model"] not in ("P3", "P3_rt", "P5", "P6", "P7", "P8"):
        stop("B4", f"Unexpected T8 model {r['model']}")
    r["tier"] = "main"
    if not r.get("source_model"):
        r["source_model"] = r["model"]
write_csv(dst_tab / "T8_pupil_ordering.csv", t8)

t9 = read_csv(src_tab / "T9_pupil_descriptives.csv")
for r in t9:
    block = r["block"]
    outcome = r.get("outcome") or ""
    if block == "qc_gate" or block == "tepr_rt_correlation" or block == "grip_paired":
        r["tier"] = "main"
    elif block == "paired_high_minus_low" and outcome == "tepr_raw":
        r["tier"] = "main"
    else:
        r["tier"] = "ms_supp"
    if not r.get("source_model"):
        stop("B4", "T9 row missing source_model")
write_csv(dst_tab / "T9_pupil_descriptives.csv", t9)

print(f"Moved {len(moved)} archived files")
print(f"Copied {len(R8_IDS)} models with matching md5")
print("MANIFEST and tables/final updated")
