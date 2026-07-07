# Standardize landmark scale, scale-bar position, and rotation, without changing any measurement value

The value-preserving half of
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)'s
pipeline (its steps 1-3), available on its own: (1) rescale the body
landmarks isotropically so they fit within `[0, 1]` (preserving body
shape); (2) reposition the embedded scale bar (landmarks 20-21) to a
fixed corner of that `[0, 1]` space; (3) rotate the body so the main
axis (landmarks 1-2) is exactly horizontal, landmark 1 to the left of
landmark 2, anchored at `Y = 0.5` for every specimen. Because it only
ever rescales, translates, and rigidly rotates coordinates, it never
changes any FISHMORPH segment or ratio value (Euclidean distances, and
therefore every ratio computed from them, are invariant under these
operations) – see Details. This is in contrast to
[`correct_geometry_conventions()`](https://funtraits.github.io/intraitR/reference/correct_geometry_conventions.md)
(step 4), which actively moves landmarks and does change values.

## Usage

``` r
standardize_geometry(
  landmarks,
  specimen = NULL,
  scale_bar_pos = c(0.1, 0.1),
  orient = TRUE
)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"`, or a raw `p x k x n`
  landmark array, with at least the 21 landmarks of the FISHMORPH scheme
  (points 1-19 plus the scale bar, 20-21).

- specimen:

  `NULL` (default) to standardize every specimen, or an
  integer/character vector to restrict this to a subset.

- scale_bar_pos:

  Numeric length-2 vector, the `c(x, y)` position (in the post-rescaling
  `[0, 1]` space) landmark 20 is moved to; landmark 21 is placed to its
  right, at `scale_bar_pos + c(length, 0)`, where `length` is the scale
  bar's own original length scaled by the same factor as the body – so
  the calibration ratio between the scale bar and the body is preserved,
  only its position and orientation are standardized. Defaults to
  `c(0.1, 0.1)` (bottom-left).

- orient:

  Logical, whether to call
  [`standardize_orientation()`](https://funtraits.github.io/intraitR/reference/standardize_orientation.md)
  first, before steps 1-3, so a specimen digitized mirrored (left-right)
  or upside-down (dorsal-ventral) is corrected before rescaling/rotation
  rather than needing a separate call. Defaults to `TRUE`, coupling the
  two functions that earlier versions of this package's documentation
  already recommended chaining manually
  (`fish \%>\% standardize_orientation() \%>\% standardize_geometry(orient = FALSE)`
  is equivalent to the default `standardize_geometry(fish)`). Set to
  `FALSE` if orientation was already standardized separately (as
  [`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)
  itself does internally, to stay behaviour identical across package
  versions), or if you deliberately want to preserve each specimen's
  original mirroring.

## Value

An object of the same class as `landmarks`, with every specimen's
coordinates replaced by their standardized version, and, if `landmarks`
is an `"intrait_landmarks"` object with a `$scale` element, that element
rescaled to match (see Details) so that no specimen's true real-world
size is lost even though every specimen is now drawn at the same visual
size. The returned `coords` array carries a `standardization_log`
attribute, a `data.frame`, one row per specimen processed, with columns
`specimen`, `scale_factor` (the isotropic factor applied in step 1),
`rotation_deg` (the rotation applied in step 3), `y_shift` (the vertical
translation applied immediately after that rotation to bring the axis to
`Y = 0.5`), and `scale_bar_placed` (logical, whether landmarks 20-21
were repositioned). Merged with any pre-existing `standardization_log`
from an earlier call, so successive calls accumulate a full record. If
`orient = TRUE`, the returned object also carries `orientation_log` from
the internal
[`standardize_orientation()`](https://funtraits.github.io/intraitR/reference/standardize_orientation.md)
call (see its own Return).

## Details

See
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)'s
Details for the full rationale behind each of the three steps (isotropic
rescale, scale-bar repositioning, rotation + vertical anchoring), which
this function implements identically – the only difference is that step
4 (active correction of landmarks that still violate the FISHMORPH
geometric conventions once the axis is horizontal) is not performed
here; call
[`correct_geometry_conventions()`](https://funtraits.github.io/intraitR/reference/correct_geometry_conventions.md)
afterwards for that, or use
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)
directly for the combined pipeline in one call.

As with
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md),
running this function twice on already-standardized data is harmless
(idempotent up to floating-point precision): a specimen already
isotropically scaled to `[0, 1]` and horizontal is left materially
unchanged by a second pass.

## See also

[`correct_geometry_conventions()`](https://funtraits.github.io/intraitR/reference/correct_geometry_conventions.md)
(step 4, which does change values),
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)
(the combined pipeline, unchanged and still the recommended one-call
route for existing workflows),
[`standardize_orientation()`](https://funtraits.github.io/intraitR/reference/standardize_orientation.md),
[`correct_landmarks()`](https://funtraits.github.io/intraitR/reference/correct_landmarks.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)

## Examples

``` r
fish <- load_t26_saudrune_landmarks()
# orientation (left-right/dorsal-ventral mirroring) is standardized
# automatically first, by default:
fish_std <- standardize_geometry(fish)
#> standardize_orientation(): 557 of 558 specimen(s) mirrored (165 horizontally, 555 vertically) to a consistent head-left, belly-down orientation.
#> standardize_geometry(): standardized 558 specimen(s) (isotropic rescale + scale bar + rotation); no landmark coordinate value was corrected (see correct_geometry_conventions() for that).
attr(fish_std$coords, "orientation_log")
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
attr(fish_std$coords, "standardization_log")
#>                    specimen scale_factor rotation_deg    y_shift
#> Y      T-26-0001_Operator_1 0.0008402182  -1.07145280  0.3673858
#> Y1     T-26-0001_Operator_2 0.0008392782  -1.41502062  0.3652958
#> Y2     T-26-0002_Operator_1 0.0007165890  -3.53802441  0.3866593
#> Y3     T-26-0002_Operator_2 0.0007196833  -3.77269529  0.3873696
#> Y4     T-26-0003_Operator_1 0.0008213552  -2.23601041  0.4026694
#> Y5     T-26-0003_Operator_2 0.0008247423  -1.66341376  0.4058416
#> Y6     T-26-0004_Operator_1 0.0003258036   0.73595494  0.3199935
#> Y7     T-26-0004_Operator_2 0.0003284431   0.81088820  0.3116379
#> Y8     T-26-0005_Operator_1 0.0010178117   0.00000000  0.3710768
#> Y9     T-26-0005_Operator_2 0.0010252908  -0.30071464  0.3726927
#> Y10    T-26-0006_Operator_1 0.0007803355  -3.42330977  0.3914030
#> Y11    T-26-0006_Operator_2 0.0007815553  -3.83093844  0.4003517
#> Y12    T-26-0007_Operator_1 0.0004312514   1.48551818  0.2989648
#> Y13    T-26-0007_Operator_2 0.0004326508   1.63354153  0.2938419
#> Y14    T-26-0008_Operator_1 0.0004125413  -0.76094726  0.3434406
#> Y15    T-26-0008_Operator_2 0.0004199034   0.10649694  0.3465253
#> Y16    T-26-0009_Operator_1 0.0010465725   3.08564115  0.2545788
#> Y17    T-26-0009_Operator_2 0.0010454783   3.57412840  0.2569263
#> Y18    T-26-0010_Operator_1 0.0007010165  -3.73913975  0.3592128
#> Y19    T-26-0010_Operator_2 0.0007067138  -3.47578327  0.3494700
#> Y20    T-26-0011_Operator_1 0.0003234849   2.18813389  0.3279600
#> Y21    T-26-0011_Operator_2 0.0003260161   1.70440125  0.3242229
#> Y22    T-26-0012_Operator_1 0.0009564802   6.34722190  0.2417504
#> Y23    T-26-0012_Operator_2 0.0009334166   5.06201325  0.2472000
#> Y24    T-26-0013_Operator_1 0.0007003620   1.10912316  0.3327304
#> Y25    T-26-0013_Operator_2 0.0007001168   1.32438277  0.3271881
#> Y26    T-26-0014_Operator_1 0.0007015082   2.29493404  0.3066173
#> Y27    T-26-0014_Operator_2 0.0007094714   2.27003772  0.2978006
#> Y28    T-26-0015_Operator_1 0.0007819629  -0.57686766  0.3150658
#> Y29    T-26-0015_Operator_2 0.0007889546  -0.76773966  0.3094675
#> Y30    T-26-0016_Operator_1 0.0005626404   2.99332753  0.3048577
#> Y31    T-26-0016_Operator_2 0.0005600148   3.23671616  0.3070749
#> Y32    T-26-0017_Operator_1 0.0008791209  -0.69271119  0.3342857
#> Y33    T-26-0017_Operator_2 0.0008822232  -1.37717801  0.3332598
#> Y34    T-26-0018_Operator_1 0.0003405415   0.49381790  0.3309212
#> Y35    T-26-0018_Operator_2 0.0003392130   1.37465002  0.3272839
#> Y36    T-26-0019_Operator_1 0.0005066285  -1.94293635  0.3774805
#> Y37    T-26-0019_Operator_2 0.0005105948  -1.71716860  0.3768614
#> Y38    T-26-0020_Operator_1 0.0007724990  -2.58155773  0.3597914
#> Y39    T-26-0020_Operator_2 0.0007540528  -2.47599517  0.3628883
#> Y40    T-26-0021_Operator_1 0.0007401925  -0.43332116  0.4089563
#> Y41    T-26-0021_Operator_2 0.0007485030  -0.60520216  0.4075599
#> Y42    T-26-0022_Operator_1 0.0005910165   4.85523184  0.2662530
#> Y43    T-26-0022_Operator_2 0.0005902028   5.35441400  0.2624434
#> Y44  T-26-0023-2_Operator_1 0.0014234875  -1.16715492  0.4071174
#> Y45  T-26-0023-2_Operator_2 0.0014409222  -0.99538693  0.4048991
#> Y46    T-26-0024_Operator_1 0.0006538084  -6.42746549  0.3721805
#> Y47    T-26-0024_Operator_2 0.0006633499  -6.99061724  0.3658925
#> Y48    T-26-0025_Operator_1 0.0006617402  -3.22849334  0.3587185
#> Y49    T-26-0025_Operator_2 0.0006682259  -4.07621158  0.3470879
#> Y50    T-26-0026_Operator_1 0.0006286015  -2.82094819  0.3676794
#> Y51    T-26-0026_Operator_2 0.0006343165  -2.86483041  0.3588646
#> Y52    T-26-0027_Operator_1 0.0006012022   3.43981032  0.3175351
#> Y53    T-26-0027_Operator_2 0.0005999999   3.95680518  0.3128000
#> Y54    T-26-0028_Operator_1 0.0008306800  -1.86404330  0.3683372
#> Y55    T-26-0028_Operator_2 0.0008445946  -1.57655006  0.3593750
#> Y56    T-26-0029_Operator_1 0.0014644869  -7.76831919  0.3628274
#> Y57    T-26-0029_Operator_2 0.0014886491  -7.55686971  0.3578340
#> Y58    T-26-0030_Operator_1 0.0004639295   0.88859798  0.3540942
#> Y59    T-26-0030_Operator_2 0.0004705145   1.27975011  0.3579832
#> Y60    T-26-0031_Operator_1 0.0007486896  -5.48642037  0.3730971
#> Y61    T-26-0031_Operator_2 0.0007462687  -5.32023391  0.3723881
#> Y62    T-26-0032_Operator_1 0.0003701647   3.21265877  0.3276883
#> Y63    T-26-0032_Operator_2 0.0003719776   4.05124021  0.3253565
#> Y64    T-26-0033_Operator_1 0.0006875215   0.44342081  0.3518391
#> Y65    T-26-0033_Operator_2 0.0006904490   0.93717554  0.3501726
#> Y66    T-26-0034_Operator_1 0.0007114906  -6.78502250  0.3656471
#> Y67    T-26-0034_Operator_2 0.0007111531  -8.83096277  0.3512502
#> Y68    T-26-0035_Operator_1 0.0009263548   0.46848796  0.3784928
#> Y69    T-26-0035_Operator_2 0.0009380863   1.09068011  0.3760159
#> Y70    T-26-0036_Operator_1 0.0004345621   0.02428668  0.3621712
#> Y71    T-26-0036_Operator_2 0.0004397537   0.15992183  0.3656552
#> Y72    T-26-0037_Operator_1 0.0003532738   2.00606711  0.3575717
#> Y73    T-26-0037_Operator_2 0.0003577818   3.03320357  0.3489564
#> Y74    T-26-0038_Operator_1 0.0008183306   2.20585805  0.3465630
#> Y75    T-26-0038_Operator_2 0.0008220304   2.59350644  0.3438142
#> Y76    T-26-0039_Operator_1 0.0007429421  -0.29269024  0.3458395
#> Y77    T-26-0039_Operator_2 0.0007485030  -1.57517445  0.3413174
#> Y78    T-26-0040_Operator_1 0.0006644518   5.84502388  0.3352159
#> Y79    T-26-0040_Operator_2 0.0006761325   6.52306621  0.3225152
#> Y80    T-26-0041_Operator_1 0.0008873114  -4.15434169  0.3975155
#> Y81    T-26-0041_Operator_2 0.0009037506  -3.35415751  0.3895915
#> Y82    T-26-0042_Operator_1 0.0006172840   2.66693986  0.2836420
#> Y83    T-26-0042_Operator_2 0.0006165228   2.72241796  0.2853471
#> Y84    T-26-0043_Operator_1 0.0006995453  -3.27854850  0.3975166
#> Y85    T-26-0043_Operator_2 0.0007072136  -3.72378159  0.3960396
#> Y86    T-26-0044_Operator_1 0.0006706908   2.76203155  0.2790074
#> Y87    T-26-0044_Operator_2 0.0006668890   1.94717219  0.2839280
#> Y88    T-26-0045_Operator_1 0.0004052685  -1.38148481  0.3412024
#> Y89    T-26-0045_Operator_2 0.0004117768  -2.21146030  0.3408483
#> Y90    T-26-0046_Operator_1 0.0006608656   0.75507846  0.3315896
#> Y91    T-26-0046_Operator_2 0.0006609385   1.64977927  0.3247409
#> Y92    T-26-0047_Operator_1 0.0003581233   1.61539182  0.3186105
#> Y93    T-26-0047_Operator_2 0.0003631962   1.88239494  0.3058716
#> Y94    T-26-0048_Operator_1 0.0005961252  -3.70850270  0.3941878
#> Y95    T-26-0048_Operator_2 0.0006033183  -3.70822611  0.3929110
#> Y96    T-26-0049_Operator_1 0.0004287245  -5.11923083  0.3904609
#> Y97    T-26-0049_Operator_2 0.0004331817  -4.88735434  0.3780593
#> Y98    T-26-0050_Operator_1 0.0007482230  -2.94698307  0.3786629
#> Y99    T-26-0050_Operator_2 0.0007607455  45.00000000 -0.5000000
#> Y100   T-26-0051_Operator_1 0.0006073489  -1.15179722  0.3290313
#> Y101   T-26-0051_Operator_2 0.0006047777  -0.69104233  0.3300575
#> Y102   T-26-0052_Operator_1 0.0003614676  33.64769527 -0.2677571
#> Y103   T-26-0052_Operator_2 0.0003631741  -6.38865393  0.3806973
#> Y104   T-26-0053_Operator_1 0.0003732272   3.72510109  0.3248941
#> Y105   T-26-0053_Operator_2 0.0003749531   3.98583071  0.3158354
#> Y106   T-26-0054_Operator_1 0.0004085523   2.30068829  0.3429116
#> Y107   T-26-0054_Operator_2 0.0004137930   2.25222790  0.3373102
#> Y108   T-26-0055_Operator_1 0.0006035003   2.06183769  0.3500302
#> Y109   T-26-0055_Operator_2 0.0006071645   2.67092878  0.3424408
#> Y110 T-26-0056-2_Operator_1 0.0004553734   2.74629009  0.2770947
#> Y111 T-26-0056-2_Operator_2 0.0004512635   3.78377244  0.2741426
#> Y112   T-26-0057_Operator_1 0.0006677796  -0.43476172  0.3678912
#> Y113   T-26-0057_Operator_2 0.0006668890  -0.20135099  0.3709570
#> Y114   T-26-0058_Operator_1 0.0005984440   5.74487421  0.2854578
#> Y115   T-26-0058_Operator_2 0.0006119951   5.55589548  0.2753978
#> Y116   T-26-0059_Operator_1 0.0005915410   1.57334404  0.3346643
#> Y117   T-26-0059_Operator_2 0.0006018053   1.60001203  0.3387162
#> Y118   T-26-0060_Operator_1 0.0006540222   0.96520636  0.3492479
#> Y119   T-26-0060_Operator_2 0.0006675567   1.77890412  0.3344459
#> Y120   T-26-0061_Operator_1 0.0003870468   4.36496226  0.3030578
#> Y121   T-26-0061_Operator_2 0.0003895598   4.30557701  0.2972341
#> Y122   T-26-0062_Operator_1 0.0003113325   3.02919335  0.2903176
#> Y123   T-26-0062_Operator_2 0.0003126954   3.43204019  0.2859600
#> Y124   T-26-0063_Operator_1 0.0008572653  -2.82152766  0.3529790
#> Y125   T-26-0063_Operator_2 0.0008760403  -2.57758412  0.3550153
#> Y126   T-26-0064_Operator_1 0.0006821282   2.55758825  0.3761937
#> Y127   T-26-0064_Operator_2 0.0006882312   2.77134016  0.3631569
#> Y128   T-26-0065_Operator_1 0.0006677796   0.24027826  0.3527546
#> Y129   T-26-0065_Operator_2 0.0006754475  -0.24156759  0.3580432
#> Y130   T-26-0067_Operator_1 0.0004968122  -0.70916973  0.3646187
#> Y131   T-26-0067_Operator_2 0.0005059449  -0.60564107  0.3582509
#> Y132   T-26-0068_Operator_1 0.0004003203   3.64594235  0.2856285
#> Y133   T-26-0068_Operator_2 0.0004043672   5.98008900  0.2529992
#> Y134   T-26-0069_Operator_1 0.0005552471   7.14030317  0.2304275
#> Y135   T-26-0069_Operator_2 0.0005627462   7.21287633  0.2301632
#> Y136   T-26-0070_Operator_1 0.0005123389  -3.62613927  0.3778072
#> Y137   T-26-0070_Operator_2 0.0005177323  -3.31224577  0.3723790
#> Y138   T-26-0071_Operator_1 0.0005880623   0.92436251  0.3532784
#> Y139   T-26-0071_Operator_2 0.0005893332   2.08959851  0.3435320
#> Y140   T-26-0072_Operator_1 0.0005298482   1.07714890  0.3609148
#> Y141   T-26-0072_Operator_2 0.0005344735   1.06582942  0.3577408
#> Y142   T-26-0073_Operator_1 0.0005047956   4.06569678  0.2973246
#> Y143   T-26-0073_Operator_2 0.0005064573   4.31887040  0.2971638
#> Y144   T-26-0074_Operator_1 0.0005040323   3.94108106  0.2956149
#> Y145   T-26-0074_Operator_2 0.0005120766   1.53449506  0.2945718
#> Y146   T-26-0075_Operator_1 0.0004264696  -1.40554990  0.3380128
#> Y147   T-26-0075_Operator_2 0.0004281738   0.43016125  0.3486405
#> Y148   T-26-0076_Operator_1 0.0004187605   8.88894248  0.2472781
#> Y149   T-26-0076_Operator_2 0.0004139645   9.62201647  0.2516904
#> Y150   T-26-0077_Operator_1 0.0006337136   5.14298223  0.2911914
#> Y151   T-26-0077_Operator_2 0.0006382981   4.41871902  0.2945746
#> Y152   T-26-0078_Operator_1 0.0003944255   0.84221204  0.3973835
#> Y153   T-26-0078_Operator_2 0.0003994408   0.65854318  0.4076625
#> Y154   T-26-0079_Operator_1 0.0004805382  -0.91359838  0.3632869
#> Y155   T-26-0079_Operator_2 0.0004864208  -0.95935832  0.3611269
#> Y156   T-26-0080_Operator_1 0.0005740528   0.85688168  0.3674897
#> Y157   T-26-0080_Operator_2 0.0005797101   1.01886926  0.3675362
#> Y158   T-26-0081_Operator_1 0.0006787332   7.44337076  0.2288461
#> Y159   T-26-0081_Operator_2 0.0006720430   6.80257227  0.2301747
#> Y160   T-26-0082_Operator_1 0.0006238303   6.14598518  0.2757330
#> Y161   T-26-0082_Operator_2 0.0006177927   8.27853668  0.2634886
#> Y162   T-26-0083_Operator_1 0.0009904256   6.26697605  0.2977878
#> Y163   T-26-0083_Operator_2 0.0009876543   6.95543999  0.2858440
#> Y164   T-26-0084_Operator_1 0.0008179959  -7.30295245  0.3842536
#> Y165   T-26-0084_Operator_2 0.0008240626  -8.90988101  0.3721327
#> Y166   T-26-0085_Operator_1 0.0006651147   0.38151737  0.3799468
#> Y167   T-26-0085_Operator_2 0.0006724950  -0.37914131  0.3754761
#> Y168   T-26-0086_Operator_1 0.0004509923   1.00666725  0.3559080
#> Y169   T-26-0086_Operator_2 0.0004545455   1.73476644  0.3486364
#> Y170   T-26-0087_Operator_1 0.0005401026  -0.74030767  0.3436403
#> Y171   T-26-0087_Operator_2 0.0005339028   0.27274840  0.3432995
#> Y172   T-26-0088_Operator_1 0.0005196155  -5.36067591  0.4046506
#> Y173   T-26-0088_Operator_2 0.0005220569  -6.13719251  0.3735750
#> Y174   T-26-0089_Operator_1 0.0011428571   7.91674180  0.2794286
#> Y175   T-26-0089_Operator_2 0.0011540681   8.45136303  0.2628390
#> Y176   T-26-0090_Operator_1 0.0008419869  -1.00819593  0.3898403
#> Y177   T-26-0090_Operator_2 0.0008453085  -0.06768770  0.3984218
#> Y178   T-26-0091_Operator_1 0.0004346881  -3.70185255  0.3808229
#> Y179   T-26-0091_Operator_2 0.0004477278  -3.60336376  0.3694874
#> Y180   T-26-0092_Operator_1 0.0004501463  -7.38666391  0.3833369
#> Y181   T-26-0092_Operator_2 0.0004527960  -7.72958650  0.3648404
#> Y182   T-26-0093_Operator_1 0.0004782783  -5.10338805  0.3500598
#> Y183   T-26-0093_Operator_2 0.0004864996  -4.97601056  0.3445634
#> Y184   T-26-0094_Operator_1 0.0005603811  -5.89562065  0.3820398
#> Y185   T-26-0094_Operator_2 0.0005725737  -5.88895264  0.3737475
#> Y186   T-26-0095_Operator_1 0.0005231494  -8.38735887  0.3956317
#> Y187   T-26-0095_Operator_2 0.0005231494  -7.84716593  0.3783678
#> Y188   T-26-0096_Operator_1 0.0006163328 -11.32589452  0.3955316
#> Y189   T-26-0096_Operator_2 0.0006248047 -11.07124626  0.3697282
#> Y190   T-26-0097_Operator_1 0.0004365859  -3.07640819  0.3917996
#> Y191   T-26-0097_Operator_2 0.0004354452  -3.06988881  0.3896146
#> Y192   T-26-0098_Operator_1 0.0004963599   3.89961680  0.3304931
#> Y193   T-26-0098_Operator_2 0.0004943154   4.69984585  0.3208107
#> Y194   T-26-0099_Operator_1 0.0009188364   2.51327692  0.3142416
#> Y195   T-26-0099_Operator_2 0.0009068921   2.17315017  0.3157495
#> Y196   T-26-0100_Operator_1 0.0005871991   2.14988672  0.3652378
#> Y197   T-26-0100_Operator_2 0.0005863957   1.87686384  0.3712861
#> Y198   T-26-0101_Operator_1 0.0005409792  -1.98119667  0.3331079
#> Y199   T-26-0101_Operator_2 0.0005356186  -1.75914542  0.3500268
#> Y200   T-26-0102_Operator_1 0.0005323396  -0.88753356  0.3709076
#> Y201   T-26-0102_Operator_2 0.0005257624  -1.14611540  0.3693481
#> Y202   T-26-0103_Operator_1 0.0004124562  -1.30286815  0.3566715
#> Y203   T-26-0103_Operator_2 0.0004191993  -1.91685037  0.3618738
#> Y204   T-26-0104_Operator_1 0.0004273504  -1.86156578  0.3685897
#> Y205   T-26-0104_Operator_2 0.0004379242  -2.82468365  0.3749726
#> Y206   T-26-0107_Operator_1 0.0003761520  -1.23457686  0.3444612
#> Y207   T-26-0107_Operator_2 0.0003712872  -1.01545718  0.3732054
#> Y208   T-26-0108_Operator_1 0.0004295533   0.10355539  0.3335481
#> Y209   T-26-0108_Operator_2 0.0004339336  -2.78209566  0.3335865
#> Y210   T-26-0109_Operator_1 0.0004316857  -1.75325710  0.3758904
#> Y211   T-26-0109_Operator_2 0.0004200503  -0.64795179  0.3804957
#> Y212   T-26-0111_Operator_1 0.0011337868  -4.38590326  0.4370748
#> Y213   T-26-0111_Operator_2 0.0011841326  -4.04201933  0.4153345
#> Y214 T-26-0112-2_Operator_1 0.0005815644   2.32394369  0.3217505
#> Y215 T-26-0112-2_Operator_2 0.0005787037   2.93416130  0.3203125
#> Y216   T-26-0112_Operator_1 0.0009548062   4.48924407  0.3088793
#> Y217   T-26-0112_Operator_2 0.0009557187   4.14559727  0.3115638
#> Y218   T-26-0113_Operator_1 0.0005664118  -3.45946585  0.4447749
#> Y219   T-26-0113_Operator_2 0.0005676980  -7.35988821  0.4160755
#> Y220   T-26-0114_Operator_1 0.0005041593  -0.65326717  0.3918578
#> Y221   T-26-0114_Operator_2 0.0004102283  -1.27941701  0.3999728
#> Y222   T-26-0115_Operator_1 0.0004129672  -0.67404648  0.4081148
#> Y223   T-26-0115_Operator_2 0.0005047107   1.77590528  0.3377355
#> Y224   T-26-0116_Operator_1 0.0005068424   2.48955292  0.3238723
#> Y225   T-26-0116_Operator_2 0.0004920855  -4.04380987  0.3809975
#> Y226   T-26-0117_Operator_1 0.0004900760  -3.12880985  0.3894879
#> Y227   T-26-0117_Operator_2 0.0004508566   0.98802242  0.3649684
#> Y228   T-26-0118_Operator_1 0.0004515354   0.47473710  0.3688290
#> Y229   T-26-0118_Operator_2 0.0004897160  -4.13307062  0.3813257
#> Y230   T-26-0120_Operator_1 0.0005701254   0.70403094  0.3657355
#> Y231   T-26-0120_Operator_2 0.0005728469   3.82095157  0.3679588
#> Y232   T-26-0121_Operator_1 0.0005329070   1.50324907  0.3206768
#> Y233   T-26-0121_Operator_2 0.0018018018  45.00000000 -0.1027027
#> Y234   T-26-0122_Operator_1 0.0004349085   5.01794661  0.2595682
#> Y235   T-26-0122_Operator_2 0.0004335887   3.89680099  0.2657897
#> Y236   T-26-0123_Operator_1 0.0004712535   7.73480495  0.2551838
#> Y237   T-26-0123_Operator_2 0.0004767201   6.81910779  0.2542508
#> Y238   T-26-0125_Operator_1 0.0005619556  -2.88215169  0.3968811
#> Y239   T-26-0125_Operator_2 0.0005606953  -3.06946954  0.3802916
#> Y240   T-26-0126_Operator_1 0.0005602241  -0.92985979  0.3697479
#> Y241   T-26-0126_Operator_2 0.0005652911  -2.70523672  0.3670622
#> Y242   T-26-0127_Operator_1 0.0004330879   2.68039126  0.3538328
#> Y243   T-26-0127_Operator_2 0.0004384042   3.52215533  0.3476545
#> Y244   T-26-0128_Operator_1 0.0005356186   1.98003479  0.4006427
#> Y245   T-26-0128_Operator_2 0.0005361930   2.74585010  0.3887399
#> Y246   T-26-0130_Operator_1 0.0008754015   5.17382605  0.3845932
#> Y247   T-26-0130_Operator_2 0.0008784776   4.93083429  0.3809663
#> Y248   T-26-0131_Operator_1 0.0006385696   5.47157126  0.2934227
#> Y249   T-26-0131_Operator_2 0.0006376872   5.56057523  0.2864813
#> Y250   T-26-0132_Operator_1 0.0006830601   2.88135925  0.2749317
#> Y251   T-26-0132_Operator_2 0.0006891799   1.83421979  0.2749828
#> Y252   T-26-0133_Operator_1 0.0006837607  -4.08080187  0.4353846
#> Y253   T-26-0133_Operator_2 0.0006944444  -2.52577658  0.4045139
#> Y254   T-26-0134_Operator_1 0.0007125045  -0.94599819  0.3628429
#> Y255   T-26-0134_Operator_2 0.0007173601  -0.11716912  0.3558106
#> Y256   T-26-0135_Operator_1 0.0006629102  -2.32601605  0.3969175
#> Y257   T-26-0135_Operator_2 0.0006702413  -0.20229889  0.3589142
#> Y258   T-26-0136_Operator_1 0.0006666667  -1.52479576  0.3723333
#> Y259   T-26-0136_Operator_2 0.0006663704  -0.29781624  0.3633941
#> Y260   T-26-0137_Operator_1 0.0003782864  -2.57110972  0.3825421
#> Y261   T-26-0137_Operator_2 0.0003827751  -2.35966518  0.3761722
#> Y262   T-26-0138_Operator_1 0.0007254262  -0.42001328  0.3871962
#> Y263   T-26-0138_Operator_2 0.0007358352   0.12417791  0.3771155
#> Y264   T-26-0139_Operator_1 0.0006686727  -1.88868776  0.3793046
#> Y265   T-26-0139_Operator_2 0.0006724194  -0.93545131  0.3799731
#> Y266   T-26-0140_Operator_1 0.0008959233  -2.24903328  0.3699415
#> Y267   T-26-0140_Operator_2 0.0008976661  -2.15543642  0.3662478
#> Y268   T-26-0141_Operator_1 0.0006825939   0.11238860  0.3392491
#> Y269   T-26-0141_Operator_2 0.0006828269   0.47500348  0.3325934
#> Y270   T-26-0142_Operator_1 0.0008566536  -2.01004036  0.3853515
#> Y271   T-26-0142_Operator_2 0.0008620690  -2.27564700  0.3879310
#> Y272   T-26-0143_Operator_1 0.0007244629  -1.78299936  0.3808259
#> Y273   T-26-0143_Operator_2 0.0007347539   0.02481411  0.3633358
#> Y274   T-26-0144_Operator_1 0.0005096840  -2.48653267  0.4074924
#> Y275   T-26-0144_Operator_2 0.0005127330  -0.48479178  0.3766877
#> Y276   T-26-0145_Operator_1 0.0016220600   3.25130996  0.3621249
#> Y277   T-26-0145_Operator_2 0.0016083635   2.97945250  0.3655682
#> Y278   T-26-0146_Operator_1 0.0005998800   0.66158468  0.3263347
#> Y279   T-26-0146_Operator_2 0.0006009615   0.86755931  0.3134014
#> Y280   T-26-0147_Operator_1 0.0005292405  -0.83806710  0.3758931
#> Y281   T-26-0147_Operator_2 0.0005279831   0.14995347  0.3612286
#> Y282   T-26-0148_Operator_1 0.0004189066  -0.27096679  0.3315296
#> Y283   T-26-0148_Operator_2 0.0004190530   0.98085434  0.3064675
#> Y284   T-26-0149_Operator_1 0.0002390343  -0.66248459  0.3466595
#> Y285   T-26-0149_Operator_2 0.0002386255   1.52450393  0.3216274
#> Y286   T-26-0150_Operator_1 0.0003471620  -1.72916580  0.3640861
#> Y287   T-26-0150_Operator_2 0.0003485940  -0.89535537  0.3516733
#> Y288   T-26-0151_Operator_1 0.0006462036  -0.89745611  0.3542811
#> Y289   T-26-0151_Operator_2 0.0006487188  -0.74962163  0.3556601
#> Y290   T-26-0152_Operator_1 0.0017381238  -4.17332155  0.4055625
#> Y291   T-26-0152_Operator_2 0.0017543860  -4.43853142  0.4061404
#> Y292   T-26-0153_Operator_1 0.0007459903  -2.31988241  0.3720627
#> Y293   T-26-0153_Operator_2 0.0007457122  -2.92607134  0.3691275
#> Y294   T-26-0154_Operator_1 0.0008839130   4.00682758  0.3213020
#> Y295   T-26-0154_Operator_2 0.0008748906   4.45648020  0.3146693
#> Y296   T-26-0155_Operator_1 0.0012070006   0.52195132  0.3436934
#> Y297   T-26-0155_Operator_2 0.0012080942   0.65702865  0.3384174
#> Y298   T-26-0156_Operator_1 0.0002890591  -1.27944114  0.3677555
#> Y299   T-26-0156_Operator_2 0.0002911208   0.98170617  0.3377001
#> Y300   T-26-0157_Operator_1 0.0006319115   4.35401038  0.3000000
#> Y301   T-26-0157_Operator_2 0.0006257822   4.03004087  0.2950563
#> Y302   T-26-0158_Operator_1 0.0007039775   0.02311246  0.3489968
#> Y303   T-26-0158_Operator_2 0.0007072136   1.00100278  0.3327440
#> Y304   T-26-0159_Operator_1 0.0006512537  -2.09551578  0.3889613
#> Y305   T-26-0159_Operator_2 0.0006591958  -1.90988365  0.3823336
#> Y306   T-26-0160_Operator_1 0.0006927607  -3.77500817  0.3985106
#> Y307   T-26-0160_Operator_2 0.0006942034  -3.75922303  0.3965637
#> Y308   T-26-0161_Operator_1 0.0007412898   1.35629756  0.3439585
#> Y309   T-26-0161_Operator_2 0.0007429421   3.02416595  0.3150074
#> Y310   T-26-0162_Operator_1 0.0007578628  -0.88764579  0.3488064
#> Y311   T-26-0162_Operator_2 0.0007573847  -0.86530868  0.3382984
#> Y312   T-26-0163_Operator_1 0.0006209252  -1.23852124  0.3990997
#> Y313   T-26-0163_Operator_2 0.0006222775  -1.50464859  0.3960797
#> Y314   T-26-0164_Operator_1 0.0012079731  -5.93447669  0.4293336
#> Y315   T-26-0164_Operator_2 0.0012148203  -6.47277441  0.4208338
#> Y316   T-26-0165_Operator_1 0.0007644284  -7.42325364  0.3811314
#> Y317   T-26-0165_Operator_2 0.0007642339  -7.39321978  0.3702079
#> Y318   T-26-0166_Operator_1 0.0013568521  -7.61255670  0.4036635
#> Y319   T-26-0166_Operator_2 0.0013596193  -7.38604315  0.3973487
#> Y320   T-26-0167_Operator_1 0.0002093145  -1.38179015  0.3623757
#> Y321   T-26-0167_Operator_2 0.0002105706  -0.25375610  0.3471609
#> Y322   T-26-0168_Operator_1 0.0007089685  -2.54735093  0.3649415
#> Y323   T-26-0168_Operator_2 0.0007130125  -2.52441551  0.3584670
#> Y324   T-26-0169_Operator_1 0.0005743825   1.91224439  0.3147616
#> Y325   T-26-0169_Operator_2 0.0005711022   1.92178954  0.3189606
#> Y326   T-26-0170_Operator_1 0.0006029545  -1.03476501  0.3690582
#> Y327   T-26-0170_Operator_2 0.0006069188  -0.53068330  0.3604087
#> Y328   T-26-0171_Operator_1 0.0005859947  -2.42387382  0.3696162
#> Y329   T-26-0171_Operator_2 0.0005897965  -2.80374761  0.3622825
#> Y330   T-26-0172_Operator_1 0.0006121824  -2.07003065  0.3956229
#> Y331   T-26-0172_Operator_2 0.0006220840  -2.11261772  0.3833593
#> Y332   T-26-0173_Operator_1 0.0008537282   1.38751575  0.3430566
#> Y333   T-26-0173_Operator_2 0.0008556765   1.19167337  0.3412720
#> Y334   T-26-0174_Operator_1 0.0007312614  -1.67566562  0.3497258
#> Y335   T-26-0174_Operator_2 0.0007363770  -1.09067806  0.3449926
#> Y336   T-26-0175_Operator_1 0.0006648936   0.51535682  0.3660239
#> Y337   T-26-0175_Operator_2 0.0006634965   0.98578448  0.3598914
#> Y338   T-26-0176_Operator_1 0.0006811989  -0.75294778  0.3736376
#> Y339   T-26-0176_Operator_2 0.0006829048  -0.31091842  0.3620532
#> Y340   T-26-0177_Operator_1 0.0006163328  -7.46658573  0.3536210
#> Y341   T-26-0177_Operator_2 0.0006192591  -6.39876715  0.3438433
#> Y342   T-26-0178_Operator_1 0.0006170935  -4.25216118  0.3713360
#> Y343   T-26-0178_Operator_2 0.0006207325  -4.87549695  0.3678876
#> Y344 T-26-0179-3_Operator_1 0.0006156373   2.48776291  0.3205417
#> Y345 T-26-0179-3_Operator_2 0.0006176652   3.90470656  0.2981266
#> Y346   T-26-0179_Operator_1 0.0011474469  -5.01134735  0.4038061
#> Y347   T-26-0179_Operator_2 0.0011603176  -5.77865148  0.3961516
#> Y348   T-26-0180_Operator_1 0.0006119951   3.22594839  0.3154835
#> Y349   T-26-0180_Operator_2 0.0006147540   3.34734799  0.3005123
#> Y350   T-26-0181_Operator_1 0.0007104796  -1.48368902  0.3667851
#> Y351   T-26-0181_Operator_2 0.0007132668  -1.64284637  0.3666191
#> Y352   T-26-0182_Operator_1 0.0007202878   0.95952763  0.3599040
#> Y353   T-26-0182_Operator_2 0.0007183908   1.04693766  0.3609914
#> Y354   T-26-0183_Operator_1 0.0005968368   0.14038140  0.3648165
#> Y355   T-26-0183_Operator_2 0.0006022282  -0.50524069  0.3684131
#> Y356   T-26-0184_Operator_1 0.0005511160  -8.01370145  0.3900524
#> Y357   T-26-0184_Operator_2 0.0005551956  -6.67440443  0.3810954
#> Y358   T-26-0185_Operator_1 0.0007846214  -2.58714130  0.3926379
#> Y359   T-26-0185_Operator_2 0.0007861635  -3.36330037  0.3946541
#> Y360   T-26-0186_Operator_1 0.0005844535   1.38670509  0.3343074
#> Y361   T-26-0186_Operator_2 0.0005849664   2.48782444  0.3198304
#> Y362   T-26-0187_Operator_1 0.0005662514   4.32412019  0.3032276
#> Y363   T-26-0187_Operator_2 0.0005622716   4.95566904  0.3009559
#> Y364   T-26-0188_Operator_1 0.0008007476   1.77108183  0.3882957
#> Y365   T-26-0188_Operator_2 0.0007998931   1.87268977  0.3758166
#> Y366   T-26-0189_Operator_1 0.0007335858  -1.74463450  0.3673435
#> Y367   T-26-0189_Operator_2 0.0007342144  -1.86686773  0.3711454
#> Y368   T-26-0190_Operator_1 0.0006799640 -89.70847800  0.4980737
#> Y369   T-26-0190_Operator_2 0.0006821282   0.42606644  0.3325375
#> Y370   T-26-0191_Operator_1 0.0006657790   2.87382242  0.3243455
#> Y371   T-26-0191_Operator_2 0.0006664445   3.30920808  0.3170610
#> Y372   T-26-0192_Operator_1 0.0006279435  -3.76558311  0.4021457
#> Y373   T-26-0192_Operator_2 0.0006297229  -3.44840395  0.3966203
#> Y374   T-26-0193_Operator_1 0.0006700917  -2.24618713  0.3497875
#> Y375   T-26-0193_Operator_2 0.0006751433  -3.87590479  0.3452794
#> Y376   T-26-0194_Operator_1 0.0005078720   2.51331047  0.3072626
#> Y377   T-26-0194_Operator_2 0.0005024285   2.76973810  0.2992798
#> Y378   T-26-0195_Operator_1 0.0006170935  -5.03830550  0.3943740
#> Y379   T-26-0195_Operator_2 0.0006195787  -4.60369517  0.3811444
#> Y380   T-26-0196_Operator_1 0.0008203445   1.41705249  0.3628655
#> Y381   T-26-0196_Operator_2 0.0008172158   2.58323382  0.3529012
#> Y382   T-26-0197_Operator_1 0.0006430868   0.87483963  0.3446945
#> Y383   T-26-0197_Operator_2 0.0006462733   1.48028903  0.3381085
#> Y384   T-26-0198_Operator_1 0.0006839945   0.34009759  0.3396033
#> Y385   T-26-0198_Operator_2 0.0006876789  -0.19169058  0.3408023
#> Y386   T-26-0199_Operator_1 0.0008892841  -1.36324688  0.4121094
#> Y387   T-26-0199_Operator_2 0.0008867874  -1.99951040  0.4222580
#> Y388   T-26-0200_Operator_1 0.0006265664   1.13708197  0.2910401
#> Y389   T-26-0200_Operator_2 0.0006274837   0.72997589  0.2825769
#> Y390   T-26-0201_Operator_1 0.0007560482   1.93633955  0.3143902
#> Y391   T-26-0201_Operator_2 0.0007583421   2.36693289  0.3135745
#> Y392   T-26-0202_Operator_1 0.0005440696   3.74916360  0.2864527
#> Y393   T-26-0202_Operator_2 0.0005425936   5.28953039  0.2620727
#> Y394   T-26-0203_Operator_1 0.0006548788  -0.12292215  0.3503602
#> Y395   T-26-0203_Operator_2 0.0006520320  -0.02196643  0.3497066
#> Y396   T-26-0204_Operator_1 0.0006311139   0.39948703  0.3248659
#> Y397   T-26-0204_Operator_2 0.0006315125   0.57959284  0.3187559
#> Y398   T-26-0205_Operator_1 0.0006915629   1.60080197  0.3433610
#> Y399   T-26-0205_Operator_2 0.0006901311   2.35585018  0.3433402
#> Y400   T-26-0206_Operator_1 0.0007629703   0.89932196  0.3414296
#> Y401   T-26-0206_Operator_2 0.0007606489   0.96718317  0.3425457
#> Y402   T-26-0207_Operator_1 0.0009032061   0.15165602  0.3544330
#> Y403   T-26-0207_Operator_2 0.0009049774   0.70354335  0.3502262
#> Y404   T-26-0208_Operator_1 0.0007764982  -0.25385067  0.3994435
#> Y405   T-26-0208_Operator_2 0.0007867821   0.02653811  0.3929976
#> Y406   T-26-0209_Operator_1 0.0005845673 -88.94721314  0.4997077
#> Y407   T-26-0209_Operator_2 0.0005845673   1.89548377  0.3617498
#> Y408   T-26-0210_Operator_1 0.0010695187  -0.90995810  0.3909091
#> Y409   T-26-0210_Operator_2 0.0010799136   0.35845552  0.3788693
#> Y410   T-26-0211_Operator_1 0.0007518797  -0.25612605  0.3614038
#> Y411   T-26-0211_Operator_2 0.0007564297   0.12910248  0.3569085
#> Y412   T-26-0212_Operator_1 0.0008605852   6.87010893  0.2683589
#> Y413   T-26-0212_Operator_2 0.0008593524   7.29396634  0.2722716
#> Y414   T-26-0213_Operator_1 0.0007682456   4.05811438  0.3124198
#> Y415   T-26-0213_Operator_2 0.0007664791   3.79690602  0.3148953
#> Y416   T-26-0214_Operator_1 0.0004654048   3.71997644  0.2743564
#> Y417   T-26-0214_Operator_2 0.0004622497   3.67006189  0.2769645
#> Y418   T-26-0215_Operator_1 0.0007543373   2.16217280  0.3143071
#> Y419   T-26-0215_Operator_2 0.0007511269   1.80499534  0.3201051
#> Y420   T-26-0216_Operator_1 0.0008045052   0.59707985  0.3326629
#> Y421   T-26-0216_Operator_2 0.0008084074   0.48459300  0.3282134
#> Y422   T-26-0217_Operator_1 0.0006011422  -3.30696326  0.3818756
#> Y423   T-26-0217_Operator_2 0.0006005404  -4.67390439  0.3946052
#> Y424   T-26-0218_Operator_1 0.0008007476   2.47055528  0.3293070
#> Y425   T-26-0218_Operator_2 0.0007967067   2.63453067  0.3275130
#> Y426   T-26-0219_Operator_1 0.0011829644  -2.28615255  0.3655360
#> Y427   T-26-0219_Operator_2 0.0011890606  -1.61812266  0.3618704
#> Y428   T-26-0220_Operator_1 0.0008322930   2.74589483  0.3218893
#> Y429   T-26-0220_Operator_2 0.0008368201   3.65577450  0.3200837
#> Y430   T-26-0221_Operator_1 0.0007135212  -6.44714719  0.3857174
#> Y431   T-26-0221_Operator_2 0.0007135212  -5.73727054  0.3861934
#> Y432   T-26-0222_Operator_1 0.0002917153   4.45824115  0.2679405
#> Y433   T-26-0222_Operator_2 0.0002914319   4.62809115  0.2644743
#> Y434   T-26-0223_Operator_1 0.0006015038  -2.11265794  0.3571429
#> Y435   T-26-0223_Operator_2 0.0006033183  -0.58442490  0.3573152
#> Y436   T-26-0224_Operator_1 0.0006113714  -0.01996136  0.3376809
#> Y437   T-26-0224_Operator_2 0.0006148171   0.06071610  0.3453735
#> Y438   T-26-0225_Operator_1 0.0005310674  -1.35815232  0.3616569
#> Y439   T-26-0225_Operator_2 0.0005329070  -1.51824176  0.3711255
#> Y440   T-26-0226_Operator_1 0.0010443864  -1.57174591  0.4013055
#> Y441   T-26-0226_Operator_2 0.0010438413  -1.50835844  0.4027484
#> Y442   T-26-0227_Operator_1 0.0007249876  -0.52193511  0.3717983
#> Y443   T-26-0227_Operator_2 0.0007221953   0.98343383  0.3578481
#> Y444   T-26-0228_Operator_1 0.0006495615  -2.70505175  0.3866515
#> Y445   T-26-0228_Operator_2 0.0006529546  -2.88285720  0.3854065
#> Y446   T-26-0229_Operator_1 0.0005492996  -3.23621854  0.3645976
#> Y447   T-26-0229_Operator_2 0.0005522320  -3.07146212  0.3682927
#> Y448 T-26-0230-1_Operator_1 0.0008045052   2.18339344  0.3781175
#> Y449 T-26-0230-1_Operator_2 0.0043352539  45.00000000 -0.1481205
#> Y450 T-26-0230-2_Operator_1 0.0008940545  -3.77929157  0.4490389
#> Y451 T-26-0230-2_Operator_2 0.0008924587  -4.29570383  0.4477912
#> Y452 T-26-0230-3_Operator_1 0.0008631852  -4.53379115  0.4335347
#> Y453 T-26-0230-3_Operator_2 0.0008646779  -5.19442891  0.4335642
#> Y454 T-26-0230-4_Operator_1 0.0008368201  -3.75128791  0.4179916
#> Y455 T-26-0230-4_Operator_2 0.0008460237  -3.28901319  0.4183587
#> Y456   T-26-0231_Operator_1 0.0008133388  -0.34287372  0.4082285
#> Y457   T-26-0231_Operator_2 0.0008182188  -0.45113855  0.4090411
#> Y458   T-26-0232_Operator_1 0.0008992806  -2.32683345  0.4091727
#> Y459   T-26-0232_Operator_2 0.0009090909  -2.10753366  0.3995455
#> Y460   T-26-0233_Operator_1 0.0009886307  -1.27348362  0.4082224
#> Y461   T-26-0233_Operator_2 0.0009899353  -1.15632927  0.4021617
#> Y462   T-26-0234_Operator_1 0.0002971916  -0.41747189  0.3749320
#> Y463   T-26-0234_Operator_2 0.0002987750  -0.05026826  0.3758590
#> Y464   T-26-0235_Operator_1 0.0008233841   2.21899462  0.3522026
#> Y465   T-26-0235_Operator_2 0.0008156607   2.52599512  0.3584829
#> Y466   T-26-0236_Operator_1 0.0003565910   0.20510088  0.3416140
#> Y467   T-26-0236_Operator_2 0.0003568879   0.71148753  0.3381513
#> Y468   T-26-0237_Operator_1 0.0003573343   0.71889809  0.3375916
#> Y469   T-26-0237_Operator_2 0.0003571429   1.37732499  0.3330357
#> Y470   T-26-0238_Operator_1 0.0004730369   0.14480790  0.3502838
#> Y471   T-26-0238_Operator_2 0.0004732608   0.69221654  0.3407478
#> Y472   T-26-0239_Operator_1 0.0005236973  -4.06310496  0.4101859
#> Y473   T-26-0239_Operator_2 0.0005256242  -4.03329654  0.4061761
#> Y474   T-26-0240_Operator_1 0.0007814533   0.71715589  0.3710602
#> Y475   T-26-0240_Operator_2 0.0007796256   1.36839773  0.3699327
#> Y476   T-26-0241_Operator_1 0.0011428571  -0.86329573  0.3925714
#> Y477   T-26-0241_Operator_2 0.0011456945  -1.38751575  0.3951689
#> Y478   T-26-0242_Operator_1 0.0003497115  -4.30614712  0.3545784
#> Y479   T-26-0242_Operator_2 0.0003519680  -3.78274255  0.3523494
#> Y480   T-26-0243_Operator_1 0.0011527378  -1.18552449  0.3720461
#> Y481   T-26-0243_Operator_2 0.0011565146  -1.19108873  0.3745182
#> Y482   T-26-0244_Operator_1 0.0014727541  -1.93805517  0.4003432
#> Y483   T-26-0244_Operator_2 0.0014771049  -1.89268289  0.3993102
#> Y484   T-26-0245_Operator_1 0.0007923930   1.65831351  0.3387480
#> Y485   T-26-0245_Operator_2 0.0007903052   1.79644303  0.3317970
#> Y486   T-26-0246_Operator_1 0.0008061266  -2.64338261  0.3903668
#> Y487   T-26-0246_Operator_2 0.0008159935  -3.38053432  0.3820889
#> Y488   T-26-0247_Operator_1 0.0011587486  -1.57534089  0.3868285
#> Y489   T-26-0247_Operator_2 0.0011461318  -2.07191300  0.4191977
#> Y490   T-26-0248_Operator_1 0.0015822785  -2.92366660  0.3976804
#> Y491   T-26-0248_Operator_2 0.0015923567  -2.87417348  0.3954347
#> Y492   T-26-0249_Operator_1 0.0015128593   3.20125096  0.3789713
#> Y493   T-26-0249_Operator_2 0.0015090536   3.12597419  0.3870730
#> Y494   T-26-0250_Operator_1 0.0015885624  -8.91933398  0.3843002
#> Y495   T-26-0250_Operator_2 0.0015961692  -9.30851801  0.3789577
#> Y496   T-26-0251_Operator_1 0.0010362694  -6.64864518  0.4227979
#> Y497   T-26-0251_Operator_2 0.0010346611  -6.54746652  0.4156751
#> Y498   T-26-0252_Operator_1 0.0015015015 -10.78192163  0.4166667
#> Y499   T-26-0252_Operator_2 0.0014973803 -10.44674673  0.4139006
#> Y500 T-26-0261-1_Operator_1 0.0008238366  -8.40939712  0.4147329
#> Y501 T-26-0261-1_Operator_2 0.0008288438  -7.73843809  0.4034397
#> Y502 T-26-0261-2_Operator_1 0.0009316764  -0.60825814  0.3697209
#> Y503 T-26-0261-2_Operator_2 0.0009447331  -0.54749781  0.3729334
#> Y504 T-26-0261-3_Operator_1 0.0009367681   1.68177635  0.3449649
#> Y505 T-26-0261-3_Operator_2 0.0009442871   0.86492177  0.3575703
#> Y506 T-26-0261-4_Operator_1 0.0012586532  -4.49910674  0.3659534
#> Y507 T-26-0261-4_Operator_2 0.0012634239  -4.78915345  0.3622868
#> Y508 T-26-0261-5_Operator_1 0.0008971289  -0.56504936  0.3730563
#> Y509 T-26-0261-5_Operator_2 0.0009100564  -0.09306291  0.3657667
#> Y510 T-26-0262-1_Operator_1 0.0010666667  -6.38738112  0.3821333
#> Y511 T-26-0262-1_Operator_2 0.0010598834  -6.82957021  0.3802332
#> Y512 T-26-0262-2_Operator_1 0.0011185682  -2.42600988  0.3517897
#> Y513 T-26-0262-2_Operator_2 0.0011252809  -2.15751201  0.3531508
#> Y514   T-26-0263_Operator_1 0.0008696915  -2.56157440  0.4363673
#> Y515   T-26-0263_Operator_2 0.0008773215  -2.27204864  0.4346395
#> Y516 T-26-0264-1_Operator_1 0.0008493766   0.78894780  0.4186017
#> Y517 T-26-0264-1_Operator_2 0.0008616975  -0.03028853  0.4254632
#> Y518 T-26-0264-2_Operator_1 0.0008865248   5.51047444  0.3420505
#> Y519 T-26-0264-2_Operator_2 0.0009160303   5.91420495  0.3282443
#> Y520 T-26-0264-3_Operator_1 0.0008484160   5.36738087  0.3499720
#> Y521 T-26-0264-3_Operator_2 0.0008615736   5.77163006  0.3453475
#> Y522 T-26-0264-4_Operator_1 0.0010021717 -13.58896463  0.4470523
#> Y523 T-26-0264-4_Operator_2 0.0009948596 -12.78617204  0.4384848
#> Y524   T-26-0265_Operator_1 0.0004808848  -0.11501862  0.3776148
#> Y525   T-26-0265_Operator_2 0.0004825090   0.18084691  0.3757539
#> Y526   T-26-0266_Operator_1 0.0004473272  -0.01487043  0.3834713
#> Y527   T-26-0266_Operator_2 0.0004463289  -0.37233541  0.3889386
#> Y528   T-26-0267_Operator_1 0.0002286498  -0.27912141  0.3588087
#> Y529   T-26-0267_Operator_2 0.0002289377   0.78149905  0.3499313
#> Y530   T-26-0268_Operator_1 0.0005411255  -0.09445389  0.3985390
#> Y531   T-26-0268_Operator_2 0.0005451077   1.44665053  0.3852548
#> Y532   T-26-0269_Operator_1 0.0005213764   4.18318563  0.3063087
#> Y533   T-26-0269_Operator_2 0.0005319149   5.07362080  0.2875000
#> Y534 T-26-0270-1_Operator_1 0.0004681648   1.91504877  0.3696161
#> Y535 T-26-0270-1_Operator_2 0.0004766774   3.62322265  0.3364201
#> Y536 T-26-0270-2_Operator_1 0.0004311274  -8.79933646  0.3941582
#> Y537 T-26-0270-2_Operator_2 0.0004376687  -9.06384708  0.3899263
#> Y538   T-26-0271_Operator_1 0.0004005608  -4.11462635  0.3872421
#> Y539   T-26-0271_Operator_2 0.0004016871  -3.79404517  0.3869251
#> Y540   T-26-0272_Operator_1 0.0005778677  -3.45348404  0.4205432
#> Y541   T-26-0272_Operator_2 0.0005813389  -3.95583310  0.4097954
#> Y542   T-26-0273_Operator_1 0.0004362050  -2.13526395  0.3968375
#> Y543   T-26-0273_Operator_2 0.0004401085  -1.40366522  0.3871122
#> Y544   T-26-0274_Operator_1 0.0005492996  -6.33228397  0.4112881
#> Y545   T-26-0274_Operator_2 0.0005575690  -6.19648121  0.4090231
#> Y546   T-26-0275_Operator_1 0.0005952381   0.83879554  0.4002976
#> Y547   T-26-0275_Operator_2 0.0006016847   1.24837872  0.3913959
#> Y548   T-26-0276_Operator_1 0.0006343165  -1.53612961  0.3975579
#> Y549   T-26-0276_Operator_2 0.0006344505  -2.15898171  0.3962673
#> Y550   T-26-0277_Operator_1 0.0005574136   7.81897769  0.3252508
#> Y551   T-26-0277_Operator_2 0.0005681818   7.83692079  0.3218750
#> Y552 T-26-0278-1_Operator_1 0.0006491399  -2.54046740  0.3743914
#> Y553 T-26-0278-1_Operator_2 0.0006538084  -3.57310534  0.3717444
#> Y554 T-26-0278-2_Operator_1 0.0006351223  -3.52702993  0.4368053
#> Y555 T-26-0278-2_Operator_2 0.0006412312  -3.36646066  0.4338461
#> Y556   T-26-0279_Operator_1 0.0006375518  -2.02676844  0.3970354
#> Y557   T-26-0279_Operator_2 0.0006441224  -2.50417339  0.3987652
#>      scale_bar_placed
#> Y                TRUE
#> Y1               TRUE
#> Y2               TRUE
#> Y3               TRUE
#> Y4               TRUE
#> Y5               TRUE
#> Y6               TRUE
#> Y7               TRUE
#> Y8               TRUE
#> Y9               TRUE
#> Y10              TRUE
#> Y11              TRUE
#> Y12              TRUE
#> Y13              TRUE
#> Y14              TRUE
#> Y15              TRUE
#> Y16              TRUE
#> Y17              TRUE
#> Y18              TRUE
#> Y19              TRUE
#> Y20              TRUE
#> Y21              TRUE
#> Y22              TRUE
#> Y23              TRUE
#> Y24              TRUE
#> Y25              TRUE
#> Y26              TRUE
#> Y27              TRUE
#> Y28              TRUE
#> Y29              TRUE
#> Y30              TRUE
#> Y31              TRUE
#> Y32              TRUE
#> Y33              TRUE
#> Y34              TRUE
#> Y35              TRUE
#> Y36              TRUE
#> Y37              TRUE
#> Y38              TRUE
#> Y39              TRUE
#> Y40              TRUE
#> Y41              TRUE
#> Y42              TRUE
#> Y43              TRUE
#> Y44              TRUE
#> Y45              TRUE
#> Y46              TRUE
#> Y47              TRUE
#> Y48              TRUE
#> Y49              TRUE
#> Y50              TRUE
#> Y51              TRUE
#> Y52              TRUE
#> Y53              TRUE
#> Y54              TRUE
#> Y55              TRUE
#> Y56              TRUE
#> Y57              TRUE
#> Y58              TRUE
#> Y59              TRUE
#> Y60              TRUE
#> Y61              TRUE
#> Y62              TRUE
#> Y63              TRUE
#> Y64              TRUE
#> Y65              TRUE
#> Y66              TRUE
#> Y67              TRUE
#> Y68              TRUE
#> Y69              TRUE
#> Y70              TRUE
#> Y71              TRUE
#> Y72              TRUE
#> Y73              TRUE
#> Y74              TRUE
#> Y75              TRUE
#> Y76              TRUE
#> Y77              TRUE
#> Y78              TRUE
#> Y79              TRUE
#> Y80              TRUE
#> Y81              TRUE
#> Y82              TRUE
#> Y83              TRUE
#> Y84              TRUE
#> Y85              TRUE
#> Y86              TRUE
#> Y87              TRUE
#> Y88              TRUE
#> Y89              TRUE
#> Y90              TRUE
#> Y91              TRUE
#> Y92              TRUE
#> Y93              TRUE
#> Y94              TRUE
#> Y95              TRUE
#> Y96              TRUE
#> Y97              TRUE
#> Y98              TRUE
#> Y99              TRUE
#> Y100             TRUE
#> Y101             TRUE
#> Y102             TRUE
#> Y103             TRUE
#> Y104             TRUE
#> Y105             TRUE
#> Y106             TRUE
#> Y107             TRUE
#> Y108             TRUE
#> Y109             TRUE
#> Y110             TRUE
#> Y111             TRUE
#> Y112             TRUE
#> Y113             TRUE
#> Y114             TRUE
#> Y115            FALSE
#> Y116             TRUE
#> Y117             TRUE
#> Y118             TRUE
#> Y119             TRUE
#> Y120             TRUE
#> Y121             TRUE
#> Y122             TRUE
#> Y123             TRUE
#> Y124             TRUE
#> Y125             TRUE
#> Y126             TRUE
#> Y127             TRUE
#> Y128             TRUE
#> Y129             TRUE
#> Y130             TRUE
#> Y131             TRUE
#> Y132             TRUE
#> Y133             TRUE
#> Y134             TRUE
#> Y135             TRUE
#> Y136             TRUE
#> Y137             TRUE
#> Y138             TRUE
#> Y139             TRUE
#> Y140             TRUE
#> Y141             TRUE
#> Y142             TRUE
#> Y143             TRUE
#> Y144             TRUE
#> Y145             TRUE
#> Y146             TRUE
#> Y147             TRUE
#> Y148             TRUE
#> Y149             TRUE
#> Y150             TRUE
#> Y151             TRUE
#> Y152             TRUE
#> Y153             TRUE
#> Y154             TRUE
#> Y155             TRUE
#> Y156             TRUE
#> Y157             TRUE
#> Y158             TRUE
#> Y159             TRUE
#> Y160             TRUE
#> Y161             TRUE
#> Y162             TRUE
#> Y163             TRUE
#> Y164             TRUE
#> Y165             TRUE
#> Y166             TRUE
#> Y167             TRUE
#> Y168             TRUE
#> Y169             TRUE
#> Y170             TRUE
#> Y171             TRUE
#> Y172             TRUE
#> Y173             TRUE
#> Y174             TRUE
#> Y175             TRUE
#> Y176             TRUE
#> Y177             TRUE
#> Y178             TRUE
#> Y179             TRUE
#> Y180             TRUE
#> Y181             TRUE
#> Y182             TRUE
#> Y183             TRUE
#> Y184             TRUE
#> Y185             TRUE
#> Y186             TRUE
#> Y187             TRUE
#> Y188             TRUE
#> Y189             TRUE
#> Y190             TRUE
#> Y191             TRUE
#> Y192             TRUE
#> Y193             TRUE
#> Y194             TRUE
#> Y195             TRUE
#> Y196             TRUE
#> Y197             TRUE
#> Y198             TRUE
#> Y199             TRUE
#> Y200             TRUE
#> Y201             TRUE
#> Y202             TRUE
#> Y203             TRUE
#> Y204             TRUE
#> Y205             TRUE
#> Y206             TRUE
#> Y207            FALSE
#> Y208             TRUE
#> Y209             TRUE
#> Y210             TRUE
#> Y211             TRUE
#> Y212             TRUE
#> Y213             TRUE
#> Y214             TRUE
#> Y215             TRUE
#> Y216             TRUE
#> Y217             TRUE
#> Y218             TRUE
#> Y219             TRUE
#> Y220             TRUE
#> Y221             TRUE
#> Y222             TRUE
#> Y223             TRUE
#> Y224             TRUE
#> Y225             TRUE
#> Y226             TRUE
#> Y227             TRUE
#> Y228             TRUE
#> Y229             TRUE
#> Y230             TRUE
#> Y231             TRUE
#> Y232             TRUE
#> Y233             TRUE
#> Y234             TRUE
#> Y235             TRUE
#> Y236             TRUE
#> Y237             TRUE
#> Y238             TRUE
#> Y239             TRUE
#> Y240             TRUE
#> Y241             TRUE
#> Y242             TRUE
#> Y243             TRUE
#> Y244             TRUE
#> Y245             TRUE
#> Y246             TRUE
#> Y247             TRUE
#> Y248             TRUE
#> Y249             TRUE
#> Y250             TRUE
#> Y251             TRUE
#> Y252             TRUE
#> Y253             TRUE
#> Y254             TRUE
#> Y255             TRUE
#> Y256             TRUE
#> Y257             TRUE
#> Y258             TRUE
#> Y259             TRUE
#> Y260             TRUE
#> Y261             TRUE
#> Y262             TRUE
#> Y263             TRUE
#> Y264             TRUE
#> Y265             TRUE
#> Y266             TRUE
#> Y267             TRUE
#> Y268             TRUE
#> Y269             TRUE
#> Y270             TRUE
#> Y271             TRUE
#> Y272             TRUE
#> Y273             TRUE
#> Y274             TRUE
#> Y275             TRUE
#> Y276             TRUE
#> Y277             TRUE
#> Y278             TRUE
#> Y279             TRUE
#> Y280             TRUE
#> Y281             TRUE
#> Y282             TRUE
#> Y283             TRUE
#> Y284             TRUE
#> Y285             TRUE
#> Y286             TRUE
#> Y287             TRUE
#> Y288             TRUE
#> Y289             TRUE
#> Y290             TRUE
#> Y291             TRUE
#> Y292             TRUE
#> Y293             TRUE
#> Y294             TRUE
#> Y295             TRUE
#> Y296             TRUE
#> Y297             TRUE
#> Y298             TRUE
#> Y299             TRUE
#> Y300             TRUE
#> Y301             TRUE
#> Y302             TRUE
#> Y303             TRUE
#> Y304             TRUE
#> Y305             TRUE
#> Y306             TRUE
#> Y307             TRUE
#> Y308             TRUE
#> Y309             TRUE
#> Y310             TRUE
#> Y311             TRUE
#> Y312             TRUE
#> Y313             TRUE
#> Y314             TRUE
#> Y315             TRUE
#> Y316             TRUE
#> Y317             TRUE
#> Y318             TRUE
#> Y319             TRUE
#> Y320             TRUE
#> Y321             TRUE
#> Y322             TRUE
#> Y323             TRUE
#> Y324             TRUE
#> Y325             TRUE
#> Y326             TRUE
#> Y327             TRUE
#> Y328             TRUE
#> Y329             TRUE
#> Y330             TRUE
#> Y331             TRUE
#> Y332             TRUE
#> Y333             TRUE
#> Y334             TRUE
#> Y335             TRUE
#> Y336             TRUE
#> Y337             TRUE
#> Y338             TRUE
#> Y339             TRUE
#> Y340             TRUE
#> Y341             TRUE
#> Y342             TRUE
#> Y343             TRUE
#> Y344             TRUE
#> Y345             TRUE
#> Y346             TRUE
#> Y347             TRUE
#> Y348             TRUE
#> Y349             TRUE
#> Y350             TRUE
#> Y351             TRUE
#> Y352             TRUE
#> Y353             TRUE
#> Y354             TRUE
#> Y355             TRUE
#> Y356             TRUE
#> Y357             TRUE
#> Y358             TRUE
#> Y359             TRUE
#> Y360             TRUE
#> Y361             TRUE
#> Y362             TRUE
#> Y363             TRUE
#> Y364             TRUE
#> Y365             TRUE
#> Y366             TRUE
#> Y367             TRUE
#> Y368             TRUE
#> Y369             TRUE
#> Y370             TRUE
#> Y371             TRUE
#> Y372             TRUE
#> Y373             TRUE
#> Y374             TRUE
#> Y375             TRUE
#> Y376             TRUE
#> Y377             TRUE
#> Y378             TRUE
#> Y379             TRUE
#> Y380             TRUE
#> Y381             TRUE
#> Y382             TRUE
#> Y383             TRUE
#> Y384             TRUE
#> Y385             TRUE
#> Y386             TRUE
#> Y387             TRUE
#> Y388             TRUE
#> Y389             TRUE
#> Y390             TRUE
#> Y391             TRUE
#> Y392             TRUE
#> Y393             TRUE
#> Y394             TRUE
#> Y395             TRUE
#> Y396             TRUE
#> Y397             TRUE
#> Y398             TRUE
#> Y399             TRUE
#> Y400             TRUE
#> Y401             TRUE
#> Y402             TRUE
#> Y403             TRUE
#> Y404             TRUE
#> Y405             TRUE
#> Y406             TRUE
#> Y407             TRUE
#> Y408             TRUE
#> Y409             TRUE
#> Y410             TRUE
#> Y411             TRUE
#> Y412             TRUE
#> Y413             TRUE
#> Y414             TRUE
#> Y415             TRUE
#> Y416             TRUE
#> Y417             TRUE
#> Y418             TRUE
#> Y419             TRUE
#> Y420             TRUE
#> Y421             TRUE
#> Y422             TRUE
#> Y423             TRUE
#> Y424             TRUE
#> Y425             TRUE
#> Y426             TRUE
#> Y427             TRUE
#> Y428             TRUE
#> Y429             TRUE
#> Y430             TRUE
#> Y431             TRUE
#> Y432             TRUE
#> Y433             TRUE
#> Y434             TRUE
#> Y435             TRUE
#> Y436             TRUE
#> Y437             TRUE
#> Y438             TRUE
#> Y439             TRUE
#> Y440             TRUE
#> Y441             TRUE
#> Y442             TRUE
#> Y443             TRUE
#> Y444             TRUE
#> Y445             TRUE
#> Y446             TRUE
#> Y447             TRUE
#> Y448             TRUE
#> Y449             TRUE
#> Y450             TRUE
#> Y451             TRUE
#> Y452             TRUE
#> Y453             TRUE
#> Y454             TRUE
#> Y455             TRUE
#> Y456             TRUE
#> Y457             TRUE
#> Y458             TRUE
#> Y459             TRUE
#> Y460            FALSE
#> Y461             TRUE
#> Y462             TRUE
#> Y463             TRUE
#> Y464             TRUE
#> Y465             TRUE
#> Y466             TRUE
#> Y467             TRUE
#> Y468             TRUE
#> Y469             TRUE
#> Y470             TRUE
#> Y471             TRUE
#> Y472             TRUE
#> Y473             TRUE
#> Y474             TRUE
#> Y475             TRUE
#> Y476             TRUE
#> Y477             TRUE
#> Y478             TRUE
#> Y479             TRUE
#> Y480             TRUE
#> Y481             TRUE
#> Y482             TRUE
#> Y483             TRUE
#> Y484             TRUE
#> Y485             TRUE
#> Y486             TRUE
#> Y487             TRUE
#> Y488             TRUE
#> Y489             TRUE
#> Y490             TRUE
#> Y491             TRUE
#> Y492             TRUE
#> Y493             TRUE
#> Y494             TRUE
#> Y495             TRUE
#> Y496             TRUE
#> Y497             TRUE
#> Y498             TRUE
#> Y499             TRUE
#> Y500             TRUE
#> Y501             TRUE
#> Y502             TRUE
#> Y503             TRUE
#> Y504             TRUE
#> Y505             TRUE
#> Y506             TRUE
#> Y507             TRUE
#> Y508             TRUE
#> Y509             TRUE
#> Y510             TRUE
#> Y511             TRUE
#> Y512             TRUE
#> Y513             TRUE
#> Y514             TRUE
#> Y515             TRUE
#> Y516             TRUE
#> Y517             TRUE
#> Y518             TRUE
#> Y519             TRUE
#> Y520             TRUE
#> Y521             TRUE
#> Y522             TRUE
#> Y523             TRUE
#> Y524             TRUE
#> Y525             TRUE
#> Y526             TRUE
#> Y527             TRUE
#> Y528             TRUE
#> Y529             TRUE
#> Y530             TRUE
#> Y531             TRUE
#> Y532             TRUE
#> Y533             TRUE
#> Y534             TRUE
#> Y535             TRUE
#> Y536             TRUE
#> Y537             TRUE
#> Y538             TRUE
#> Y539             TRUE
#> Y540             TRUE
#> Y541             TRUE
#> Y542             TRUE
#> Y543             TRUE
#> Y544             TRUE
#> Y545             TRUE
#> Y546             TRUE
#> Y547             TRUE
#> Y548             TRUE
#> Y549             TRUE
#> Y550             TRUE
#> Y551             TRUE
#> Y552             TRUE
#> Y553             TRUE
#> Y554             TRUE
#> Y555             TRUE
#> Y556             TRUE
#> Y557             TRUE

# equivalent to the pre-existing two-call workflow:
fish_std2 <- standardize_geometry(standardize_orientation(fish), orient = FALSE)
#> standardize_orientation(): 557 of 558 specimen(s) mirrored (165 horizontally, 555 vertically) to a consistent head-left, belly-down orientation.
#> standardize_geometry(): standardized 558 specimen(s) (isotropic rescale + scale bar + rotation); no landmark coordinate value was corrected (see correct_geometry_conventions() for that).

# then, only if/where desired, actively correct remaining conventions:
fish_corrected <- correct_geometry_conventions(fish_std)
#> correct_geometry_conventions(): corrected 6804 landmark coordinate(s) across 558 specimen(s).
```
