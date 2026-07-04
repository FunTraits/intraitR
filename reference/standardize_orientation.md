# Standardize every specimen to the same head-left, belly-down orientation

Digitization sources vary in how a picture happens to be oriented (fish
facing left or right, right-side up or upside down), and in whether Y
increases upward (standard Cartesian convention) or downward
(image/pixel convention). Rather than a per-plot display toggle (as an
earlier version of
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)'s
`flip_y_points` argument offered), `standardize_orientation()` checks
and, if needed, mirrors *every specimen*'s actual coordinates using two
pairs of landmarks that are present, and anatomically the same two
points, in every FISHMORPH digitization: the snout tip and caudal fin
base (1, 2) fix the left-right orientation, and the top/bottom of the
body at its deepest point (3, 4) fix the dorsal-ventral orientation.

## Usage

``` r
standardize_orientation(landmarks, specimen = NULL)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"`, or a raw `p x k x n`
  landmark array, with at least landmarks 1-4 digitized following the
  scheme described in
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md).

- specimen:

  `NULL` (default) to check/correct every specimen, or an
  integer/character vector to restrict this to a subset.

## Value

An object of the same class as `landmarks`, with any specimen not
already in the target orientation mirrored (horizontally, vertically, or
both) so that, afterwards, every specimen has the snout (1) to the left
of the caudal fin base (2), and the bottom of the body (4) below its top
(3). The returned `coords` array carries an `orientation_log` attribute,
a `data.frame` with one row per specimen checked and columns `specimen`,
`flipped_x`, `flipped_y` (logical), for transparency.

## Details

A mirror is a reflection about the midpoint of that specimen's own
coordinate range on the relevant axis (the same operation the old
`flip_y_points` display toggle used), so the corrected specimen stays in
roughly the same coordinate region rather than jumping to a different
part of the plane. Because
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
and
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
are computed from Euclidean distances between landmarks, mirroring never
changes their values – but it does matter for any geometric-morphometric
analysis of *shape* (e.g.
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
on GPA-derived coordinates, or any PCA of landmark configurations),
where an inconsistently mirrored subset of specimens would otherwise be
treated as genuinely different in shape from the rest, purely as an
artifact of how each picture happened to be taken. Apply this function
to the raw digitized landmarks *before* such analyses (a warning is
issued if `landmarks` is already an `"intrait_gpa"` object, since
Procrustes alignment does not preserve absolute orientation the same
way).

If a specimen is missing landmark 1, 2, 3, or 4, the corresponding check
(left-right or dorsal-ventral) is skipped for it (with a warning),
rather than guessed at or treated as an error.

## See also

[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md),
[`correct_landmarks()`](https://funtraits.github.io/intraitR/reference/correct_landmarks.md),
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)

## Examples

``` r
fish <- load_t26_saudrune_landmarks()
fish_oriented <- standardize_orientation(fish)
#> standardize_orientation(): 557 of 558 specimen(s) mirrored (165 horizontally, 555 vertically) to a consistent head-left, belly-down orientation.
attr(fish_oriented$coords, "orientation_log")
#>                   specimen flipped_x flipped_y
#> 1     T-26-0001_Operator_1     FALSE      TRUE
#> 2     T-26-0001_Operator_2     FALSE      TRUE
#> 3     T-26-0002_Operator_1     FALSE      TRUE
#> 4     T-26-0002_Operator_2     FALSE      TRUE
#> 5     T-26-0003_Operator_1     FALSE      TRUE
#> 6     T-26-0003_Operator_2     FALSE      TRUE
#> 7     T-26-0004_Operator_1     FALSE      TRUE
#> 8     T-26-0004_Operator_2     FALSE      TRUE
#> 9     T-26-0005_Operator_1     FALSE      TRUE
#> 10    T-26-0005_Operator_2     FALSE      TRUE
#> 11    T-26-0006_Operator_1     FALSE      TRUE
#> 12    T-26-0006_Operator_2     FALSE      TRUE
#> 13    T-26-0007_Operator_1     FALSE      TRUE
#> 14    T-26-0007_Operator_2     FALSE      TRUE
#> 15    T-26-0008_Operator_1     FALSE      TRUE
#> 16    T-26-0008_Operator_2     FALSE      TRUE
#> 17    T-26-0009_Operator_1     FALSE      TRUE
#> 18    T-26-0009_Operator_2     FALSE      TRUE
#> 19    T-26-0010_Operator_1     FALSE      TRUE
#> 20    T-26-0010_Operator_2     FALSE      TRUE
#> 21    T-26-0011_Operator_1      TRUE      TRUE
#> 22    T-26-0011_Operator_2      TRUE      TRUE
#> 23    T-26-0012_Operator_1     FALSE      TRUE
#> 24    T-26-0012_Operator_2     FALSE      TRUE
#> 25    T-26-0013_Operator_1     FALSE      TRUE
#> 26    T-26-0013_Operator_2     FALSE      TRUE
#> 27    T-26-0014_Operator_1     FALSE      TRUE
#> 28    T-26-0014_Operator_2     FALSE      TRUE
#> 29    T-26-0015_Operator_1     FALSE      TRUE
#> 30    T-26-0015_Operator_2     FALSE      TRUE
#> 31    T-26-0016_Operator_1     FALSE      TRUE
#> 32    T-26-0016_Operator_2     FALSE      TRUE
#> 33    T-26-0017_Operator_1     FALSE      TRUE
#> 34    T-26-0017_Operator_2     FALSE      TRUE
#> 35    T-26-0018_Operator_1     FALSE      TRUE
#> 36    T-26-0018_Operator_2     FALSE      TRUE
#> 37    T-26-0019_Operator_1     FALSE      TRUE
#> 38    T-26-0019_Operator_2     FALSE      TRUE
#> 39    T-26-0020_Operator_1     FALSE      TRUE
#> 40    T-26-0020_Operator_2     FALSE      TRUE
#> 41    T-26-0021_Operator_1     FALSE      TRUE
#> 42    T-26-0021_Operator_2     FALSE      TRUE
#> 43    T-26-0022_Operator_1     FALSE      TRUE
#> 44    T-26-0022_Operator_2     FALSE      TRUE
#> 45  T-26-0023-2_Operator_1     FALSE      TRUE
#> 46  T-26-0023-2_Operator_2     FALSE      TRUE
#> 47    T-26-0024_Operator_1     FALSE      TRUE
#> 48    T-26-0024_Operator_2     FALSE      TRUE
#> 49    T-26-0025_Operator_1     FALSE      TRUE
#> 50    T-26-0025_Operator_2     FALSE      TRUE
#> 51    T-26-0026_Operator_1     FALSE      TRUE
#> 52    T-26-0026_Operator_2     FALSE      TRUE
#> 53    T-26-0027_Operator_1     FALSE      TRUE
#> 54    T-26-0027_Operator_2     FALSE      TRUE
#> 55    T-26-0028_Operator_1     FALSE      TRUE
#> 56    T-26-0028_Operator_2     FALSE      TRUE
#> 57    T-26-0029_Operator_1     FALSE      TRUE
#> 58    T-26-0029_Operator_2     FALSE      TRUE
#> 59    T-26-0030_Operator_1     FALSE      TRUE
#> 60    T-26-0030_Operator_2     FALSE      TRUE
#> 61    T-26-0031_Operator_1     FALSE      TRUE
#> 62    T-26-0031_Operator_2     FALSE      TRUE
#> 63    T-26-0032_Operator_1     FALSE      TRUE
#> 64    T-26-0032_Operator_2     FALSE      TRUE
#> 65    T-26-0033_Operator_1     FALSE      TRUE
#> 66    T-26-0033_Operator_2     FALSE      TRUE
#> 67    T-26-0034_Operator_1     FALSE      TRUE
#> 68    T-26-0034_Operator_2     FALSE      TRUE
#> 69    T-26-0035_Operator_1     FALSE      TRUE
#> 70    T-26-0035_Operator_2     FALSE      TRUE
#> 71    T-26-0036_Operator_1     FALSE      TRUE
#> 72    T-26-0036_Operator_2     FALSE      TRUE
#> 73    T-26-0037_Operator_1     FALSE      TRUE
#> 74    T-26-0037_Operator_2     FALSE      TRUE
#> 75    T-26-0038_Operator_1     FALSE      TRUE
#> 76    T-26-0038_Operator_2     FALSE      TRUE
#> 77    T-26-0039_Operator_1     FALSE      TRUE
#> 78    T-26-0039_Operator_2     FALSE      TRUE
#> 79    T-26-0040_Operator_1     FALSE      TRUE
#> 80    T-26-0040_Operator_2     FALSE      TRUE
#> 81    T-26-0041_Operator_1     FALSE      TRUE
#> 82    T-26-0041_Operator_2     FALSE      TRUE
#> 83    T-26-0042_Operator_1     FALSE      TRUE
#> 84    T-26-0042_Operator_2     FALSE      TRUE
#> 85    T-26-0043_Operator_1     FALSE      TRUE
#> 86    T-26-0043_Operator_2     FALSE      TRUE
#> 87    T-26-0044_Operator_1     FALSE      TRUE
#> 88    T-26-0044_Operator_2     FALSE      TRUE
#> 89    T-26-0045_Operator_1     FALSE      TRUE
#> 90    T-26-0045_Operator_2     FALSE      TRUE
#> 91    T-26-0046_Operator_1     FALSE      TRUE
#> 92    T-26-0046_Operator_2     FALSE      TRUE
#> 93    T-26-0047_Operator_1     FALSE      TRUE
#> 94    T-26-0047_Operator_2     FALSE      TRUE
#> 95    T-26-0048_Operator_1     FALSE      TRUE
#> 96    T-26-0048_Operator_2     FALSE      TRUE
#> 97    T-26-0049_Operator_1     FALSE      TRUE
#> 98    T-26-0049_Operator_2     FALSE      TRUE
#> 99    T-26-0050_Operator_1     FALSE      TRUE
#> 100   T-26-0050_Operator_2     FALSE      TRUE
#> 101   T-26-0051_Operator_1     FALSE      TRUE
#> 102   T-26-0051_Operator_2     FALSE      TRUE
#> 103   T-26-0052_Operator_1     FALSE     FALSE
#> 104   T-26-0052_Operator_2     FALSE      TRUE
#> 105   T-26-0053_Operator_1     FALSE      TRUE
#> 106   T-26-0053_Operator_2     FALSE      TRUE
#> 107   T-26-0054_Operator_1     FALSE      TRUE
#> 108   T-26-0054_Operator_2     FALSE      TRUE
#> 109   T-26-0055_Operator_1     FALSE      TRUE
#> 110   T-26-0055_Operator_2     FALSE      TRUE
#> 111 T-26-0056-2_Operator_1     FALSE      TRUE
#> 112 T-26-0056-2_Operator_2     FALSE      TRUE
#> 113   T-26-0057_Operator_1     FALSE      TRUE
#> 114   T-26-0057_Operator_2     FALSE      TRUE
#> 115   T-26-0058_Operator_1     FALSE      TRUE
#> 116   T-26-0058_Operator_2     FALSE      TRUE
#> 117   T-26-0059_Operator_1     FALSE      TRUE
#> 118   T-26-0059_Operator_2     FALSE      TRUE
#> 119   T-26-0060_Operator_1     FALSE      TRUE
#> 120   T-26-0060_Operator_2     FALSE      TRUE
#> 121   T-26-0061_Operator_1     FALSE      TRUE
#> 122   T-26-0061_Operator_2     FALSE      TRUE
#> 123   T-26-0062_Operator_1     FALSE      TRUE
#> 124   T-26-0062_Operator_2     FALSE      TRUE
#> 125   T-26-0063_Operator_1     FALSE      TRUE
#> 126   T-26-0063_Operator_2     FALSE      TRUE
#> 127   T-26-0064_Operator_1     FALSE      TRUE
#> 128   T-26-0064_Operator_2     FALSE      TRUE
#> 129   T-26-0065_Operator_1     FALSE      TRUE
#> 130   T-26-0065_Operator_2     FALSE      TRUE
#> 131   T-26-0067_Operator_1      TRUE      TRUE
#> 132   T-26-0067_Operator_2      TRUE      TRUE
#> 133   T-26-0068_Operator_1      TRUE      TRUE
#> 134   T-26-0068_Operator_2      TRUE      TRUE
#> 135   T-26-0069_Operator_1     FALSE      TRUE
#> 136   T-26-0069_Operator_2     FALSE      TRUE
#> 137   T-26-0070_Operator_1      TRUE      TRUE
#> 138   T-26-0070_Operator_2      TRUE      TRUE
#> 139   T-26-0071_Operator_1      TRUE      TRUE
#> 140   T-26-0071_Operator_2      TRUE      TRUE
#> 141   T-26-0072_Operator_1      TRUE      TRUE
#> 142   T-26-0072_Operator_2      TRUE      TRUE
#> 143   T-26-0073_Operator_1      TRUE      TRUE
#> 144   T-26-0073_Operator_2      TRUE      TRUE
#> 145   T-26-0074_Operator_1      TRUE      TRUE
#> 146   T-26-0074_Operator_2      TRUE      TRUE
#> 147   T-26-0075_Operator_1      TRUE      TRUE
#> 148   T-26-0075_Operator_2      TRUE      TRUE
#> 149   T-26-0076_Operator_1      TRUE      TRUE
#> 150   T-26-0076_Operator_2      TRUE      TRUE
#> 151   T-26-0077_Operator_1      TRUE      TRUE
#> 152   T-26-0077_Operator_2      TRUE      TRUE
#> 153   T-26-0078_Operator_1      TRUE      TRUE
#> 154   T-26-0078_Operator_2      TRUE      TRUE
#> 155   T-26-0079_Operator_1      TRUE      TRUE
#> 156   T-26-0079_Operator_2      TRUE      TRUE
#> 157   T-26-0080_Operator_1      TRUE      TRUE
#> 158   T-26-0080_Operator_2      TRUE      TRUE
#> 159   T-26-0081_Operator_1      TRUE      TRUE
#> 160   T-26-0081_Operator_2      TRUE      TRUE
#> 161   T-26-0082_Operator_1      TRUE      TRUE
#> 162   T-26-0082_Operator_2      TRUE      TRUE
#> 163   T-26-0083_Operator_1      TRUE      TRUE
#> 164   T-26-0083_Operator_2      TRUE      TRUE
#> 165   T-26-0084_Operator_1      TRUE      TRUE
#> 166   T-26-0084_Operator_2      TRUE      TRUE
#> 167   T-26-0085_Operator_1      TRUE      TRUE
#> 168   T-26-0085_Operator_2      TRUE      TRUE
#> 169   T-26-0086_Operator_1      TRUE      TRUE
#> 170   T-26-0086_Operator_2      TRUE      TRUE
#> 171   T-26-0087_Operator_1     FALSE      TRUE
#> 172   T-26-0087_Operator_2     FALSE      TRUE
#> 173   T-26-0088_Operator_1      TRUE      TRUE
#> 174   T-26-0088_Operator_2      TRUE      TRUE
#> 175   T-26-0089_Operator_1     FALSE      TRUE
#> 176   T-26-0089_Operator_2     FALSE      TRUE
#> 177   T-26-0090_Operator_1      TRUE      TRUE
#> 178   T-26-0090_Operator_2      TRUE      TRUE
#> 179   T-26-0091_Operator_1      TRUE      TRUE
#> 180   T-26-0091_Operator_2      TRUE      TRUE
#> 181   T-26-0092_Operator_1      TRUE      TRUE
#> 182   T-26-0092_Operator_2      TRUE      TRUE
#> 183   T-26-0093_Operator_1      TRUE      TRUE
#> 184   T-26-0093_Operator_2      TRUE      TRUE
#> 185   T-26-0094_Operator_1      TRUE      TRUE
#> 186   T-26-0094_Operator_2      TRUE      TRUE
#> 187   T-26-0095_Operator_1      TRUE      TRUE
#> 188   T-26-0095_Operator_2      TRUE      TRUE
#> 189   T-26-0096_Operator_1      TRUE      TRUE
#> 190   T-26-0096_Operator_2      TRUE      TRUE
#> 191   T-26-0097_Operator_1      TRUE      TRUE
#> 192   T-26-0097_Operator_2      TRUE      TRUE
#> 193   T-26-0098_Operator_1      TRUE      TRUE
#> 194   T-26-0098_Operator_2      TRUE      TRUE
#> 195   T-26-0099_Operator_1      TRUE      TRUE
#> 196   T-26-0099_Operator_2      TRUE      TRUE
#> 197   T-26-0100_Operator_1      TRUE      TRUE
#> 198   T-26-0100_Operator_2      TRUE      TRUE
#> 199   T-26-0101_Operator_1      TRUE      TRUE
#> 200   T-26-0101_Operator_2      TRUE      TRUE
#> 201   T-26-0102_Operator_1      TRUE      TRUE
#> 202   T-26-0102_Operator_2      TRUE      TRUE
#> 203   T-26-0103_Operator_1      TRUE      TRUE
#> 204   T-26-0103_Operator_2      TRUE      TRUE
#> 205   T-26-0104_Operator_1      TRUE      TRUE
#> 206   T-26-0104_Operator_2      TRUE      TRUE
#> 207   T-26-0107_Operator_1      TRUE      TRUE
#> 208   T-26-0107_Operator_2      TRUE      TRUE
#> 209   T-26-0108_Operator_1      TRUE      TRUE
#> 210   T-26-0108_Operator_2      TRUE      TRUE
#> 211   T-26-0109_Operator_1      TRUE      TRUE
#> 212   T-26-0109_Operator_2      TRUE      TRUE
#> 213   T-26-0111_Operator_1      TRUE      TRUE
#> 214   T-26-0111_Operator_2      TRUE      TRUE
#> 215 T-26-0112-2_Operator_1      TRUE      TRUE
#> 216 T-26-0112-2_Operator_2      TRUE      TRUE
#> 217   T-26-0112_Operator_1     FALSE      TRUE
#> 218   T-26-0112_Operator_2     FALSE      TRUE
#> 219   T-26-0113_Operator_1      TRUE      TRUE
#> 220   T-26-0113_Operator_2      TRUE      TRUE
#> 221   T-26-0114_Operator_1      TRUE      TRUE
#> 222   T-26-0114_Operator_2      TRUE      TRUE
#> 223   T-26-0115_Operator_1      TRUE      TRUE
#> 224   T-26-0115_Operator_2      TRUE      TRUE
#> 225   T-26-0116_Operator_1      TRUE      TRUE
#> 226   T-26-0116_Operator_2      TRUE      TRUE
#> 227   T-26-0117_Operator_1      TRUE      TRUE
#> 228   T-26-0117_Operator_2      TRUE      TRUE
#> 229   T-26-0118_Operator_1      TRUE      TRUE
#> 230   T-26-0118_Operator_2      TRUE      TRUE
#> 231   T-26-0120_Operator_1      TRUE      TRUE
#> 232   T-26-0120_Operator_2      TRUE      TRUE
#> 233   T-26-0121_Operator_1      TRUE      TRUE
#> 234   T-26-0121_Operator_2     FALSE      TRUE
#> 235   T-26-0122_Operator_1      TRUE      TRUE
#> 236   T-26-0122_Operator_2      TRUE      TRUE
#> 237   T-26-0123_Operator_1      TRUE      TRUE
#> 238   T-26-0123_Operator_2      TRUE      TRUE
#> 239   T-26-0125_Operator_1      TRUE      TRUE
#> 240   T-26-0125_Operator_2      TRUE      TRUE
#> 241   T-26-0126_Operator_1      TRUE      TRUE
#> 242   T-26-0126_Operator_2      TRUE      TRUE
#> 243   T-26-0127_Operator_1      TRUE      TRUE
#> 244   T-26-0127_Operator_2      TRUE      TRUE
#> 245   T-26-0128_Operator_1      TRUE      TRUE
#> 246   T-26-0128_Operator_2      TRUE      TRUE
#> 247   T-26-0130_Operator_1      TRUE      TRUE
#> 248   T-26-0130_Operator_2      TRUE      TRUE
#> 249   T-26-0131_Operator_1     FALSE      TRUE
#> 250   T-26-0131_Operator_2     FALSE      TRUE
#> 251   T-26-0132_Operator_1     FALSE      TRUE
#> 252   T-26-0132_Operator_2     FALSE      TRUE
#> 253   T-26-0133_Operator_1     FALSE      TRUE
#> 254   T-26-0133_Operator_2     FALSE      TRUE
#> 255   T-26-0134_Operator_1     FALSE      TRUE
#> 256   T-26-0134_Operator_2     FALSE      TRUE
#> 257   T-26-0135_Operator_1     FALSE      TRUE
#> 258   T-26-0135_Operator_2     FALSE      TRUE
#> 259   T-26-0136_Operator_1     FALSE      TRUE
#> 260   T-26-0136_Operator_2     FALSE      TRUE
#> 261   T-26-0137_Operator_1     FALSE      TRUE
#> 262   T-26-0137_Operator_2     FALSE      TRUE
#> 263   T-26-0138_Operator_1     FALSE      TRUE
#> 264   T-26-0138_Operator_2     FALSE      TRUE
#> 265   T-26-0139_Operator_1     FALSE      TRUE
#> 266   T-26-0139_Operator_2     FALSE      TRUE
#> 267   T-26-0140_Operator_1     FALSE      TRUE
#> 268   T-26-0140_Operator_2     FALSE      TRUE
#> 269   T-26-0141_Operator_1     FALSE      TRUE
#> 270   T-26-0141_Operator_2     FALSE      TRUE
#> 271   T-26-0142_Operator_1     FALSE      TRUE
#> 272   T-26-0142_Operator_2     FALSE      TRUE
#> 273   T-26-0143_Operator_1     FALSE      TRUE
#> 274   T-26-0143_Operator_2     FALSE      TRUE
#> 275   T-26-0144_Operator_1     FALSE      TRUE
#> 276   T-26-0144_Operator_2     FALSE      TRUE
#> 277   T-26-0145_Operator_1     FALSE      TRUE
#> 278   T-26-0145_Operator_2     FALSE      TRUE
#> 279   T-26-0146_Operator_1     FALSE      TRUE
#> 280   T-26-0146_Operator_2     FALSE      TRUE
#> 281   T-26-0147_Operator_1     FALSE      TRUE
#> 282   T-26-0147_Operator_2     FALSE      TRUE
#> 283   T-26-0148_Operator_1     FALSE      TRUE
#> 284   T-26-0148_Operator_2     FALSE      TRUE
#> 285   T-26-0149_Operator_1     FALSE      TRUE
#> 286   T-26-0149_Operator_2     FALSE      TRUE
#> 287   T-26-0150_Operator_1     FALSE      TRUE
#> 288   T-26-0150_Operator_2     FALSE      TRUE
#> 289   T-26-0151_Operator_1     FALSE      TRUE
#> 290   T-26-0151_Operator_2     FALSE      TRUE
#> 291   T-26-0152_Operator_1     FALSE      TRUE
#> 292   T-26-0152_Operator_2     FALSE      TRUE
#> 293   T-26-0153_Operator_1     FALSE      TRUE
#> 294   T-26-0153_Operator_2     FALSE      TRUE
#> 295   T-26-0154_Operator_1     FALSE      TRUE
#> 296   T-26-0154_Operator_2     FALSE      TRUE
#> 297   T-26-0155_Operator_1     FALSE      TRUE
#> 298   T-26-0155_Operator_2     FALSE      TRUE
#> 299   T-26-0156_Operator_1     FALSE      TRUE
#> 300   T-26-0156_Operator_2     FALSE      TRUE
#> 301   T-26-0157_Operator_1     FALSE      TRUE
#> 302   T-26-0157_Operator_2     FALSE      TRUE
#> 303   T-26-0158_Operator_1     FALSE      TRUE
#> 304   T-26-0158_Operator_2     FALSE      TRUE
#> 305   T-26-0159_Operator_1     FALSE      TRUE
#> 306   T-26-0159_Operator_2     FALSE      TRUE
#> 307   T-26-0160_Operator_1     FALSE      TRUE
#> 308   T-26-0160_Operator_2     FALSE      TRUE
#> 309   T-26-0161_Operator_1     FALSE      TRUE
#> 310   T-26-0161_Operator_2     FALSE      TRUE
#> 311   T-26-0162_Operator_1     FALSE      TRUE
#> 312   T-26-0162_Operator_2     FALSE      TRUE
#> 313   T-26-0163_Operator_1     FALSE      TRUE
#> 314   T-26-0163_Operator_2     FALSE      TRUE
#> 315   T-26-0164_Operator_1     FALSE      TRUE
#> 316   T-26-0164_Operator_2     FALSE      TRUE
#> 317   T-26-0165_Operator_1     FALSE      TRUE
#> 318   T-26-0165_Operator_2     FALSE      TRUE
#> 319   T-26-0166_Operator_1     FALSE      TRUE
#> 320   T-26-0166_Operator_2     FALSE      TRUE
#> 321   T-26-0167_Operator_1     FALSE      TRUE
#> 322   T-26-0167_Operator_2     FALSE      TRUE
#> 323   T-26-0168_Operator_1     FALSE      TRUE
#> 324   T-26-0168_Operator_2     FALSE      TRUE
#> 325   T-26-0169_Operator_1     FALSE      TRUE
#> 326   T-26-0169_Operator_2     FALSE      TRUE
#> 327   T-26-0170_Operator_1     FALSE      TRUE
#> 328   T-26-0170_Operator_2     FALSE      TRUE
#> 329   T-26-0171_Operator_1     FALSE      TRUE
#> 330   T-26-0171_Operator_2     FALSE      TRUE
#> 331   T-26-0172_Operator_1     FALSE      TRUE
#> 332   T-26-0172_Operator_2     FALSE      TRUE
#> 333   T-26-0173_Operator_1     FALSE      TRUE
#> 334   T-26-0173_Operator_2     FALSE      TRUE
#> 335   T-26-0174_Operator_1     FALSE      TRUE
#> 336   T-26-0174_Operator_2     FALSE      TRUE
#> 337   T-26-0175_Operator_1     FALSE      TRUE
#> 338   T-26-0175_Operator_2     FALSE      TRUE
#> 339   T-26-0176_Operator_1     FALSE      TRUE
#> 340   T-26-0176_Operator_2     FALSE      TRUE
#> 341   T-26-0177_Operator_1     FALSE      TRUE
#> 342   T-26-0177_Operator_2     FALSE      TRUE
#> 343   T-26-0178_Operator_1     FALSE      TRUE
#> 344   T-26-0178_Operator_2     FALSE      TRUE
#> 345 T-26-0179-3_Operator_1     FALSE      TRUE
#> 346 T-26-0179-3_Operator_2     FALSE      TRUE
#> 347   T-26-0179_Operator_1     FALSE      TRUE
#> 348   T-26-0179_Operator_2     FALSE      TRUE
#> 349   T-26-0180_Operator_1     FALSE      TRUE
#> 350   T-26-0180_Operator_2     FALSE      TRUE
#> 351   T-26-0181_Operator_1     FALSE      TRUE
#> 352   T-26-0181_Operator_2     FALSE      TRUE
#> 353   T-26-0182_Operator_1     FALSE      TRUE
#> 354   T-26-0182_Operator_2     FALSE      TRUE
#> 355   T-26-0183_Operator_1     FALSE      TRUE
#> 356   T-26-0183_Operator_2     FALSE      TRUE
#> 357   T-26-0184_Operator_1     FALSE      TRUE
#> 358   T-26-0184_Operator_2     FALSE      TRUE
#> 359   T-26-0185_Operator_1     FALSE      TRUE
#> 360   T-26-0185_Operator_2     FALSE      TRUE
#> 361   T-26-0186_Operator_1     FALSE      TRUE
#> 362   T-26-0186_Operator_2     FALSE      TRUE
#> 363   T-26-0187_Operator_1     FALSE      TRUE
#> 364   T-26-0187_Operator_2     FALSE      TRUE
#> 365   T-26-0188_Operator_1     FALSE      TRUE
#> 366   T-26-0188_Operator_2     FALSE      TRUE
#> 367   T-26-0189_Operator_1     FALSE      TRUE
#> 368   T-26-0189_Operator_2     FALSE      TRUE
#> 369   T-26-0190_Operator_1      TRUE     FALSE
#> 370   T-26-0190_Operator_2     FALSE      TRUE
#> 371   T-26-0191_Operator_1     FALSE      TRUE
#> 372   T-26-0191_Operator_2     FALSE      TRUE
#> 373   T-26-0192_Operator_1     FALSE      TRUE
#> 374   T-26-0192_Operator_2     FALSE      TRUE
#> 375   T-26-0193_Operator_1     FALSE      TRUE
#> 376   T-26-0193_Operator_2     FALSE      TRUE
#> 377   T-26-0194_Operator_1     FALSE      TRUE
#> 378   T-26-0194_Operator_2     FALSE      TRUE
#> 379   T-26-0195_Operator_1     FALSE      TRUE
#> 380   T-26-0195_Operator_2     FALSE      TRUE
#> 381   T-26-0196_Operator_1     FALSE      TRUE
#> 382   T-26-0196_Operator_2     FALSE      TRUE
#> 383   T-26-0197_Operator_1     FALSE      TRUE
#> 384   T-26-0197_Operator_2     FALSE      TRUE
#> 385   T-26-0198_Operator_1     FALSE      TRUE
#> 386   T-26-0198_Operator_2     FALSE      TRUE
#> 387   T-26-0199_Operator_1     FALSE      TRUE
#> 388   T-26-0199_Operator_2     FALSE      TRUE
#> 389   T-26-0200_Operator_1     FALSE      TRUE
#> 390   T-26-0200_Operator_2     FALSE      TRUE
#> 391   T-26-0201_Operator_1     FALSE      TRUE
#> 392   T-26-0201_Operator_2     FALSE      TRUE
#> 393   T-26-0202_Operator_1     FALSE      TRUE
#> 394   T-26-0202_Operator_2     FALSE      TRUE
#> 395   T-26-0203_Operator_1     FALSE      TRUE
#> 396   T-26-0203_Operator_2     FALSE      TRUE
#> 397   T-26-0204_Operator_1     FALSE      TRUE
#> 398   T-26-0204_Operator_2     FALSE      TRUE
#> 399   T-26-0205_Operator_1     FALSE      TRUE
#> 400   T-26-0205_Operator_2     FALSE      TRUE
#> 401   T-26-0206_Operator_1     FALSE      TRUE
#> 402   T-26-0206_Operator_2     FALSE      TRUE
#> 403   T-26-0207_Operator_1     FALSE      TRUE
#> 404   T-26-0207_Operator_2     FALSE      TRUE
#> 405   T-26-0208_Operator_1     FALSE      TRUE
#> 406   T-26-0208_Operator_2     FALSE      TRUE
#> 407   T-26-0209_Operator_1      TRUE     FALSE
#> 408   T-26-0209_Operator_2     FALSE      TRUE
#> 409   T-26-0210_Operator_1     FALSE      TRUE
#> 410   T-26-0210_Operator_2     FALSE      TRUE
#> 411   T-26-0211_Operator_1     FALSE      TRUE
#> 412   T-26-0211_Operator_2     FALSE      TRUE
#> 413   T-26-0212_Operator_1     FALSE      TRUE
#> 414   T-26-0212_Operator_2     FALSE      TRUE
#> 415   T-26-0213_Operator_1     FALSE      TRUE
#> 416   T-26-0213_Operator_2     FALSE      TRUE
#> 417   T-26-0214_Operator_1     FALSE      TRUE
#> 418   T-26-0214_Operator_2     FALSE      TRUE
#> 419   T-26-0215_Operator_1     FALSE      TRUE
#> 420   T-26-0215_Operator_2     FALSE      TRUE
#> 421   T-26-0216_Operator_1     FALSE      TRUE
#> 422   T-26-0216_Operator_2     FALSE      TRUE
#> 423   T-26-0217_Operator_1     FALSE      TRUE
#> 424   T-26-0217_Operator_2     FALSE      TRUE
#> 425   T-26-0218_Operator_1     FALSE      TRUE
#> 426   T-26-0218_Operator_2     FALSE      TRUE
#> 427   T-26-0219_Operator_1     FALSE      TRUE
#> 428   T-26-0219_Operator_2     FALSE      TRUE
#> 429   T-26-0220_Operator_1     FALSE      TRUE
#> 430   T-26-0220_Operator_2     FALSE      TRUE
#> 431   T-26-0221_Operator_1     FALSE      TRUE
#> 432   T-26-0221_Operator_2     FALSE      TRUE
#> 433   T-26-0222_Operator_1     FALSE      TRUE
#> 434   T-26-0222_Operator_2     FALSE      TRUE
#> 435   T-26-0223_Operator_1     FALSE      TRUE
#> 436   T-26-0223_Operator_2     FALSE      TRUE
#> 437   T-26-0224_Operator_1     FALSE      TRUE
#> 438   T-26-0224_Operator_2     FALSE      TRUE
#> 439   T-26-0225_Operator_1     FALSE      TRUE
#> 440   T-26-0225_Operator_2     FALSE      TRUE
#> 441   T-26-0226_Operator_1     FALSE      TRUE
#> 442   T-26-0226_Operator_2     FALSE      TRUE
#> 443   T-26-0227_Operator_1     FALSE      TRUE
#> 444   T-26-0227_Operator_2     FALSE      TRUE
#> 445   T-26-0228_Operator_1     FALSE      TRUE
#> 446   T-26-0228_Operator_2     FALSE      TRUE
#> 447   T-26-0229_Operator_1     FALSE      TRUE
#> 448   T-26-0229_Operator_2     FALSE      TRUE
#> 449 T-26-0230-1_Operator_1     FALSE      TRUE
#> 450 T-26-0230-1_Operator_2     FALSE      TRUE
#> 451 T-26-0230-2_Operator_1     FALSE      TRUE
#> 452 T-26-0230-2_Operator_2     FALSE      TRUE
#> 453 T-26-0230-3_Operator_1     FALSE      TRUE
#> 454 T-26-0230-3_Operator_2     FALSE      TRUE
#> 455 T-26-0230-4_Operator_1     FALSE      TRUE
#> 456 T-26-0230-4_Operator_2     FALSE      TRUE
#> 457   T-26-0231_Operator_1     FALSE      TRUE
#> 458   T-26-0231_Operator_2     FALSE      TRUE
#> 459   T-26-0232_Operator_1     FALSE      TRUE
#> 460   T-26-0232_Operator_2     FALSE      TRUE
#> 461   T-26-0233_Operator_1     FALSE      TRUE
#> 462   T-26-0233_Operator_2     FALSE      TRUE
#> 463   T-26-0234_Operator_1     FALSE      TRUE
#> 464   T-26-0234_Operator_2     FALSE      TRUE
#> 465   T-26-0235_Operator_1     FALSE      TRUE
#> 466   T-26-0235_Operator_2     FALSE      TRUE
#> 467   T-26-0236_Operator_1     FALSE      TRUE
#> 468   T-26-0236_Operator_2     FALSE      TRUE
#> 469   T-26-0237_Operator_1     FALSE      TRUE
#> 470   T-26-0237_Operator_2     FALSE      TRUE
#> 471   T-26-0238_Operator_1     FALSE      TRUE
#> 472   T-26-0238_Operator_2     FALSE      TRUE
#> 473   T-26-0239_Operator_1     FALSE      TRUE
#> 474   T-26-0239_Operator_2     FALSE      TRUE
#> 475   T-26-0240_Operator_1     FALSE      TRUE
#> 476   T-26-0240_Operator_2     FALSE      TRUE
#> 477   T-26-0241_Operator_1     FALSE      TRUE
#> 478   T-26-0241_Operator_2     FALSE      TRUE
#> 479   T-26-0242_Operator_1     FALSE      TRUE
#> 480   T-26-0242_Operator_2     FALSE      TRUE
#> 481   T-26-0243_Operator_1     FALSE      TRUE
#> 482   T-26-0243_Operator_2     FALSE      TRUE
#> 483   T-26-0244_Operator_1     FALSE      TRUE
#> 484   T-26-0244_Operator_2     FALSE      TRUE
#> 485   T-26-0245_Operator_1     FALSE      TRUE
#> 486   T-26-0245_Operator_2     FALSE      TRUE
#> 487   T-26-0246_Operator_1     FALSE      TRUE
#> 488   T-26-0246_Operator_2     FALSE      TRUE
#> 489   T-26-0247_Operator_1     FALSE      TRUE
#> 490   T-26-0247_Operator_2     FALSE      TRUE
#> 491   T-26-0248_Operator_1     FALSE      TRUE
#> 492   T-26-0248_Operator_2     FALSE      TRUE
#> 493   T-26-0249_Operator_1     FALSE      TRUE
#> 494   T-26-0249_Operator_2     FALSE      TRUE
#> 495   T-26-0250_Operator_1     FALSE      TRUE
#> 496   T-26-0250_Operator_2     FALSE      TRUE
#> 497   T-26-0251_Operator_1     FALSE      TRUE
#> 498   T-26-0251_Operator_2     FALSE      TRUE
#> 499   T-26-0252_Operator_1     FALSE      TRUE
#> 500   T-26-0252_Operator_2     FALSE      TRUE
#> 501 T-26-0261-1_Operator_1      TRUE      TRUE
#> 502 T-26-0261-1_Operator_2      TRUE      TRUE
#> 503 T-26-0261-2_Operator_1      TRUE      TRUE
#> 504 T-26-0261-2_Operator_2      TRUE      TRUE
#> 505 T-26-0261-3_Operator_1      TRUE      TRUE
#> 506 T-26-0261-3_Operator_2      TRUE      TRUE
#> 507 T-26-0261-4_Operator_1      TRUE      TRUE
#> 508 T-26-0261-4_Operator_2      TRUE      TRUE
#> 509 T-26-0261-5_Operator_1      TRUE      TRUE
#> 510 T-26-0261-5_Operator_2      TRUE      TRUE
#> 511 T-26-0262-1_Operator_1     FALSE      TRUE
#> 512 T-26-0262-1_Operator_2     FALSE      TRUE
#> 513 T-26-0262-2_Operator_1     FALSE      TRUE
#> 514 T-26-0262-2_Operator_2     FALSE      TRUE
#> 515   T-26-0263_Operator_1      TRUE      TRUE
#> 516   T-26-0263_Operator_2      TRUE      TRUE
#> 517 T-26-0264-1_Operator_1      TRUE      TRUE
#> 518 T-26-0264-1_Operator_2      TRUE      TRUE
#> 519 T-26-0264-2_Operator_1      TRUE      TRUE
#> 520 T-26-0264-2_Operator_2      TRUE      TRUE
#> 521 T-26-0264-3_Operator_1      TRUE      TRUE
#> 522 T-26-0264-3_Operator_2      TRUE      TRUE
#> 523 T-26-0264-4_Operator_1      TRUE      TRUE
#> 524 T-26-0264-4_Operator_2      TRUE      TRUE
#> 525   T-26-0265_Operator_1      TRUE      TRUE
#> 526   T-26-0265_Operator_2      TRUE      TRUE
#> 527   T-26-0266_Operator_1      TRUE      TRUE
#> 528   T-26-0266_Operator_2      TRUE      TRUE
#> 529   T-26-0267_Operator_1     FALSE      TRUE
#> 530   T-26-0267_Operator_2     FALSE      TRUE
#> 531   T-26-0268_Operator_1      TRUE      TRUE
#> 532   T-26-0268_Operator_2      TRUE      TRUE
#> 533   T-26-0269_Operator_1      TRUE      TRUE
#> 534   T-26-0269_Operator_2      TRUE      TRUE
#> 535 T-26-0270-1_Operator_1      TRUE      TRUE
#> 536 T-26-0270-1_Operator_2      TRUE      TRUE
#> 537 T-26-0270-2_Operator_1      TRUE      TRUE
#> 538 T-26-0270-2_Operator_2      TRUE      TRUE
#> 539   T-26-0271_Operator_1      TRUE      TRUE
#> 540   T-26-0271_Operator_2      TRUE      TRUE
#> 541   T-26-0272_Operator_1      TRUE      TRUE
#> 542   T-26-0272_Operator_2      TRUE      TRUE
#> 543   T-26-0273_Operator_1      TRUE      TRUE
#> 544   T-26-0273_Operator_2      TRUE      TRUE
#> 545   T-26-0274_Operator_1      TRUE      TRUE
#> 546   T-26-0274_Operator_2      TRUE      TRUE
#> 547   T-26-0275_Operator_1      TRUE      TRUE
#> 548   T-26-0275_Operator_2      TRUE      TRUE
#> 549   T-26-0276_Operator_1      TRUE      TRUE
#> 550   T-26-0276_Operator_2      TRUE      TRUE
#> 551   T-26-0277_Operator_1      TRUE      TRUE
#> 552   T-26-0277_Operator_2      TRUE      TRUE
#> 553 T-26-0278-1_Operator_1      TRUE      TRUE
#> 554 T-26-0278-1_Operator_2      TRUE      TRUE
#> 555 T-26-0278-2_Operator_1      TRUE      TRUE
#> 556 T-26-0278-2_Operator_2      TRUE      TRUE
#> 557   T-26-0279_Operator_1      TRUE      TRUE
#> 558   T-26-0279_Operator_2      TRUE      TRUE
plot_fishmorph_points(fish_oriented, specimen = 1)

```
