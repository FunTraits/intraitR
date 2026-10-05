#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
predict_new_image.py

Landmarking automatique d'UNE nouvelle photo à partir de 4 clics utilisateur :
  - museau (LM1) et base de caudale (LM2)  -> orientation + longueur de corps
  - 2 points d'échelle sur la règle        -> calibration px->mm (optionnel)

Pipeline : canonicalise l'image (rotation tête-à-gauche + mise à l'échelle à une
longueur de corps commune + recadrage) exactement comme à l'entraînement, applique
le prédicteur de forme ml-morph (dlib) pour placer les 19 landmarks anatomiques,
puis inverse la transformation pour ramener les points en coordonnées image
d'origine. Les points d'échelle 20-21 sont repris des clics utilisateur.

Un affinage optionnel (--refine) recadre une 2e fois centré sur le barycentre
des 19 points prédits (comme à l'entraînement) pour améliorer le cadrage.

Sortie : CSV (landmark, X, Y) en coordonnées image d'origine (haut-gauche).

Usage :
  python3 predict_new_image.py --image photo.jpeg \
      --snout 2450,1980 --caudal 3480,1960 \
      --scale1 3719,2079 --scale2 3869,2075 --scale-mm 10 \
      --dataset-dir mlmorph_dataset_aligned \
      --predictor mlmorph_run_aligned/predictor.dat \
      --out out.csv
"""
import argparse
import csv
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import cv2
    import dlib
    import build_mlmorph_xml as bx     # compute_fixed_dims, load_heights, parse_tps
except ImportError as e:
    sys.exit(f"Dépendance manquante ({e}). Activez le venv .venv_mlmorph.")


def parse_xy(s):
    a, b = s.split(",")
    return np.array([float(a), float(b)])


def affine(center, angle, scale, cw, ch):
    """Matrice affine original->canonicalisé, centrée sur `center`."""
    M = cv2.getRotationMatrix2D((float(center[0]), float(center[1])), angle, scale)
    M[0, 2] += cw / 2.0 - center[0]
    M[1, 2] += ch / 2.0 - center[1]
    return M


def orient_dorsal_up(M, dorsal, ch):
    """Si le point dorsal se retrouve SOUS l'axe (poisson ventre en l'air), ajoute
    un retournement vertical à M pour garantir dos-en-haut dans le repère canonique."""
    if dorsal is None:
        return M
    dy = M[1, 0] * dorsal[0] + M[1, 1] * dorsal[1] + M[1, 2]
    if dy > ch / 2.0:                      # dorsal en bas -> flip vertical (y -> ch - y)
        M = M.copy()
        M[1, :] = [-M[1, 0], -M[1, 1], ch - M[1, 2]]
    return M


def fixed_box_dims(dataset_dir, pad=0.15):
    """Reproduit la box fixe d'entraînement (compute_fixed_dims sur le jeu aligné)."""
    specs = []
    for b in ("train", "val", "test"):
        p = os.path.join(dataset_dir, f"{b}.tps")
        if os.path.exists(p):
            specs += bx.parse_tps(p)
    heights = bx.load_heights(os.path.join(dataset_dir, "split_assignments.csv"))
    (W, H), _, _ = bx.compute_fixed_dims(specs, heights, pad)
    return W, H


def predict_config(predictor, img_canon, box_w, box_h, cw, ch):
    """Prédit les N landmarks dans l'image canonicalisée (box fixe centrée)."""
    left = int(round(cw / 2 - box_w / 2)); top = int(round(ch / 2 - box_h / 2))
    rect = dlib.rectangle(left, top, left + int(box_w), top + int(box_h))
    rgb = cv2.cvtColor(img_canon, cv2.COLOR_BGR2RGB)
    shape = predictor(rgb, rect)
    return np.array([[shape.part(i).x, shape.part(i).y]
                     for i in range(shape.num_parts)], dtype=float)


def main():
    ap = argparse.ArgumentParser(description="Landmarking auto d'une nouvelle photo")
    ap.add_argument("--image", required=True)
    ap.add_argument("--snout", required=True, help="x,y du museau (LM1)")
    ap.add_argument("--caudal", required=True, help="x,y de la base de caudale (LM2)")
    ap.add_argument("--dorsal", default="", help="x,y d'un point DORSAL (haut du corps) "
                    "-> oriente dos-en-haut automatiquement ; SERT AUSSI de LM3 épinglé "
                    "quand --pin-clicks est actif")
    ap.add_argument("--lm4", default="", help="x,y de LM4 (ventral, à l'aplomb de LM3) "
                    "-> épinglé sur le clic quand --pin-clicks est actif")
    ap.add_argument("--lm7", default="", help="x,y de LM7 (référence tête : verticale œil) "
                    "-> épinglé sur le clic quand --pin-clicks est actif")
    for k in ("lm10", "lm12", "lm15", "lm16", "lm18"):
        ap.add_argument(f"--{k}", default="",
                        help=f"x,y de {k.upper()} -> épinglé sur le clic quand --pin-clicks")
    ap.add_argument("--scale1", default="", help="x,y point d'échelle 20")
    ap.add_argument("--scale2", default="", help="x,y point d'échelle 21")
    ap.add_argument("--scale-mm", type=float, default=0)
    ap.add_argument("--dataset-dir", default="mlmorph_dataset_aligned")
    ap.add_argument("--predictor", default="mlmorph_run_aligned/predictor.dat")
    ap.add_argument("--target-len", type=float, default=750)
    ap.add_argument("--crop-w-factor", type=float, default=2.6)
    ap.add_argument("--crop-h-factor", type=float, default=1.7)
    ap.add_argument("--refine", action="store_true", default=True)
    ap.add_argument("--no-refine", dest="refine", action="store_false")
    ap.add_argument("--pin-clicks", action="store_true", default=True,
                    help="épingle LM1=museau et LM2=caudale sur les clics utilisateur "
                         "(placés précisément) ; le modèle ne prédit que les autres")
    ap.add_argument("--no-pin-clicks", dest="pin_clicks", action="store_false")
    ap.add_argument("--out", default="prediction.csv")
    args = ap.parse_args()

    snout = parse_xy(args.snout); caudal = parse_xy(args.caudal)
    dorsal = parse_xy(args.dorsal) if args.dorsal else None
    lm4 = parse_xy(args.lm4) if args.lm4 else None
    lm7 = parse_xy(args.lm7) if args.lm7 else None
    # LM10, LM12, LM15, LM16, LM18 : indices 0-based 9, 11, 14, 15, 17
    extra_pins = {9: args.lm10, 11: args.lm12, 14: args.lm15, 15: args.lm16, 17: args.lm18}
    extra_pins = {i: parse_xy(s) for i, s in extra_pins.items() if s}
    img = cv2.imread(args.image)
    if img is None:
        sys.exit(f"Image illisible : {args.image}")

    dx, dy = caudal - snout
    angle = math.degrees(math.atan2(dy, dx))          # signe validé
    body = math.hypot(dx, dy)
    scale = args.target_len / body if body > 0 else 1.0
    cw = int(round(args.crop_w_factor * args.target_len))
    ch = int(round(args.crop_h_factor * args.target_len))
    box_w, box_h = fixed_box_dims(args.dataset_dir)
    predictor = dlib.shape_predictor(args.predictor)

    # Passe 1 : centre = milieu museau-caudale (seule info disponible a priori)
    center = (snout + caudal) / 2.0
    M = orient_dorsal_up(affine(center, angle, scale, cw, ch), dorsal, ch)
    img_c = cv2.warpAffine(img, M, (cw, ch), flags=cv2.INTER_CUBIC)
    P_canon = predict_config(predictor, img_c, box_w, box_h, cw, ch)

    # Passe 2 (refine) : recentrer sur le barycentre des 19 points prédits
    if args.refine:
        Minv = cv2.invertAffineTransform(M)
        centroid_canon = P_canon.mean(axis=0)
        center = Minv[:, :2] @ centroid_canon + Minv[:, 2]   # -> coords d'origine
        M = orient_dorsal_up(affine(center, angle, scale, cw, ch), dorsal, ch)
        img_c = cv2.warpAffine(img, M, (cw, ch), flags=cv2.INTER_CUBIC)
        P_canon = predict_config(predictor, img_c, box_w, box_h, cw, ch)

    # Inverse -> coordonnées image d'origine
    Minv = cv2.invertAffineTransform(M)
    P_orig = (Minv[:, :2] @ P_canon.T).T + Minv[:, 2]

    # Épinglage : les points placés à la main écrasent la prédiction du modèle.
    # LM1 = museau, LM2 = caudale (toujours) ; LM3 = dorsal, LM4, LM7 si fournis.
    # (La propagation FISHMORPH vers les points dépendants 8/9/11, 5/6/13/14 est
    #  faite côté R par apply_fishmorph() après lecture de ce CSV.)
    if args.pin_clicks and P_orig.shape[0] >= 2:
        P_orig[0] = snout
        P_orig[1] = caudal
        if dorsal is not None and P_orig.shape[0] >= 3:
            P_orig[2] = dorsal          # LM3 (= clic dorsal, aussi utilisé pour l'orientation)
        if lm4 is not None and P_orig.shape[0] >= 4:
            P_orig[3] = lm4             # LM4 (ventral, à l'aplomb de LM3)
        if lm7 is not None and P_orig.shape[0] >= 7:
            P_orig[6] = lm7             # LM7 (référence tête)
        for idx, xy in extra_pins.items():   # LM10, LM12, LM16, LM18
            if P_orig.shape[0] > idx:
                P_orig[idx] = xy

    rows = [{"landmark": i + 1, "X": round(P_orig[i, 0], 3), "Y": round(P_orig[i, 1], 3)}
            for i in range(P_orig.shape[0])]
    # Points d'échelle 20-21 depuis les clics
    n = P_orig.shape[0]
    for k, s in enumerate([args.scale1, args.scale2]):
        if s:
            p = parse_xy(s)
            rows.append({"landmark": n + 1 + k, "X": round(p[0], 3), "Y": round(p[1], 3)})

    with open(args.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["landmark", "X", "Y"])
        w.writeheader(); w.writerows(rows)

    scale_mm_per_px = ""
    if args.scale1 and args.scale2 and args.scale_mm > 0:
        d = np.hypot(*(parse_xy(args.scale2) - parse_xy(args.scale1)))
        scale_mm_per_px = args.scale_mm / d if d > 0 else ""
    print(f"OK: {len(rows)} landmarks -> {os.path.abspath(args.out)}"
          + (f" | mm/px={scale_mm_per_px:.5f}" if scale_mm_per_px else ""))


if __name__ == "__main__":
    main()
