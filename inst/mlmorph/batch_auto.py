#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
batch_auto.py -- landmarking TOUT AUTOMATIQUE d'un lot de photographies, sans
les ouvrir une à une.

Pour chaque photo : réseau global (photo entière, puis passe zoomée sur le
poisson détecté) -> LM1, LM2, côté dorsal -> repère canonique -> modèle fin
(cnn) -> 19 landmarks en pixels de la photo d'origine (grille brute, comme
les applications R). Mêmes fonctions que predict_new_image.py --auto, mais les
modèles sont chargés UNE fois (environ 0,3 s par photo sur CPU).

Contrôle qualité, sans rien regarder : chaque photo reçoit un score de risque
et des drapeaux :
  plusieurs  un poisson de plus que --max-fish a été trouvé (planche non déclarée) ;
  dorsal     le côté dorsal du réseau global et le LM3 du modèle fin se
             contredisent (poisson peut-être retourné) ;
  petit      poisson < --min-bl-frac de la plus grande dimension de la photo ;
  bord       un point à moins de 1 % du bord ou hors image ;
  confiance  score (confiance moyenne du modèle fin) parmi les 10 % les plus bas du lot.
Localisation robuste (GlobalModel.locate_verified) : plusieurs candidats par
point, chaque couple museau-caudale vérifié par le modèle fin ; planches :
détection, masquage du poisson trouvé, et ainsi de suite.
Les photos signalées sont à revoir en priorité ; les autres peuvent être
acceptées après un simple coup d'œil à la planche de contrôle.

Sorties dans --out-dir :
  landmarks_long.csv   photo, individual, landmark, X, Y, conf
  landmarks_wide.csv   une ligne par poisson : X1, Y1, ..., X19, Y19
  summary.csv          dimensions, Bl (px), confiances, écarts, drapeaux, risque
  qc/<photo>.jpg       vignette annotée (si --qc) ; qc/index.html : planche
                       triée par risque décroissant
La règle (20-21) n'est pas détectée : les mesures sont en pixels.
Reprise : une photo déjà présente dans summary.csv est sautée (--redo pour tout refaire).

Usage (depuis ml_morph/) :
  python batch_auto.py --input "../../00_CampagneIntrait/00_project/prepared/SITE/DATE" \\
                       --out-dir batch_SITE_DATE [--recursive] [--qc]
"""
import argparse, glob, html, math, os, sys, time
import numpy as np, pandas as pd, cv2
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import predict_new_image as W

EXT = (".jpg", ".jpeg", ".png", ".tif", ".tiff", ".bmp")


def list_images(inp, recursive):
    if os.path.isfile(inp) and inp.lower().endswith((".txt", ".csv")):
        return [l.strip() for l in open(inp) if l.strip() and not l.startswith("#")]
    pat = os.path.join(inp, "**", "*") if recursive else os.path.join(inp, "*")
    return sorted(f for f in glob.glob(pat, recursive=recursive) if f.lower().endswith(EXT))


class Chain:
    def __init__(self, global_model, predictor, dataset_dir):
        cp = W.read_canon_params(dataset_dir)
        self.TL = float(cp["target_len"])
        self.cw = int(round(float(cp["crop_w_factor"]) * self.TL))
        self.ch = int(round(float(cp["crop_h_factor"]) * self.TL))
        if not predictor.lower().endswith(".onnx"):
            sys.exit("Le traitement par lot attend un modèle fin .onnx (mlmorph_run_cnn/model.onnx)")
        self.cnn = W.CNNModel(predictor); self.G = W.GlobalModel(global_model)
        self.ids = W.landmark_ids(self.cnn)
        self.refiners = []

    def load_refiners(self, predictor):
        self.refiners = [W.RefineModel(p) for p in W.find_refiners(predictor)]
        if self.refiners:
            print("2e étage :", ", ".join(R.p["region"] for R in self.refiners), flush=True)

    def fine(self, img, snout, caudal, orient):
        return W.fine_predict(img, snout, caudal, orient, self.cnn, self.TL, self.cw, self.ch)

    def __call__(self, img, n_search):
        """Liste des poissons détectés (au plus n_search), triés du haut vers le bas."""
        if not self.G.has_heat:
            sys.exit("Modèle global sans sortie 'heat' : réexporter (train_global.py --export-only)")
        V = self.G.locate_verified(img, self.fine, max_fish=n_search)
        return V


def draw(img, fishes, flags, path, max_side=900):
    s = min(1.0, max_side / max(img.shape[:2]))
    v = cv2.resize(img, None, fx=s, fy=s, interpolation=cv2.INTER_AREA) if s < 1 else img.copy()
    col = (0, 0, 255) if flags else (0, 200, 0)
    for ind, Q, labs in fishes:
        q = Q * s; pos = {l: q[i] for i, l in enumerate(labs)}
        axis = [pos[l] for l in (1, 22, 24, 2) if l in pos]      # axe brisé si charnières
        for a_, b_ in zip(axis[:-1], axis[1:]):
            cv2.line(v, tuple(np.round(a_).astype(int)), tuple(np.round(b_).astype(int)), (255, 200, 0), 1)
        for l, (x, y) in zip(labs, q):
            if np.isfinite(x):
                c_ = (255, 0, 255) if l in (22, 24) else col
                cv2.circle(v, (int(round(x)), int(round(y))), 3, c_, -1)
                cv2.putText(v, str(l), (int(x) + 4, int(y) - 4), cv2.FONT_HERSHEY_SIMPLEX, 0.35, c_, 1)
        if len(fishes) > 1:
            cv2.putText(v, f"i{ind}", (int(q[0, 0]) - 10, int(q[0, 1]) - 12), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 0, 255), 2)
    if flags:
        cv2.putText(v, " ".join(flags), (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
    cv2.imwrite(path, v, [cv2.IMWRITE_JPEG_QUALITY, 85])


def write_index(out_dir, S):
    S = S.sort_values("risk", ascending=False)
    cards = []
    for r in S.itertuples():
        th = r.qc_name            # index.html est DANS qc/ : chemin relatif à qc/
        cards.append(f'<figure class="{ "bad" if r.flags else "ok"}"><a href="{html.escape(th)}" target="_blank">'
                     f'<img loading="lazy" src="{html.escape(th)}"></a><figcaption><b>{html.escape(str(r.photo_name))}</b>'
                     f'<br>risque {r.risk:.2f} · {html.escape(r.flags or "OK")}</figcaption></figure>')
    n_bad = int((S["flags"] != "").sum())
    page = f"""<!doctype html><meta charset="utf-8"><title>Contrôle du lot</title>
<style>body{{font-family:sans-serif;margin:16px;background:#fafafa}}main{{display:grid;
grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:10px}}figure{{margin:0;background:#fff;
border:2px solid #ccc;padding:4px}}figure.bad{{border-color:#d33}}img{{width:100%}}figcaption{{font-size:12px}}</style>
<h1>Contrôle du lot — {len(S)} photos, {n_bad} signalées</h1>
<p>Triées par risque décroissant. Rouge = à revoir dans l'application ; vert = aucun drapeau.</p>
<main>{''.join(cards)}</main>"""
    open(os.path.join(out_dir, "qc", "index.html"), "w").write(page)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description="Landmarking automatique d'un lot de photos")
    ap.add_argument("--input", required=True, help="dossier de photos, ou fichier .txt (un chemin par ligne)")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--recursive", action="store_true")
    ap.add_argument("--global-model", default=os.path.join(here, "mlmorph_run_global", "model.onnx"))
    ap.add_argument("--predictor", default=os.path.join(here, "mlmorph_run_cnn", "model.onnx"))
    ap.add_argument("--dataset-dir", default=os.path.join(here, "mlmorph_dataset_cnn"))
    ap.add_argument("--qc", action="store_true", help="vignettes annotées + qc/index.html")
    ap.add_argument("--max-fish", type=int, default=1,
                    help="poissons par photo (planches : individus i1..iN numérotés de haut en bas)")
    ap.add_argument("--min-bl-frac", type=float, default=0.15)
    ap.add_argument("--redo", action="store_true")
    ap.add_argument("--no-refine-regions", dest="refine_regions", action="store_false", default=True,
                    help="sans le 2e étage à haute résolution (mlmorph_run_refine_*)")
    ap.add_argument("--hinges", action="store_true",
                    help="écrit aussi les charnières 22/24 prédites (voir predict_new_image.py --hinges)")
    ap.add_argument("--straighten", action="store_true",
                    help="EXPÉRIMENTAL : redressement des poissons courbés (voir predict_new_image.py)")
    a = ap.parse_args()

    imgs = list_images(a.input, a.recursive)
    if not imgs:
        sys.exit(f"Aucune photo trouvée dans {a.input}")
    os.makedirs(a.out_dir, exist_ok=True)
    if a.qc:
        os.makedirs(os.path.join(a.out_dir, "qc"), exist_ok=True)
    fs, fl = os.path.join(a.out_dir, "summary.csv"), os.path.join(a.out_dir, "landmarks_long.csv")
    S0 = pd.read_csv(fs) if os.path.exists(fs) and not a.redo else pd.DataFrame()
    L0 = pd.read_csv(fl) if os.path.exists(fl) and not a.redo else pd.DataFrame()
    done = set(S0.photo) if len(S0) else set()
    todo = [f for f in imgs if os.path.abspath(f) not in done]
    print(f"{len(imgs)} photos, {len(todo)} à traiter", flush=True)
    chain = Chain(a.global_model, a.predictor, a.dataset_dir)
    if a.refine_regions:
        chain.load_refiners(a.predictor)

    rows, lms, t0 = [], [], time.time()
    for k, f in enumerate(todo):
        img = cv2.imread(f, cv2.IMREAD_COLOR | cv2.IMREAD_IGNORE_ORIENTATION)
        if img is None:
            rows.append(dict(photo=os.path.abspath(f), photo_name=os.path.basename(f), individual=1,
                             flags="illisible", risk=9.0))
            continue
        H, Wd = img.shape[:2]
        # on cherche toujours un poisson de plus que demandé : s'il existe, la photo
        # porte plus de poissons qu'annoncé (planche) -> drapeau "plusieurs"
        V = chain(img, a.max_fish + 1)
        extra = len(V) > a.max_fish
        V = sorted(V[:a.max_fish], key=lambda h: float((h["snout"][1] + h["caudal"][1]) / 2))
        if not V:
            rows.append(dict(photo=os.path.abspath(f), photo_name=os.path.basename(f), individual=1,
                             width=Wd, height=H, flags="aucun", risk=9.0))
            continue
        for ind, h in enumerate(V, 1):
            Q, cf = h["P"], h["conf"]
            if chain.refiners:          # 2e étage à haute résolution (tête, pectorale, caudale)
                Q, cf2 = W.fine_predict(img, h["snout"], h["caudal"], h["orient"], chain.cnn, chain.TL,
                                        chain.cw, chain.ch, chain.refiners, keep12=False)
                cf = np.asarray(cf2, float).copy()
            # charnières 22/24 : courbure mesurée ; redressement seulement avec --straighten
            Qc, cc, curv, redressed = W.refine_curved(img, Q.copy(), chain.ids, h["orient"], chain.cnn,
                                                     chain.TL, chain.cw, chain.ch,
                                                     thr=1.5 if a.straighten else float("inf"))
            if redressed:
                Q, cf = Qc, np.asarray(cc, float).copy(); cf[:2] = h["conf"][:2]
            bl = float(np.hypot(*(Q[1] - Q[0])))
            ax = (Q[1] - Q[0]) / max(bl, 1e-6)
            side = lambda p: float(ax[0] * (p - Q[0])[1] - ax[1] * (p - Q[0])[0])
            dorsal_ok = bool(np.sign(side(h["orient"])) == np.sign(side(Q[2])))
            margin = 0.01 * max(H, Wd)
            edge = bool(((Q[:, 0] < margin) | (Q[:, 1] < margin) | (Q[:, 0] > Wd - margin) | (Q[:, 1] > H - margin)).any())
            r = dict(photo=os.path.abspath(f), photo_name=os.path.basename(f), individual=ind, n_found=len(V),
                     width=Wd, height=H, bl_px=round(bl, 1), bl_frac=round(bl / max(H, Wd), 3),
                     score=round(h["score"], 4), dorsal_ok=dorsal_ok, edge=edge, extra_fish=extra,
                     curvature_pct=round(float(curv), 2), straightened=bool(redressed))
            rows.append(r)
            for i in range(len(Q)):
                if chain.ids[i] > 19 and not a.hinges:
                    continue
                lms.append(dict(photo=r["photo"], individual=ind, landmark=chain.ids[i], X=round(float(Q[i, 0]), 2),
                                Y=round(float(Q[i, 1]), 2), conf=round(float(cf[i]), 4)))
        if (k + 1) % 25 == 0 or k + 1 == len(todo):
            el = time.time() - t0
            print(f"  {k + 1}/{len(todo)}  ({el / (k + 1):.2f} s/photo)", flush=True)

    S = pd.concat([S0, pd.DataFrame(rows)], ignore_index=True) if rows else S0
    L = pd.concat([L0, pd.DataFrame(lms)], ignore_index=True) if lms else L0
    # drapeaux sur l'ensemble du lot (le seuil de score est relatif au lot)
    ok = S.get("bl_px", pd.Series(np.nan, index=S.index)).notna()
    q10 = S.loc[ok, "score"].quantile(0.10) if ok.any() else np.nan
    def flags(r):
        if not np.isfinite(r.get("bl_px", np.nan)):
            return r.get("flags") if isinstance(r.get("flags"), str) and r.get("flags") else "illisible"
        f = []
        if bool(r["extra_fish"]): f.append("plusieurs")
        if not bool(r["dorsal_ok"]): f.append("dorsal")
        if r["bl_frac"] < a.min_bl_frac: f.append("petit")
        if bool(r["edge"]): f.append("bord")
        if r["score"] < q10: f.append("confiance")
        return " ".join(f)
    S["flags"] = S.apply(flags, axis=1)
    def risk(r):
        if not np.isfinite(r.get("bl_px", np.nan)):
            return 9.0
        return (3.0 * bool(r["extra_fish"]) + 2.0 * (not bool(r["dorsal_ok"])) + 1.0 * bool(r["edge"])
                + 0.5 * (r["bl_frac"] < a.min_bl_frac) + (q10 / max(r["score"], 1e-6) if np.isfinite(q10) else 0))
    S["risk"] = S.apply(risk, axis=1).round(3)
    S.to_csv(fs, index=False); L.to_csv(fl, index=False)
    if len(L):
        Wide = L.pivot_table(index=["photo", "individual"], columns="landmark", values=["X", "Y"])
        Wide.columns = [f"{c}{l}" for c, l in Wide.columns]
        Wide = Wide[[f"{c}{i}" for i in sorted(L.landmark.unique()) for c in "XY"]].reset_index()
        Wide.to_csv(os.path.join(a.out_dir, "landmarks_wide.csv"), index=False)
    if a.qc:
        S["qc_name"] = [os.path.splitext(n)[0] + ".jpg" for n in S.photo_name]
        new = {x["photo"] for x in rows}
        for ph, g in S.groupby("photo"):
            out = os.path.join(a.out_dir, "qc", g.qc_name.iloc[0])
            if (ph in new or not os.path.exists(out)) and g.bl_px.notna().any():
                img = cv2.imread(ph, cv2.IMREAD_COLOR | cv2.IMREAD_IGNORE_ORIENTATION)
                Lp = L[L.photo == ph]
                fishes = [(i, d.sort_values("landmark")[["X", "Y"]].to_numpy(float), list(d.sort_values("landmark").landmark))
                          for i, d in Lp.groupby("individual")]
                fl = sorted({x for v in g["flags"] if isinstance(v, str) for x in v.split()})
                draw(img, fishes, fl, out)
        Sq = S.sort_values("risk", ascending=False).drop_duplicates("photo")
        write_index(a.out_dir, Sq)
    n_bad = int((S["flags"].fillna("") != "").sum())
    print(f"OK : {S.photo.nunique()} photos, {len(S)} poisson(s), {n_bad} signalé(s) -> {os.path.abspath(a.out_dir)}")


if __name__ == "__main__":
    main()
