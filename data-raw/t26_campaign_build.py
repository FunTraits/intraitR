#!/usr/bin/env python3
"""Build the campaign tables shipped in intraitR/inst/extdata/T26_Saudrune/
from the FishInTrait campaign working files. Mirror of data-raw/t26_campaign_prepare.R.
"""
import csv, gzip, os, re, collections, datetime, openpyxl

PROJECT = os.path.expanduser("~/mnt/00_CampagneIntrait/00_project")
PKG     = os.path.expanduser("~/mnt/intraitR")
OUT     = os.path.join(PKG, "inst", "extdata", "T26_Saudrune")
SITE    = "SAUDRUNESUDTOULOUSE"
TODAY   = datetime.date.today().isoformat()
PTS     = range(1, 26)

def num(v):
    try:
        f = float(v); return f if f == f else None
    except (TypeError, ValueError):
        return None

def sheet(wb, name):
    rows = list(wb[name].iter_rows(values_only=True))
    hdr = list(rows[0]); return [dict(zip(hdr, r)) for r in rows[1:]]

wb   = openpyxl.load_workbook(os.path.join(PROJECT, "measurements", "landmarks.xlsx"), read_only=True)
meas = sheet(wb, "measurements")
bias = sheet(wb, "bias")

# ---- campaign export: identity, current determination, taxon codes -----------
export = [x for x in csv.DictReader(open(os.path.join(PROJECT, "export", "specimens.csv")))
          if x["site"] == SITE]
export = {x["specimen_code"]: x for x in export}
det = [x for x in csv.DictReader(open(os.path.join(PROJECT, "export", "determinations.csv")))
       if x["uid"].startswith(SITE) and x["superseded"].upper() != "TRUE"]
current = {}
for x in det:                      # last non-superseded line wins (file is append-only)
    current[x["uid"]] = x
taxa = {x["species"]: x["species_code"] for x in csv.DictReader(open(os.path.join(PROJECT, "export", "taxa.csv")))}

def uid_of(code): return re.sub(r"_i\d+$", "", str(code))
def ind_of(code):
    m = re.search(r"_i(\d+)$", str(code)); return int(m.group(1)) if m else 1

# ---- exclusions --------------------------------------------------------------
qc, keep = [], []
for x in meas:
    code, uid = str(x["specimen"]), uid_of(x["specimen"])
    anat = [p for p in range(1, 20) if num(x.get(f"{p}_X")) is not None]
    if not anat:
        qc.append((code, "row saved with no anatomical landmark at all (empty configuration); excluded")); continue
    if uid not in export:
        qc.append((code, "no entry in the campaign specimen export (export/specimens.csv): no identity, excluded rather than guessed")); continue
    if uid not in current:
        qc.append((code, "no current determination in export/determinations.csv: no species, excluded rather than guessed")); continue
    keep.append(x)
# A photograph holding both a bare record and indexed `_iK` records is a
# convention conflict: the same fish digitized again under a plate index. The
# bare record (the single-fish code) is kept; the indexed siblings are excluded
# pending an operator decision.
bare = {str(x["specimen"]) for x in keep if ind_of(x["specimen"]) == 1 and "_i" not in str(x["specimen"])}
conflict = [x for x in keep if re.search(r"_i\d+$", str(x["specimen"])) and uid_of(x["specimen"]) in bare]
for x in conflict:
    qc.append((str(x["specimen"]), "photograph also digitized under its bare code: same fish measured again under a plate index; excluded pending an operator decision (bare record kept)"))
keep = [x for x in keep if x not in conflict]
dups = collections.Counter(str(x["specimen"]) for x in keep)
assert all(c == 1 for c in dups.values()), "duplicate specimen codes in measurements"

# ---- landmarks (long, rectangular 25 points) ----------------------------------
def long_rows(records, specimen_of, code_of, extra):
    out = []
    for x in records:
        op = (x.get("operator") or "AT").strip()
        for p in PTS:
            X, Y = num(x.get(f"{p}_X")), num(x.get(f"{p}_Y"))
            out.append([specimen_of(x), code_of(x), op] + extra(x) + [p,
                        "" if X is None else round(X, 3), "" if Y is None else round(Y, 3)])
    return out

keep.sort(key=lambda x: str(x["specimen"]))
long = long_rows(keep, lambda x: str(x["specimen"]), lambda x: str(x["specimen"]), lambda x: [])
os.makedirs(OUT, exist_ok=True)
with gzip.open(os.path.join(OUT, "t26_campaign_landmarks.csv.gz"), "wt", newline="") as f:
    w = csv.writer(f); w.writerow(["specimen", "code", "operator", "landmark", "X", "Y"]); w.writerows(long)

# ---- specimens (one row per digitized specimen) -------------------------------
spec_rows = []
for x in keep:
    code, uid = str(x["specimen"]), uid_of(x["specimen"])
    e, d = export[uid], current[uid]
    sp = d["taxon"]
    n_lm = sum(1 for p in PTS if num(x.get(f"{p}_X")) is not None)
    spec_rows.append(dict(
        code=code, uid=uid, individual=ind_of(code), photo=x["photo_file"],
        species=sp, species_code=taxa.get(sp, ""), confidence=d["confidence"],
        determined_by=d["determined_by"], site=SITE, date=uid.split("_")[1],
        operator=(x.get("operator") or "AT").strip(), quality=x.get("quality") or "",
        reviewed=x.get("reviewed") or "", n_landmarks=n_lm,
        ruler_mm=x.get("ruler_mm") or "", mm_per_px=(round(num(x.get("mm_per_px")), 9) if num(x.get("mm_per_px")) else ""),
        img_w=x.get("img_w") or "", img_h=x.get("img_h") or "", photo_hash=x.get("photo_hash") or "",
        app_version=x.get("app_version") or "", digitized=str(x.get("timestamp") or "")[:10]))
cols = list(spec_rows[0].keys())
with open(os.path.join(OUT, "t26_campaign_specimens.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, cols); w.writeheader(); w.writerows(spec_rows)

# ---- repeatability (bias sheet) -----------------------------------------------
REP = re.compile(r"^(.*)_([^_]+)_rep(\d+)$")
rep_recs = []
for x in bias:
    m = REP.match(str(x["specimen"]))
    if not m: raise SystemExit("unexpected repeat id: " + str(x["specimen"]))
    x = dict(x); x["_code"], x["_op"], x["_rep"] = m.group(1), m.group(2), int(m.group(3)); rep_recs.append(x)
rep_recs.sort(key=lambda x: (x["_code"], x["_op"], x["_rep"]))
rep_long = long_rows(rep_recs, lambda x: str(x["specimen"]), lambda x: x["_code"], lambda x: [x["_rep"]])
# column order: specimen, code, operator, replicate, landmark, X, Y
with gzip.open(os.path.join(OUT, "t26_campaign_repeatability.csv.gz"), "wt", newline="") as f:
    w = csv.writer(f); w.writerow(["specimen", "code", "operator", "replicate", "landmark", "X", "Y"]); w.writerows(rep_long)

# ---- qc log -------------------------------------------------------------------
with open(os.path.join(OUT, "t26_campaign_qc_log.csv"), "w", newline="") as f:
    w = csv.writer(f); w.writerow(["code", "reason"]); w.writerows(sorted(qc))

# ---- remeasure list (campaign QC artefact, not shipped) ------------------------
measured = {str(x["specimen"]) for x in meas}
measured_uid = {uid_of(c) for c in measured}
rem = []
for uid, e in sorted(export.items()):
    if uid not in measured_uid:
        rem.append((uid, e["species"], "never digitized: photograph in export/specimens.csv with no measurement row", e.get("qc_flag", "")))
conflict_codes = {str(x["specimen"]) for x in conflict}
for x in meas:
    code = str(x["specimen"]); e = export.get(uid_of(code), {})
    if code in conflict_codes: continue
    anat_missing = [p for p in range(1, 20) if num(x.get(f"{p}_X")) is None]
    scale_missing = [p for p in (20, 21) if num(x.get(f"{p}_X")) is None]
    reasons = []
    if len(anat_missing) == 19: reasons.append("empty configuration")
    elif anat_missing: reasons.append("anatomical landmark(s) missing: " + ",".join(map(str, anat_missing)))
    if scale_missing and len(anat_missing) < 19: reasons.append("scale bar missing: " + ",".join(map(str, scale_missing)))
    q = num(x.get("quality"))
    if q is not None and q <= 2: reasons.append(f"operator quality score {int(q)}")
    if e.get("qc_flag"): reasons.append("export qc_flag=" + e["qc_flag"])
    if uid_of(code) not in current: reasons.append("no current determination")
    if reasons:
        rem.append((code, e.get("species", ""), "; ".join(reasons), e.get("qc_flag", "")))
for x in conflict:
    rem.append((str(x["specimen"]), current[uid_of(x["specimen"])]["taxon"], "duplicate digitization of " + uid_of(x["specimen"]) + " under a plate index: arbitrate (delete the index record, or renumber if it really is a second fish)", ""))
qcdir = os.path.join(PROJECT, "qc"); os.makedirs(qcdir, exist_ok=True)
rem_path = os.path.join(qcdir, f"t26_remeasure_list_{TODAY}.csv")
with open(rem_path, "w", newline="") as f:
    w = csv.writer(f); w.writerow(["code", "species", "reason", "action", "export_qc_flag"])
    def action(r):
        if r[2].startswith("duplicate"): return "arbitrate duplicate"
        if "scale bar missing" in r[2]:
            uid = uid_of(r[0]); mates = [k["code"] for k in spec_rows if k["uid"] == uid and k["code"] != r[0] and all(num(next(x for x in keep if str(x["specimen"]) == k["code"]).get(f"{p}_X")) is not None for p in (20, 21))]
            return ("copy scale bar from plate-mate " + mates[0]) if mates else "re-digitize scale bar (20-21) on this photograph"
        if "quality score" in r[2]: return "re-digitize: operator flagged the configuration as poor"
        if "blurry" in r[2]: return "re-photograph if possible; otherwise review landmarks and keep quality score"
        return "digitize"
    w.writerows([list(r[:3]) + [action(r), r[3]] for r in sorted(rem, key=lambda r: (action(r).split(" ")[0], r[0]))])

# ---- report -------------------------------------------------------------------
print("specimens kept:", len(spec_rows), "| excluded:", len(qc))
print("species:", collections.Counter(r["species"] for r in spec_rows).most_common())
print("plates: individuals", sum(1 for r in spec_rows if r["individual"] > 1 or re.search(r"_i\d+$", r["code"])), "| photos", len({r["uid"] for r in spec_rows}))
print("n_landmarks:", collections.Counter(r["n_landmarks"] for r in spec_rows).most_common())
print("dates:", collections.Counter(r["date"] for r in spec_rows))
print("repeat:", len(rep_recs), "records |", len({x['_code'] for x in rep_recs}), "individuals |", collections.Counter(x['_op'] for x in rep_recs))
print("qc reasons:", collections.Counter(r for _, r in qc))
print("remeasure:", len(rem), collections.Counter(r[2].split(':')[0].split(';')[0] for r in rem))
print("export vs determinations disagreement:", sum(1 for uid, e in export.items() if uid in current and e['species'] != current[uid]['taxon']))
print("written:", rem_path)
