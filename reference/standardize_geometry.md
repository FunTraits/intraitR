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
#> standardize_orientation(): 1006 of 1036 specimen(s) mirrored (234 horizontally, 1004 vertically) to a consistent head-left, belly-down orientation.
#> standardize_geometry(): standardized 1036 specimen(s) (isotropic rescale + scale bar + rotation); no landmark coordinate value was corrected (see correct_geometry_conventions() for that).
attr(fish_std$coords, "orientation_log")
#>                    specimen flipped_x flipped_y
#> 1      T-26-0001_Operator_1     FALSE      TRUE
#> 2      T-26-0001_Operator_2     FALSE      TRUE
#> 3      T-26-0001_Operator_3     FALSE      TRUE
#> 4      T-26-0001_Operator_4     FALSE      TRUE
#> 5      T-26-0002_Operator_1     FALSE      TRUE
#> 6      T-26-0002_Operator_2     FALSE      TRUE
#> 7      T-26-0002_Operator_3     FALSE      TRUE
#> 8      T-26-0002_Operator_4     FALSE      TRUE
#> 9      T-26-0003_Operator_1     FALSE      TRUE
#> 10     T-26-0003_Operator_2     FALSE      TRUE
#> 11     T-26-0003_Operator_3     FALSE      TRUE
#> 12     T-26-0003_Operator_4     FALSE      TRUE
#> 13     T-26-0004_Operator_1     FALSE      TRUE
#> 14     T-26-0004_Operator_2     FALSE      TRUE
#> 15     T-26-0004_Operator_3     FALSE      TRUE
#> 16     T-26-0004_Operator_4     FALSE      TRUE
#> 17     T-26-0005_Operator_1     FALSE      TRUE
#> 18     T-26-0005_Operator_2     FALSE      TRUE
#> 19     T-26-0005_Operator_3     FALSE      TRUE
#> 20     T-26-0005_Operator_4     FALSE      TRUE
#> 21     T-26-0006_Operator_1     FALSE      TRUE
#> 22     T-26-0006_Operator_2     FALSE      TRUE
#> 23     T-26-0006_Operator_3     FALSE      TRUE
#> 24     T-26-0006_Operator_4     FALSE      TRUE
#> 25     T-26-0007_Operator_1     FALSE      TRUE
#> 26     T-26-0007_Operator_2     FALSE      TRUE
#> 27     T-26-0007_Operator_3     FALSE      TRUE
#> 28     T-26-0007_Operator_4     FALSE      TRUE
#> 29     T-26-0008_Operator_1     FALSE      TRUE
#> 30     T-26-0008_Operator_2     FALSE      TRUE
#> 31     T-26-0008_Operator_3     FALSE      TRUE
#> 32     T-26-0008_Operator_4     FALSE      TRUE
#> 33     T-26-0009_Operator_1     FALSE      TRUE
#> 34     T-26-0009_Operator_2     FALSE      TRUE
#> 35     T-26-0009_Operator_3     FALSE      TRUE
#> 36     T-26-0009_Operator_4     FALSE      TRUE
#> 37     T-26-0010_Operator_1     FALSE      TRUE
#> 38     T-26-0010_Operator_2     FALSE      TRUE
#> 39     T-26-0010_Operator_3     FALSE      TRUE
#> 40     T-26-0010_Operator_4     FALSE      TRUE
#> 41     T-26-0011_Operator_1      TRUE      TRUE
#> 42     T-26-0011_Operator_2      TRUE      TRUE
#> 43     T-26-0011_Operator_3     FALSE     FALSE
#> 44     T-26-0011_Operator_4      TRUE      TRUE
#> 45     T-26-0012_Operator_1     FALSE      TRUE
#> 46     T-26-0012_Operator_2     FALSE      TRUE
#> 47     T-26-0012_Operator_3     FALSE      TRUE
#> 48     T-26-0012_Operator_4     FALSE      TRUE
#> 49     T-26-0013_Operator_1     FALSE      TRUE
#> 50     T-26-0013_Operator_2     FALSE      TRUE
#> 51     T-26-0013_Operator_3     FALSE      TRUE
#> 52     T-26-0013_Operator_4     FALSE      TRUE
#> 53     T-26-0014_Operator_1     FALSE      TRUE
#> 54     T-26-0014_Operator_2     FALSE      TRUE
#> 55     T-26-0014_Operator_3     FALSE      TRUE
#> 56     T-26-0014_Operator_4     FALSE      TRUE
#> 57     T-26-0015_Operator_1     FALSE      TRUE
#> 58     T-26-0015_Operator_2     FALSE      TRUE
#> 59     T-26-0015_Operator_3     FALSE      TRUE
#> 60     T-26-0015_Operator_4     FALSE      TRUE
#> 61     T-26-0016_Operator_1     FALSE      TRUE
#> 62     T-26-0016_Operator_2     FALSE      TRUE
#> 63     T-26-0016_Operator_3     FALSE      TRUE
#> 64     T-26-0016_Operator_4     FALSE      TRUE
#> 65     T-26-0017_Operator_1     FALSE      TRUE
#> 66     T-26-0017_Operator_2     FALSE      TRUE
#> 67     T-26-0017_Operator_3     FALSE      TRUE
#> 68     T-26-0017_Operator_4     FALSE      TRUE
#> 69     T-26-0018_Operator_1     FALSE      TRUE
#> 70     T-26-0018_Operator_2     FALSE      TRUE
#> 71     T-26-0018_Operator_3     FALSE      TRUE
#> 72     T-26-0018_Operator_4     FALSE      TRUE
#> 73     T-26-0019_Operator_1     FALSE      TRUE
#> 74     T-26-0019_Operator_2     FALSE      TRUE
#> 75     T-26-0019_Operator_3     FALSE      TRUE
#> 76     T-26-0019_Operator_4     FALSE      TRUE
#> 77     T-26-0020_Operator_1     FALSE      TRUE
#> 78     T-26-0020_Operator_2     FALSE      TRUE
#> 79     T-26-0020_Operator_3     FALSE      TRUE
#> 80     T-26-0020_Operator_4     FALSE      TRUE
#> 81     T-26-0021_Operator_1     FALSE      TRUE
#> 82     T-26-0021_Operator_2     FALSE      TRUE
#> 83     T-26-0021_Operator_3     FALSE      TRUE
#> 84     T-26-0021_Operator_4     FALSE      TRUE
#> 85     T-26-0022_Operator_1     FALSE      TRUE
#> 86     T-26-0022_Operator_2     FALSE      TRUE
#> 87     T-26-0022_Operator_3     FALSE      TRUE
#> 88     T-26-0022_Operator_4     FALSE      TRUE
#> 89   T-26-0023-2_Operator_1     FALSE      TRUE
#> 90   T-26-0023-2_Operator_2     FALSE      TRUE
#> 91     T-26-0023_Operator_3     FALSE      TRUE
#> 92     T-26-0023_Operator_4     FALSE      TRUE
#> 93     T-26-0024_Operator_1     FALSE      TRUE
#> 94     T-26-0024_Operator_2     FALSE      TRUE
#> 95     T-26-0024_Operator_3     FALSE      TRUE
#> 96     T-26-0024_Operator_4     FALSE      TRUE
#> 97     T-26-0025_Operator_1     FALSE      TRUE
#> 98     T-26-0025_Operator_2     FALSE      TRUE
#> 99     T-26-0025_Operator_3     FALSE      TRUE
#> 100    T-26-0025_Operator_4     FALSE      TRUE
#> 101    T-26-0026_Operator_1     FALSE      TRUE
#> 102    T-26-0026_Operator_2     FALSE      TRUE
#> 103    T-26-0026_Operator_3     FALSE      TRUE
#> 104    T-26-0026_Operator_4     FALSE      TRUE
#> 105    T-26-0027_Operator_1     FALSE      TRUE
#> 106    T-26-0027_Operator_2     FALSE      TRUE
#> 107    T-26-0027_Operator_3     FALSE      TRUE
#> 108    T-26-0027_Operator_4     FALSE      TRUE
#> 109    T-26-0028_Operator_1     FALSE      TRUE
#> 110    T-26-0028_Operator_2     FALSE      TRUE
#> 111    T-26-0028_Operator_3     FALSE      TRUE
#> 112    T-26-0028_Operator_4     FALSE      TRUE
#> 113    T-26-0029_Operator_1     FALSE      TRUE
#> 114    T-26-0029_Operator_2     FALSE      TRUE
#> 115    T-26-0029_Operator_3     FALSE      TRUE
#> 116    T-26-0029_Operator_4     FALSE      TRUE
#> 117    T-26-0030_Operator_1     FALSE      TRUE
#> 118    T-26-0030_Operator_2     FALSE      TRUE
#> 119    T-26-0030_Operator_3     FALSE      TRUE
#> 120    T-26-0030_Operator_4     FALSE      TRUE
#> 121    T-26-0031_Operator_1     FALSE      TRUE
#> 122    T-26-0031_Operator_2     FALSE      TRUE
#> 123    T-26-0031_Operator_3     FALSE      TRUE
#> 124    T-26-0031_Operator_4     FALSE      TRUE
#> 125    T-26-0032_Operator_1     FALSE      TRUE
#> 126    T-26-0032_Operator_2     FALSE      TRUE
#> 127    T-26-0032_Operator_3     FALSE      TRUE
#> 128    T-26-0032_Operator_4     FALSE      TRUE
#> 129    T-26-0033_Operator_1     FALSE      TRUE
#> 130    T-26-0033_Operator_2     FALSE      TRUE
#> 131    T-26-0033_Operator_3     FALSE      TRUE
#> 132    T-26-0033_Operator_4     FALSE      TRUE
#> 133    T-26-0034_Operator_1     FALSE      TRUE
#> 134    T-26-0034_Operator_2     FALSE      TRUE
#> 135    T-26-0034_Operator_3     FALSE      TRUE
#> 136    T-26-0034_Operator_4     FALSE      TRUE
#> 137    T-26-0035_Operator_1     FALSE      TRUE
#> 138    T-26-0035_Operator_2     FALSE      TRUE
#> 139    T-26-0035_Operator_3     FALSE      TRUE
#> 140    T-26-0035_Operator_4     FALSE      TRUE
#> 141    T-26-0036_Operator_1     FALSE      TRUE
#> 142    T-26-0036_Operator_2     FALSE      TRUE
#> 143    T-26-0036_Operator_4     FALSE      TRUE
#> 144    T-26-0037_Operator_1     FALSE      TRUE
#> 145    T-26-0037_Operator_2     FALSE      TRUE
#> 146    T-26-0037_Operator_4     FALSE      TRUE
#> 147    T-26-0038_Operator_1     FALSE      TRUE
#> 148    T-26-0038_Operator_2     FALSE      TRUE
#> 149    T-26-0038_Operator_4     FALSE      TRUE
#> 150    T-26-0039_Operator_1     FALSE      TRUE
#> 151    T-26-0039_Operator_2     FALSE      TRUE
#> 152    T-26-0039_Operator_4     FALSE      TRUE
#> 153    T-26-0040_Operator_1     FALSE      TRUE
#> 154    T-26-0040_Operator_2     FALSE      TRUE
#> 155    T-26-0040_Operator_3     FALSE      TRUE
#> 156    T-26-0040_Operator_4     FALSE      TRUE
#> 157    T-26-0041_Operator_1     FALSE      TRUE
#> 158    T-26-0041_Operator_2     FALSE      TRUE
#> 159    T-26-0041_Operator_3     FALSE      TRUE
#> 160    T-26-0041_Operator_4     FALSE      TRUE
#> 161    T-26-0042_Operator_1     FALSE      TRUE
#> 162    T-26-0042_Operator_2     FALSE      TRUE
#> 163    T-26-0042_Operator_3     FALSE      TRUE
#> 164    T-26-0042_Operator_4     FALSE      TRUE
#> 165    T-26-0043_Operator_1     FALSE      TRUE
#> 166    T-26-0043_Operator_2     FALSE      TRUE
#> 167    T-26-0043_Operator_3     FALSE      TRUE
#> 168    T-26-0043_Operator_4     FALSE      TRUE
#> 169    T-26-0044_Operator_1     FALSE      TRUE
#> 170    T-26-0044_Operator_2     FALSE      TRUE
#> 171    T-26-0044_Operator_3     FALSE      TRUE
#> 172    T-26-0044_Operator_4     FALSE      TRUE
#> 173    T-26-0045_Operator_1     FALSE      TRUE
#> 174    T-26-0045_Operator_2     FALSE      TRUE
#> 175    T-26-0045_Operator_3     FALSE      TRUE
#> 176    T-26-0045_Operator_4     FALSE      TRUE
#> 177    T-26-0046_Operator_1     FALSE      TRUE
#> 178    T-26-0046_Operator_2     FALSE      TRUE
#> 179    T-26-0046_Operator_3     FALSE      TRUE
#> 180    T-26-0046_Operator_4     FALSE      TRUE
#> 181    T-26-0047_Operator_1     FALSE      TRUE
#> 182    T-26-0047_Operator_2     FALSE      TRUE
#> 183    T-26-0047_Operator_3     FALSE      TRUE
#> 184    T-26-0047_Operator_4     FALSE      TRUE
#> 185    T-26-0048_Operator_1     FALSE      TRUE
#> 186    T-26-0048_Operator_2     FALSE      TRUE
#> 187    T-26-0048_Operator_3     FALSE      TRUE
#> 188    T-26-0048_Operator_4     FALSE      TRUE
#> 189    T-26-0049_Operator_1     FALSE      TRUE
#> 190    T-26-0049_Operator_2     FALSE      TRUE
#> 191    T-26-0049_Operator_3     FALSE      TRUE
#> 192    T-26-0049_Operator_4     FALSE      TRUE
#> 193    T-26-0050_Operator_1     FALSE      TRUE
#> 194    T-26-0050_Operator_2     FALSE      TRUE
#> 195    T-26-0050_Operator_4     FALSE      TRUE
#> 196    T-26-0051_Operator_1     FALSE      TRUE
#> 197    T-26-0051_Operator_2     FALSE      TRUE
#> 198    T-26-0051_Operator_3     FALSE      TRUE
#> 199    T-26-0051_Operator_4     FALSE      TRUE
#> 200    T-26-0052_Operator_1     FALSE     FALSE
#> 201    T-26-0052_Operator_2     FALSE      TRUE
#> 202    T-26-0052_Operator_3     FALSE      TRUE
#> 203    T-26-0052_Operator_4     FALSE      TRUE
#> 204    T-26-0053_Operator_1     FALSE      TRUE
#> 205    T-26-0053_Operator_2     FALSE      TRUE
#> 206    T-26-0053_Operator_3     FALSE      TRUE
#> 207    T-26-0053_Operator_4     FALSE      TRUE
#> 208    T-26-0054_Operator_1     FALSE      TRUE
#> 209    T-26-0054_Operator_2     FALSE      TRUE
#> 210    T-26-0054_Operator_3     FALSE      TRUE
#> 211    T-26-0054_Operator_4     FALSE      TRUE
#> 212    T-26-0055_Operator_1     FALSE      TRUE
#> 213    T-26-0055_Operator_2     FALSE      TRUE
#> 214    T-26-0055_Operator_3     FALSE      TRUE
#> 215    T-26-0055_Operator_4     FALSE      TRUE
#> 216  T-26-0056-2_Operator_1     FALSE      TRUE
#> 217  T-26-0056-2_Operator_2     FALSE      TRUE
#> 218    T-26-0056_Operator_3     FALSE      TRUE
#> 219    T-26-0056_Operator_4     FALSE     FALSE
#> 220    T-26-0057_Operator_1     FALSE      TRUE
#> 221    T-26-0057_Operator_2     FALSE      TRUE
#> 222    T-26-0057_Operator_3     FALSE      TRUE
#> 223    T-26-0057_Operator_4     FALSE      TRUE
#> 224    T-26-0058_Operator_1     FALSE      TRUE
#> 225    T-26-0058_Operator_2     FALSE      TRUE
#> 226    T-26-0058_Operator_3     FALSE      TRUE
#> 227    T-26-0058_Operator_4     FALSE      TRUE
#> 228    T-26-0059_Operator_1     FALSE      TRUE
#> 229    T-26-0059_Operator_2     FALSE      TRUE
#> 230    T-26-0059_Operator_3     FALSE      TRUE
#> 231    T-26-0059_Operator_4     FALSE      TRUE
#> 232    T-26-0060_Operator_1     FALSE      TRUE
#> 233    T-26-0060_Operator_2     FALSE      TRUE
#> 234    T-26-0060_Operator_3     FALSE      TRUE
#> 235    T-26-0060_Operator_4     FALSE      TRUE
#> 236    T-26-0061_Operator_1     FALSE      TRUE
#> 237    T-26-0061_Operator_2     FALSE      TRUE
#> 238    T-26-0061_Operator_3     FALSE      TRUE
#> 239    T-26-0061_Operator_4     FALSE      TRUE
#> 240    T-26-0062_Operator_1     FALSE      TRUE
#> 241    T-26-0062_Operator_2     FALSE      TRUE
#> 242    T-26-0062_Operator_3     FALSE      TRUE
#> 243    T-26-0062_Operator_4     FALSE      TRUE
#> 244    T-26-0063_Operator_1     FALSE      TRUE
#> 245    T-26-0063_Operator_2     FALSE      TRUE
#> 246    T-26-0063_Operator_3     FALSE      TRUE
#> 247    T-26-0063_Operator_4     FALSE      TRUE
#> 248    T-26-0064_Operator_1     FALSE      TRUE
#> 249    T-26-0064_Operator_2     FALSE      TRUE
#> 250    T-26-0064_Operator_3     FALSE      TRUE
#> 251    T-26-0064_Operator_4     FALSE      TRUE
#> 252    T-26-0065_Operator_1     FALSE      TRUE
#> 253    T-26-0065_Operator_2     FALSE      TRUE
#> 254    T-26-0065_Operator_3     FALSE      TRUE
#> 255    T-26-0065_Operator_4     FALSE      TRUE
#> 256    T-26-0067_Operator_1      TRUE      TRUE
#> 257    T-26-0067_Operator_2      TRUE      TRUE
#> 258    T-26-0067_Operator_3     FALSE     FALSE
#> 259    T-26-0067_Operator_4      TRUE      TRUE
#> 260    T-26-0068_Operator_1      TRUE      TRUE
#> 261    T-26-0068_Operator_2      TRUE      TRUE
#> 262    T-26-0068_Operator_3     FALSE     FALSE
#> 263    T-26-0068_Operator_4      TRUE      TRUE
#> 264    T-26-0069_Operator_1     FALSE      TRUE
#> 265    T-26-0069_Operator_2     FALSE      TRUE
#> 266    T-26-0069_Operator_3     FALSE      TRUE
#> 267    T-26-0069_Operator_4     FALSE      TRUE
#> 268    T-26-0070_Operator_1      TRUE      TRUE
#> 269    T-26-0070_Operator_2      TRUE      TRUE
#> 270    T-26-0070_Operator_3     FALSE     FALSE
#> 271    T-26-0070_Operator_4      TRUE      TRUE
#> 272    T-26-0071_Operator_1      TRUE      TRUE
#> 273    T-26-0071_Operator_2      TRUE      TRUE
#> 274    T-26-0071_Operator_3     FALSE     FALSE
#> 275    T-26-0071_Operator_4      TRUE      TRUE
#> 276    T-26-0072_Operator_1      TRUE      TRUE
#> 277    T-26-0072_Operator_2      TRUE      TRUE
#> 278    T-26-0072_Operator_3     FALSE     FALSE
#> 279    T-26-0072_Operator_4      TRUE      TRUE
#> 280    T-26-0073_Operator_1      TRUE      TRUE
#> 281    T-26-0073_Operator_2      TRUE      TRUE
#> 282    T-26-0073_Operator_3     FALSE     FALSE
#> 283    T-26-0073_Operator_4      TRUE      TRUE
#> 284    T-26-0074_Operator_1      TRUE      TRUE
#> 285    T-26-0074_Operator_2      TRUE      TRUE
#> 286    T-26-0074_Operator_3     FALSE     FALSE
#> 287    T-26-0074_Operator_4      TRUE      TRUE
#> 288    T-26-0075_Operator_1      TRUE      TRUE
#> 289    T-26-0075_Operator_2      TRUE      TRUE
#> 290    T-26-0075_Operator_3     FALSE     FALSE
#> 291    T-26-0075_Operator_4      TRUE      TRUE
#> 292    T-26-0076_Operator_1      TRUE      TRUE
#> 293    T-26-0076_Operator_2      TRUE      TRUE
#> 294    T-26-0076_Operator_3     FALSE     FALSE
#> 295    T-26-0076_Operator_4      TRUE      TRUE
#> 296    T-26-0077_Operator_1      TRUE      TRUE
#> 297    T-26-0077_Operator_2      TRUE      TRUE
#> 298    T-26-0077_Operator_3     FALSE     FALSE
#> 299    T-26-0077_Operator_4      TRUE      TRUE
#> 300    T-26-0078_Operator_1      TRUE      TRUE
#> 301    T-26-0078_Operator_2      TRUE      TRUE
#> 302    T-26-0078_Operator_3     FALSE     FALSE
#> 303    T-26-0078_Operator_4      TRUE      TRUE
#> 304    T-26-0079_Operator_1      TRUE      TRUE
#> 305    T-26-0079_Operator_2      TRUE      TRUE
#> 306    T-26-0079_Operator_3     FALSE     FALSE
#> 307    T-26-0079_Operator_4      TRUE      TRUE
#> 308    T-26-0080_Operator_1      TRUE      TRUE
#> 309    T-26-0080_Operator_2      TRUE      TRUE
#> 310    T-26-0080_Operator_3     FALSE     FALSE
#> 311    T-26-0080_Operator_4      TRUE      TRUE
#> 312    T-26-0081_Operator_1      TRUE      TRUE
#> 313    T-26-0081_Operator_2      TRUE      TRUE
#> 314    T-26-0081_Operator_3     FALSE     FALSE
#> 315    T-26-0081_Operator_4      TRUE      TRUE
#> 316    T-26-0082_Operator_1      TRUE      TRUE
#> 317    T-26-0082_Operator_2      TRUE      TRUE
#> 318    T-26-0082_Operator_3     FALSE     FALSE
#> 319    T-26-0082_Operator_4      TRUE      TRUE
#> 320    T-26-0083_Operator_1      TRUE      TRUE
#> 321    T-26-0083_Operator_2      TRUE      TRUE
#> 322    T-26-0083_Operator_3     FALSE     FALSE
#> 323    T-26-0083_Operator_4      TRUE      TRUE
#> 324    T-26-0084_Operator_1      TRUE      TRUE
#> 325    T-26-0084_Operator_2      TRUE      TRUE
#> 326    T-26-0084_Operator_3     FALSE     FALSE
#> 327    T-26-0084_Operator_4      TRUE      TRUE
#> 328    T-26-0085_Operator_1      TRUE      TRUE
#> 329    T-26-0085_Operator_2      TRUE      TRUE
#> 330    T-26-0085_Operator_3     FALSE     FALSE
#> 331    T-26-0085_Operator_4      TRUE      TRUE
#> 332    T-26-0086_Operator_1      TRUE      TRUE
#> 333    T-26-0086_Operator_2      TRUE      TRUE
#> 334    T-26-0086_Operator_3     FALSE     FALSE
#> 335    T-26-0086_Operator_4      TRUE      TRUE
#> 336    T-26-0087_Operator_1     FALSE      TRUE
#> 337    T-26-0087_Operator_2     FALSE      TRUE
#> 338    T-26-0087_Operator_3     FALSE      TRUE
#> 339    T-26-0087_Operator_4     FALSE      TRUE
#> 340    T-26-0088_Operator_1      TRUE      TRUE
#> 341    T-26-0088_Operator_2      TRUE      TRUE
#> 342    T-26-0088_Operator_3     FALSE     FALSE
#> 343    T-26-0088_Operator_4      TRUE      TRUE
#> 344    T-26-0089_Operator_1     FALSE      TRUE
#> 345    T-26-0089_Operator_2     FALSE      TRUE
#> 346    T-26-0089_Operator_3     FALSE      TRUE
#> 347    T-26-0089_Operator_4     FALSE      TRUE
#> 348    T-26-0090_Operator_1      TRUE      TRUE
#> 349    T-26-0090_Operator_2      TRUE      TRUE
#> 350    T-26-0090_Operator_3     FALSE     FALSE
#> 351    T-26-0090_Operator_4      TRUE      TRUE
#> 352    T-26-0091_Operator_1      TRUE      TRUE
#> 353    T-26-0091_Operator_2      TRUE      TRUE
#> 354    T-26-0091_Operator_3     FALSE     FALSE
#> 355    T-26-0091_Operator_4      TRUE      TRUE
#> 356    T-26-0092_Operator_1      TRUE      TRUE
#> 357    T-26-0092_Operator_2      TRUE      TRUE
#> 358    T-26-0092_Operator_3     FALSE     FALSE
#> 359    T-26-0092_Operator_4      TRUE      TRUE
#> 360    T-26-0093_Operator_1      TRUE      TRUE
#> 361    T-26-0093_Operator_2      TRUE      TRUE
#> 362    T-26-0093_Operator_3     FALSE     FALSE
#> 363    T-26-0093_Operator_4      TRUE      TRUE
#> 364    T-26-0094_Operator_1      TRUE      TRUE
#> 365    T-26-0094_Operator_2      TRUE      TRUE
#> 366    T-26-0094_Operator_3     FALSE     FALSE
#> 367    T-26-0094_Operator_4      TRUE      TRUE
#> 368    T-26-0095_Operator_1      TRUE      TRUE
#> 369    T-26-0095_Operator_2      TRUE      TRUE
#> 370    T-26-0095_Operator_3     FALSE      TRUE
#> 371    T-26-0095_Operator_4      TRUE      TRUE
#> 372    T-26-0096_Operator_1      TRUE      TRUE
#> 373    T-26-0096_Operator_2      TRUE      TRUE
#> 374    T-26-0096_Operator_3     FALSE      TRUE
#> 375    T-26-0096_Operator_4      TRUE      TRUE
#> 376    T-26-0097_Operator_1      TRUE      TRUE
#> 377    T-26-0097_Operator_2      TRUE      TRUE
#> 378    T-26-0097_Operator_3     FALSE      TRUE
#> 379    T-26-0097_Operator_4      TRUE      TRUE
#> 380    T-26-0098_Operator_1      TRUE      TRUE
#> 381    T-26-0098_Operator_2      TRUE      TRUE
#> 382    T-26-0098_Operator_3     FALSE      TRUE
#> 383    T-26-0098_Operator_4      TRUE      TRUE
#> 384    T-26-0099_Operator_1      TRUE      TRUE
#> 385    T-26-0099_Operator_2      TRUE      TRUE
#> 386    T-26-0099_Operator_3     FALSE      TRUE
#> 387    T-26-0099_Operator_4      TRUE      TRUE
#> 388    T-26-0100_Operator_1      TRUE      TRUE
#> 389    T-26-0100_Operator_2      TRUE      TRUE
#> 390    T-26-0100_Operator_3     FALSE      TRUE
#> 391    T-26-0100_Operator_4      TRUE      TRUE
#> 392    T-26-0101_Operator_1      TRUE      TRUE
#> 393    T-26-0101_Operator_2      TRUE      TRUE
#> 394    T-26-0101_Operator_3     FALSE      TRUE
#> 395    T-26-0101_Operator_4      TRUE      TRUE
#> 396    T-26-0102_Operator_1      TRUE      TRUE
#> 397    T-26-0102_Operator_2      TRUE      TRUE
#> 398    T-26-0102_Operator_3     FALSE      TRUE
#> 399    T-26-0102_Operator_4      TRUE      TRUE
#> 400    T-26-0103_Operator_1      TRUE      TRUE
#> 401    T-26-0103_Operator_2      TRUE      TRUE
#> 402    T-26-0103_Operator_3     FALSE      TRUE
#> 403    T-26-0103_Operator_4      TRUE      TRUE
#> 404    T-26-0104_Operator_1      TRUE      TRUE
#> 405    T-26-0104_Operator_2      TRUE      TRUE
#> 406    T-26-0104_Operator_3     FALSE      TRUE
#> 407    T-26-0104_Operator_4      TRUE      TRUE
#> 408    T-26-0107_Operator_1      TRUE      TRUE
#> 409    T-26-0107_Operator_2      TRUE      TRUE
#> 410    T-26-0107_Operator_3     FALSE      TRUE
#> 411    T-26-0107_Operator_4      TRUE      TRUE
#> 412    T-26-0108_Operator_1      TRUE      TRUE
#> 413    T-26-0108_Operator_2      TRUE      TRUE
#> 414    T-26-0108_Operator_3     FALSE      TRUE
#> 415    T-26-0108_Operator_4      TRUE      TRUE
#> 416    T-26-0109_Operator_1      TRUE      TRUE
#> 417    T-26-0109_Operator_2      TRUE      TRUE
#> 418    T-26-0109_Operator_3     FALSE      TRUE
#> 419    T-26-0109_Operator_4      TRUE      TRUE
#> 420    T-26-0111_Operator_1      TRUE      TRUE
#> 421    T-26-0111_Operator_2      TRUE      TRUE
#> 422    T-26-0111_Operator_3     FALSE      TRUE
#> 423    T-26-0111_Operator_4      TRUE      TRUE
#> 424  T-26-0112-2_Operator_1      TRUE      TRUE
#> 425  T-26-0112-2_Operator_2      TRUE      TRUE
#> 426    T-26-0112_Operator_1     FALSE      TRUE
#> 427    T-26-0112_Operator_2     FALSE      TRUE
#> 428    T-26-0112_Operator_4      TRUE      TRUE
#> 429    T-26-0113_Operator_1      TRUE      TRUE
#> 430    T-26-0113_Operator_2      TRUE      TRUE
#> 431    T-26-0113_Operator_3     FALSE      TRUE
#> 432    T-26-0113_Operator_4      TRUE      TRUE
#> 433    T-26-0114_Operator_1      TRUE      TRUE
#> 434    T-26-0114_Operator_2      TRUE      TRUE
#> 435    T-26-0114_Operator_3     FALSE      TRUE
#> 436    T-26-0114_Operator_4      TRUE      TRUE
#> 437    T-26-0115_Operator_1      TRUE      TRUE
#> 438    T-26-0115_Operator_2      TRUE      TRUE
#> 439    T-26-0115_Operator_3     FALSE      TRUE
#> 440    T-26-0115_Operator_4      TRUE      TRUE
#> 441    T-26-0116_Operator_1      TRUE      TRUE
#> 442    T-26-0116_Operator_2      TRUE      TRUE
#> 443    T-26-0116_Operator_3     FALSE      TRUE
#> 444    T-26-0116_Operator_4      TRUE      TRUE
#> 445    T-26-0117_Operator_1      TRUE      TRUE
#> 446    T-26-0117_Operator_2      TRUE      TRUE
#> 447    T-26-0117_Operator_4      TRUE      TRUE
#> 448    T-26-0118_Operator_1      TRUE      TRUE
#> 449    T-26-0118_Operator_2      TRUE      TRUE
#> 450    T-26-0118_Operator_3     FALSE      TRUE
#> 451    T-26-0118_Operator_4      TRUE      TRUE
#> 452    T-26-0120_Operator_1      TRUE      TRUE
#> 453    T-26-0120_Operator_2      TRUE      TRUE
#> 454    T-26-0120_Operator_3     FALSE      TRUE
#> 455    T-26-0120_Operator_4      TRUE      TRUE
#> 456    T-26-0121_Operator_1      TRUE      TRUE
#> 457    T-26-0121_Operator_2     FALSE      TRUE
#> 458    T-26-0121_Operator_4      TRUE      TRUE
#> 459    T-26-0122_Operator_1      TRUE      TRUE
#> 460    T-26-0122_Operator_2      TRUE      TRUE
#> 461    T-26-0122_Operator_3     FALSE      TRUE
#> 462    T-26-0122_Operator_4      TRUE      TRUE
#> 463    T-26-0123_Operator_1      TRUE      TRUE
#> 464    T-26-0123_Operator_2      TRUE      TRUE
#> 465    T-26-0123_Operator_3     FALSE      TRUE
#> 466    T-26-0123_Operator_4      TRUE      TRUE
#> 467    T-26-0125_Operator_1      TRUE      TRUE
#> 468    T-26-0125_Operator_2      TRUE      TRUE
#> 469    T-26-0125_Operator_3     FALSE      TRUE
#> 470    T-26-0125_Operator_4      TRUE      TRUE
#> 471    T-26-0126_Operator_1      TRUE      TRUE
#> 472    T-26-0126_Operator_2      TRUE      TRUE
#> 473    T-26-0126_Operator_4      TRUE      TRUE
#> 474    T-26-0127_Operator_1      TRUE      TRUE
#> 475    T-26-0127_Operator_2      TRUE      TRUE
#> 476    T-26-0127_Operator_3     FALSE      TRUE
#> 477    T-26-0127_Operator_4      TRUE      TRUE
#> 478    T-26-0128_Operator_1      TRUE      TRUE
#> 479    T-26-0128_Operator_2      TRUE      TRUE
#> 480    T-26-0128_Operator_3     FALSE      TRUE
#> 481    T-26-0128_Operator_4      TRUE      TRUE
#> 482    T-26-0130_Operator_1      TRUE      TRUE
#> 483    T-26-0130_Operator_2      TRUE      TRUE
#> 484    T-26-0130_Operator_3     FALSE      TRUE
#> 485    T-26-0130_Operator_4      TRUE      TRUE
#> 486    T-26-0131_Operator_1     FALSE      TRUE
#> 487    T-26-0131_Operator_2     FALSE      TRUE
#> 488    T-26-0131_Operator_3     FALSE      TRUE
#> 489    T-26-0131_Operator_4     FALSE      TRUE
#> 490    T-26-0132_Operator_1     FALSE      TRUE
#> 491    T-26-0132_Operator_2     FALSE      TRUE
#> 492    T-26-0132_Operator_3     FALSE      TRUE
#> 493    T-26-0132_Operator_4     FALSE      TRUE
#> 494    T-26-0133_Operator_1     FALSE      TRUE
#> 495    T-26-0133_Operator_2     FALSE      TRUE
#> 496    T-26-0133_Operator_3     FALSE      TRUE
#> 497    T-26-0133_Operator_4     FALSE      TRUE
#> 498    T-26-0134_Operator_1     FALSE      TRUE
#> 499    T-26-0134_Operator_2     FALSE      TRUE
#> 500    T-26-0134_Operator_3     FALSE      TRUE
#> 501    T-26-0134_Operator_4     FALSE      TRUE
#> 502    T-26-0135_Operator_1     FALSE      TRUE
#> 503    T-26-0135_Operator_2     FALSE      TRUE
#> 504    T-26-0135_Operator_3     FALSE      TRUE
#> 505    T-26-0135_Operator_4     FALSE      TRUE
#> 506    T-26-0136_Operator_1     FALSE      TRUE
#> 507    T-26-0136_Operator_2     FALSE      TRUE
#> 508    T-26-0136_Operator_3     FALSE      TRUE
#> 509    T-26-0136_Operator_4     FALSE      TRUE
#> 510    T-26-0137_Operator_1     FALSE      TRUE
#> 511    T-26-0137_Operator_2     FALSE      TRUE
#> 512    T-26-0137_Operator_3     FALSE      TRUE
#> 513    T-26-0137_Operator_4     FALSE      TRUE
#> 514    T-26-0138_Operator_1     FALSE      TRUE
#> 515    T-26-0138_Operator_2     FALSE      TRUE
#> 516    T-26-0138_Operator_3     FALSE      TRUE
#> 517    T-26-0138_Operator_4     FALSE      TRUE
#> 518    T-26-0139_Operator_1     FALSE      TRUE
#> 519    T-26-0139_Operator_2     FALSE      TRUE
#> 520    T-26-0139_Operator_3     FALSE      TRUE
#> 521    T-26-0139_Operator_4     FALSE      TRUE
#> 522    T-26-0140_Operator_1     FALSE      TRUE
#> 523    T-26-0140_Operator_2     FALSE      TRUE
#> 524    T-26-0140_Operator_3     FALSE      TRUE
#> 525    T-26-0140_Operator_4     FALSE      TRUE
#> 526    T-26-0141_Operator_1     FALSE      TRUE
#> 527    T-26-0141_Operator_2     FALSE      TRUE
#> 528    T-26-0141_Operator_3     FALSE      TRUE
#> 529    T-26-0141_Operator_4     FALSE      TRUE
#> 530    T-26-0142_Operator_1     FALSE      TRUE
#> 531    T-26-0142_Operator_2     FALSE      TRUE
#> 532    T-26-0142_Operator_3     FALSE      TRUE
#> 533    T-26-0142_Operator_4     FALSE      TRUE
#> 534    T-26-0143_Operator_1     FALSE      TRUE
#> 535    T-26-0143_Operator_2     FALSE      TRUE
#> 536    T-26-0143_Operator_3     FALSE      TRUE
#> 537    T-26-0143_Operator_4     FALSE      TRUE
#> 538    T-26-0144_Operator_1     FALSE      TRUE
#> 539    T-26-0144_Operator_2     FALSE      TRUE
#> 540    T-26-0144_Operator_3     FALSE      TRUE
#> 541    T-26-0144_Operator_4     FALSE      TRUE
#> 542    T-26-0145_Operator_1     FALSE      TRUE
#> 543    T-26-0145_Operator_2     FALSE      TRUE
#> 544    T-26-0145_Operator_3     FALSE      TRUE
#> 545    T-26-0145_Operator_4     FALSE      TRUE
#> 546    T-26-0146_Operator_1     FALSE      TRUE
#> 547    T-26-0146_Operator_2     FALSE      TRUE
#> 548    T-26-0146_Operator_3     FALSE      TRUE
#> 549    T-26-0146_Operator_4     FALSE      TRUE
#> 550    T-26-0147_Operator_1     FALSE      TRUE
#> 551    T-26-0147_Operator_2     FALSE      TRUE
#> 552    T-26-0147_Operator_3     FALSE      TRUE
#> 553    T-26-0147_Operator_4     FALSE      TRUE
#> 554    T-26-0148_Operator_1     FALSE      TRUE
#> 555    T-26-0148_Operator_2     FALSE      TRUE
#> 556    T-26-0148_Operator_3     FALSE      TRUE
#> 557    T-26-0148_Operator_4     FALSE      TRUE
#> 558    T-26-0149_Operator_1     FALSE      TRUE
#> 559    T-26-0149_Operator_2     FALSE      TRUE
#> 560    T-26-0149_Operator_3     FALSE      TRUE
#> 561    T-26-0149_Operator_4     FALSE      TRUE
#> 562    T-26-0150_Operator_1     FALSE      TRUE
#> 563    T-26-0150_Operator_2     FALSE      TRUE
#> 564    T-26-0150_Operator_3     FALSE      TRUE
#> 565    T-26-0150_Operator_4     FALSE      TRUE
#> 566    T-26-0151_Operator_1     FALSE      TRUE
#> 567    T-26-0151_Operator_2     FALSE      TRUE
#> 568    T-26-0151_Operator_3     FALSE      TRUE
#> 569    T-26-0151_Operator_4     FALSE      TRUE
#> 570    T-26-0152_Operator_1     FALSE      TRUE
#> 571    T-26-0152_Operator_2     FALSE      TRUE
#> 572    T-26-0152_Operator_3     FALSE      TRUE
#> 573    T-26-0152_Operator_4     FALSE      TRUE
#> 574    T-26-0153_Operator_1     FALSE      TRUE
#> 575    T-26-0153_Operator_2     FALSE      TRUE
#> 576    T-26-0153_Operator_3     FALSE      TRUE
#> 577    T-26-0153_Operator_4     FALSE      TRUE
#> 578    T-26-0154_Operator_1     FALSE      TRUE
#> 579    T-26-0154_Operator_2     FALSE      TRUE
#> 580    T-26-0154_Operator_3     FALSE      TRUE
#> 581    T-26-0154_Operator_4     FALSE      TRUE
#> 582    T-26-0155_Operator_1     FALSE      TRUE
#> 583    T-26-0155_Operator_2     FALSE      TRUE
#> 584    T-26-0155_Operator_3     FALSE      TRUE
#> 585    T-26-0155_Operator_4     FALSE      TRUE
#> 586    T-26-0156_Operator_1     FALSE      TRUE
#> 587    T-26-0156_Operator_2     FALSE      TRUE
#> 588    T-26-0156_Operator_3     FALSE      TRUE
#> 589    T-26-0156_Operator_4     FALSE      TRUE
#> 590    T-26-0157_Operator_1     FALSE      TRUE
#> 591    T-26-0157_Operator_2     FALSE      TRUE
#> 592    T-26-0157_Operator_3     FALSE      TRUE
#> 593    T-26-0157_Operator_4     FALSE      TRUE
#> 594    T-26-0158_Operator_1     FALSE      TRUE
#> 595    T-26-0158_Operator_2     FALSE      TRUE
#> 596    T-26-0158_Operator_3     FALSE      TRUE
#> 597    T-26-0158_Operator_4     FALSE      TRUE
#> 598    T-26-0159_Operator_1     FALSE      TRUE
#> 599    T-26-0159_Operator_2     FALSE      TRUE
#> 600    T-26-0159_Operator_3     FALSE      TRUE
#> 601    T-26-0159_Operator_4     FALSE      TRUE
#> 602    T-26-0160_Operator_1     FALSE      TRUE
#> 603    T-26-0160_Operator_2     FALSE      TRUE
#> 604    T-26-0160_Operator_3     FALSE      TRUE
#> 605    T-26-0160_Operator_4     FALSE      TRUE
#> 606    T-26-0161_Operator_1     FALSE      TRUE
#> 607    T-26-0161_Operator_2     FALSE      TRUE
#> 608    T-26-0161_Operator_3     FALSE      TRUE
#> 609    T-26-0161_Operator_4     FALSE      TRUE
#> 610    T-26-0162_Operator_1     FALSE      TRUE
#> 611    T-26-0162_Operator_2     FALSE      TRUE
#> 612    T-26-0162_Operator_3     FALSE      TRUE
#> 613    T-26-0162_Operator_4     FALSE      TRUE
#> 614    T-26-0163_Operator_1     FALSE      TRUE
#> 615    T-26-0163_Operator_2     FALSE      TRUE
#> 616    T-26-0163_Operator_3     FALSE      TRUE
#> 617    T-26-0163_Operator_4     FALSE      TRUE
#> 618    T-26-0164_Operator_1     FALSE      TRUE
#> 619    T-26-0164_Operator_2     FALSE      TRUE
#> 620    T-26-0164_Operator_3     FALSE      TRUE
#> 621    T-26-0164_Operator_4     FALSE      TRUE
#> 622    T-26-0165_Operator_1     FALSE      TRUE
#> 623    T-26-0165_Operator_2     FALSE      TRUE
#> 624    T-26-0165_Operator_3     FALSE      TRUE
#> 625    T-26-0165_Operator_4     FALSE      TRUE
#> 626    T-26-0166_Operator_1     FALSE      TRUE
#> 627    T-26-0166_Operator_2     FALSE      TRUE
#> 628    T-26-0166_Operator_3     FALSE      TRUE
#> 629    T-26-0166_Operator_4     FALSE      TRUE
#> 630    T-26-0167_Operator_1     FALSE      TRUE
#> 631    T-26-0167_Operator_2     FALSE      TRUE
#> 632    T-26-0167_Operator_3     FALSE      TRUE
#> 633    T-26-0167_Operator_4     FALSE      TRUE
#> 634    T-26-0168_Operator_1     FALSE      TRUE
#> 635    T-26-0168_Operator_2     FALSE      TRUE
#> 636    T-26-0168_Operator_3     FALSE      TRUE
#> 637    T-26-0168_Operator_4     FALSE      TRUE
#> 638    T-26-0169_Operator_1     FALSE      TRUE
#> 639    T-26-0169_Operator_2     FALSE      TRUE
#> 640    T-26-0169_Operator_3     FALSE      TRUE
#> 641    T-26-0169_Operator_4     FALSE      TRUE
#> 642    T-26-0170_Operator_1     FALSE      TRUE
#> 643    T-26-0170_Operator_2     FALSE      TRUE
#> 644    T-26-0170_Operator_3     FALSE      TRUE
#> 645    T-26-0170_Operator_4     FALSE      TRUE
#> 646    T-26-0171_Operator_1     FALSE      TRUE
#> 647    T-26-0171_Operator_2     FALSE      TRUE
#> 648    T-26-0171_Operator_3     FALSE      TRUE
#> 649    T-26-0171_Operator_4     FALSE      TRUE
#> 650    T-26-0172_Operator_1     FALSE      TRUE
#> 651    T-26-0172_Operator_2     FALSE      TRUE
#> 652    T-26-0172_Operator_3     FALSE      TRUE
#> 653    T-26-0172_Operator_4     FALSE      TRUE
#> 654    T-26-0173_Operator_1     FALSE      TRUE
#> 655    T-26-0173_Operator_2     FALSE      TRUE
#> 656    T-26-0173_Operator_3     FALSE      TRUE
#> 657    T-26-0173_Operator_4     FALSE      TRUE
#> 658    T-26-0174_Operator_1     FALSE      TRUE
#> 659    T-26-0174_Operator_2     FALSE      TRUE
#> 660    T-26-0174_Operator_3     FALSE      TRUE
#> 661    T-26-0174_Operator_4     FALSE      TRUE
#> 662    T-26-0175_Operator_1     FALSE      TRUE
#> 663    T-26-0175_Operator_2     FALSE      TRUE
#> 664    T-26-0175_Operator_3     FALSE      TRUE
#> 665    T-26-0175_Operator_4     FALSE      TRUE
#> 666    T-26-0176_Operator_1     FALSE      TRUE
#> 667    T-26-0176_Operator_2     FALSE      TRUE
#> 668    T-26-0176_Operator_3     FALSE      TRUE
#> 669    T-26-0176_Operator_4     FALSE      TRUE
#> 670    T-26-0177_Operator_1     FALSE      TRUE
#> 671    T-26-0177_Operator_2     FALSE      TRUE
#> 672    T-26-0177_Operator_3     FALSE      TRUE
#> 673    T-26-0177_Operator_4     FALSE      TRUE
#> 674    T-26-0178_Operator_1     FALSE      TRUE
#> 675    T-26-0178_Operator_2     FALSE      TRUE
#> 676    T-26-0178_Operator_3     FALSE      TRUE
#> 677    T-26-0178_Operator_4     FALSE      TRUE
#> 678  T-26-0179-3_Operator_1     FALSE      TRUE
#> 679  T-26-0179-3_Operator_2     FALSE      TRUE
#> 680    T-26-0179_Operator_1     FALSE      TRUE
#> 681    T-26-0179_Operator_2     FALSE      TRUE
#> 682    T-26-0179_Operator_3     FALSE      TRUE
#> 683    T-26-0179_Operator_4     FALSE      TRUE
#> 684    T-26-0180_Operator_1     FALSE      TRUE
#> 685    T-26-0180_Operator_2     FALSE      TRUE
#> 686    T-26-0180_Operator_3     FALSE      TRUE
#> 687    T-26-0180_Operator_4     FALSE      TRUE
#> 688    T-26-0181_Operator_1     FALSE      TRUE
#> 689    T-26-0181_Operator_2     FALSE      TRUE
#> 690    T-26-0181_Operator_3     FALSE      TRUE
#> 691    T-26-0181_Operator_4     FALSE      TRUE
#> 692    T-26-0182_Operator_1     FALSE      TRUE
#> 693    T-26-0182_Operator_2     FALSE      TRUE
#> 694    T-26-0182_Operator_3     FALSE      TRUE
#> 695    T-26-0182_Operator_4     FALSE      TRUE
#> 696    T-26-0183_Operator_1     FALSE      TRUE
#> 697    T-26-0183_Operator_2     FALSE      TRUE
#> 698    T-26-0183_Operator_3     FALSE      TRUE
#> 699    T-26-0183_Operator_4     FALSE      TRUE
#> 700    T-26-0184_Operator_1     FALSE      TRUE
#> 701    T-26-0184_Operator_2     FALSE      TRUE
#> 702    T-26-0184_Operator_3     FALSE      TRUE
#> 703    T-26-0184_Operator_4     FALSE      TRUE
#> 704    T-26-0185_Operator_1     FALSE      TRUE
#> 705    T-26-0185_Operator_2     FALSE      TRUE
#> 706    T-26-0185_Operator_3     FALSE      TRUE
#> 707    T-26-0185_Operator_4     FALSE      TRUE
#> 708    T-26-0186_Operator_1     FALSE      TRUE
#> 709    T-26-0186_Operator_2     FALSE      TRUE
#> 710    T-26-0186_Operator_3     FALSE      TRUE
#> 711    T-26-0186_Operator_4     FALSE      TRUE
#> 712    T-26-0187_Operator_1     FALSE      TRUE
#> 713    T-26-0187_Operator_2     FALSE      TRUE
#> 714    T-26-0187_Operator_3     FALSE      TRUE
#> 715    T-26-0187_Operator_4     FALSE      TRUE
#> 716    T-26-0188_Operator_1     FALSE      TRUE
#> 717    T-26-0188_Operator_2     FALSE      TRUE
#> 718    T-26-0188_Operator_3     FALSE      TRUE
#> 719    T-26-0188_Operator_4     FALSE      TRUE
#> 720    T-26-0189_Operator_1     FALSE      TRUE
#> 721    T-26-0189_Operator_2     FALSE      TRUE
#> 722    T-26-0189_Operator_3     FALSE      TRUE
#> 723    T-26-0189_Operator_4     FALSE      TRUE
#> 724    T-26-0190_Operator_1      TRUE     FALSE
#> 725    T-26-0190_Operator_2     FALSE      TRUE
#> 726    T-26-0190_Operator_4     FALSE     FALSE
#> 727    T-26-0191_Operator_1     FALSE      TRUE
#> 728    T-26-0191_Operator_2     FALSE      TRUE
#> 729    T-26-0191_Operator_4     FALSE      TRUE
#> 730    T-26-0192_Operator_1     FALSE      TRUE
#> 731    T-26-0192_Operator_2     FALSE      TRUE
#> 732    T-26-0192_Operator_4     FALSE      TRUE
#> 733    T-26-0193_Operator_1     FALSE      TRUE
#> 734    T-26-0193_Operator_2     FALSE      TRUE
#> 735    T-26-0193_Operator_4     FALSE      TRUE
#> 736    T-26-0194_Operator_1     FALSE      TRUE
#> 737    T-26-0194_Operator_2     FALSE      TRUE
#> 738    T-26-0194_Operator_4     FALSE      TRUE
#> 739    T-26-0195_Operator_1     FALSE      TRUE
#> 740    T-26-0195_Operator_2     FALSE      TRUE
#> 741    T-26-0195_Operator_4     FALSE      TRUE
#> 742    T-26-0196_Operator_1     FALSE      TRUE
#> 743    T-26-0196_Operator_2     FALSE      TRUE
#> 744    T-26-0196_Operator_4     FALSE      TRUE
#> 745    T-26-0197_Operator_1     FALSE      TRUE
#> 746    T-26-0197_Operator_2     FALSE      TRUE
#> 747    T-26-0197_Operator_3     FALSE      TRUE
#> 748    T-26-0197_Operator_4     FALSE      TRUE
#> 749    T-26-0198_Operator_1     FALSE      TRUE
#> 750    T-26-0198_Operator_2     FALSE      TRUE
#> 751    T-26-0198_Operator_3     FALSE      TRUE
#> 752    T-26-0198_Operator_4     FALSE      TRUE
#> 753    T-26-0199_Operator_1     FALSE      TRUE
#> 754    T-26-0199_Operator_2     FALSE      TRUE
#> 755    T-26-0199_Operator_3     FALSE      TRUE
#> 756    T-26-0199_Operator_4     FALSE      TRUE
#> 757    T-26-0200_Operator_1     FALSE      TRUE
#> 758    T-26-0200_Operator_2     FALSE      TRUE
#> 759    T-26-0200_Operator_3     FALSE      TRUE
#> 760    T-26-0200_Operator_4     FALSE      TRUE
#> 761    T-26-0201_Operator_1     FALSE      TRUE
#> 762    T-26-0201_Operator_2     FALSE      TRUE
#> 763    T-26-0201_Operator_3     FALSE      TRUE
#> 764    T-26-0201_Operator_4     FALSE      TRUE
#> 765    T-26-0202_Operator_1     FALSE      TRUE
#> 766    T-26-0202_Operator_2     FALSE      TRUE
#> 767    T-26-0202_Operator_3     FALSE      TRUE
#> 768    T-26-0202_Operator_4     FALSE      TRUE
#> 769    T-26-0203_Operator_1     FALSE      TRUE
#> 770    T-26-0203_Operator_2     FALSE      TRUE
#> 771    T-26-0203_Operator_3     FALSE      TRUE
#> 772    T-26-0203_Operator_4     FALSE      TRUE
#> 773    T-26-0204_Operator_1     FALSE      TRUE
#> 774    T-26-0204_Operator_2     FALSE      TRUE
#> 775    T-26-0204_Operator_3     FALSE      TRUE
#> 776    T-26-0204_Operator_4     FALSE      TRUE
#> 777    T-26-0205_Operator_1     FALSE      TRUE
#> 778    T-26-0205_Operator_2     FALSE      TRUE
#> 779    T-26-0205_Operator_3     FALSE      TRUE
#> 780    T-26-0205_Operator_4     FALSE      TRUE
#> 781    T-26-0206_Operator_1     FALSE      TRUE
#> 782    T-26-0206_Operator_2     FALSE      TRUE
#> 783    T-26-0206_Operator_3     FALSE      TRUE
#> 784    T-26-0206_Operator_4     FALSE      TRUE
#> 785    T-26-0207_Operator_1     FALSE      TRUE
#> 786    T-26-0207_Operator_2     FALSE      TRUE
#> 787    T-26-0207_Operator_3     FALSE      TRUE
#> 788    T-26-0207_Operator_4     FALSE      TRUE
#> 789    T-26-0208_Operator_1     FALSE      TRUE
#> 790    T-26-0208_Operator_2     FALSE      TRUE
#> 791    T-26-0208_Operator_3     FALSE      TRUE
#> 792    T-26-0208_Operator_4     FALSE      TRUE
#> 793    T-26-0209_Operator_1      TRUE     FALSE
#> 794    T-26-0209_Operator_2     FALSE      TRUE
#> 795    T-26-0209_Operator_4     FALSE     FALSE
#> 796    T-26-0210_Operator_1     FALSE      TRUE
#> 797    T-26-0210_Operator_2     FALSE      TRUE
#> 798    T-26-0210_Operator_4     FALSE      TRUE
#> 799    T-26-0211_Operator_1     FALSE      TRUE
#> 800    T-26-0211_Operator_2     FALSE      TRUE
#> 801    T-26-0211_Operator_4     FALSE      TRUE
#> 802    T-26-0212_Operator_1     FALSE      TRUE
#> 803    T-26-0212_Operator_2     FALSE      TRUE
#> 804    T-26-0212_Operator_4     FALSE      TRUE
#> 805    T-26-0213_Operator_1     FALSE      TRUE
#> 806    T-26-0213_Operator_2     FALSE      TRUE
#> 807    T-26-0213_Operator_4     FALSE      TRUE
#> 808    T-26-0214_Operator_1     FALSE      TRUE
#> 809    T-26-0214_Operator_2     FALSE      TRUE
#> 810    T-26-0214_Operator_4     FALSE      TRUE
#> 811    T-26-0215_Operator_1     FALSE      TRUE
#> 812    T-26-0215_Operator_2     FALSE      TRUE
#> 813    T-26-0215_Operator_4     FALSE      TRUE
#> 814    T-26-0216_Operator_1     FALSE      TRUE
#> 815    T-26-0216_Operator_2     FALSE      TRUE
#> 816    T-26-0216_Operator_3     FALSE      TRUE
#> 817    T-26-0216_Operator_4     FALSE      TRUE
#> 818    T-26-0217_Operator_1     FALSE      TRUE
#> 819    T-26-0217_Operator_2     FALSE      TRUE
#> 820    T-26-0217_Operator_3     FALSE      TRUE
#> 821    T-26-0217_Operator_4     FALSE      TRUE
#> 822    T-26-0218_Operator_1     FALSE      TRUE
#> 823    T-26-0218_Operator_2     FALSE      TRUE
#> 824    T-26-0218_Operator_3     FALSE      TRUE
#> 825    T-26-0218_Operator_4     FALSE      TRUE
#> 826    T-26-0219_Operator_1     FALSE      TRUE
#> 827    T-26-0219_Operator_2     FALSE      TRUE
#> 828    T-26-0219_Operator_3     FALSE      TRUE
#> 829    T-26-0219_Operator_4     FALSE      TRUE
#> 830    T-26-0220_Operator_1     FALSE      TRUE
#> 831    T-26-0220_Operator_2     FALSE      TRUE
#> 832    T-26-0220_Operator_3     FALSE      TRUE
#> 833    T-26-0220_Operator_4     FALSE      TRUE
#> 834    T-26-0221_Operator_1     FALSE      TRUE
#> 835    T-26-0221_Operator_2     FALSE      TRUE
#> 836    T-26-0221_Operator_3     FALSE      TRUE
#> 837    T-26-0221_Operator_4     FALSE      TRUE
#> 838    T-26-0222_Operator_1     FALSE      TRUE
#> 839    T-26-0222_Operator_2     FALSE      TRUE
#> 840    T-26-0222_Operator_4     FALSE      TRUE
#> 841    T-26-0223_Operator_1     FALSE      TRUE
#> 842    T-26-0223_Operator_2     FALSE      TRUE
#> 843    T-26-0223_Operator_4     FALSE      TRUE
#> 844    T-26-0224_Operator_1     FALSE      TRUE
#> 845    T-26-0224_Operator_2     FALSE      TRUE
#> 846    T-26-0224_Operator_4     FALSE      TRUE
#> 847    T-26-0225_Operator_1     FALSE      TRUE
#> 848    T-26-0225_Operator_2     FALSE      TRUE
#> 849    T-26-0225_Operator_4     FALSE      TRUE
#> 850    T-26-0226_Operator_1     FALSE      TRUE
#> 851    T-26-0226_Operator_2     FALSE      TRUE
#> 852    T-26-0226_Operator_4     FALSE      TRUE
#> 853    T-26-0227_Operator_1     FALSE      TRUE
#> 854    T-26-0227_Operator_2     FALSE      TRUE
#> 855    T-26-0227_Operator_4     FALSE      TRUE
#> 856    T-26-0228_Operator_1     FALSE      TRUE
#> 857    T-26-0228_Operator_2     FALSE      TRUE
#> 858    T-26-0228_Operator_3     FALSE      TRUE
#> 859    T-26-0228_Operator_4     FALSE      TRUE
#> 860    T-26-0229_Operator_1     FALSE      TRUE
#> 861    T-26-0229_Operator_2     FALSE      TRUE
#> 862    T-26-0229_Operator_4     FALSE      TRUE
#> 863  T-26-0230-1_Operator_1     FALSE      TRUE
#> 864  T-26-0230-1_Operator_2     FALSE      TRUE
#> 865  T-26-0230-2_Operator_1     FALSE      TRUE
#> 866  T-26-0230-2_Operator_2     FALSE      TRUE
#> 867  T-26-0230-3_Operator_1     FALSE      TRUE
#> 868  T-26-0230-3_Operator_2     FALSE      TRUE
#> 869  T-26-0230-4_Operator_1     FALSE      TRUE
#> 870  T-26-0230-4_Operator_2     FALSE      TRUE
#> 871    T-26-0231_Operator_1     FALSE      TRUE
#> 872    T-26-0231_Operator_2     FALSE      TRUE
#> 873    T-26-0231_Operator_4     FALSE      TRUE
#> 874    T-26-0232_Operator_1     FALSE      TRUE
#> 875    T-26-0232_Operator_2     FALSE      TRUE
#> 876    T-26-0232_Operator_4     FALSE      TRUE
#> 877    T-26-0233_Operator_1     FALSE      TRUE
#> 878    T-26-0233_Operator_2     FALSE      TRUE
#> 879    T-26-0233_Operator_4     FALSE      TRUE
#> 880    T-26-0234_Operator_1     FALSE      TRUE
#> 881    T-26-0234_Operator_2     FALSE      TRUE
#> 882    T-26-0234_Operator_4     FALSE      TRUE
#> 883    T-26-0235_Operator_1     FALSE      TRUE
#> 884    T-26-0235_Operator_2     FALSE      TRUE
#> 885    T-26-0235_Operator_4     FALSE      TRUE
#> 886    T-26-0236_Operator_1     FALSE      TRUE
#> 887    T-26-0236_Operator_2     FALSE      TRUE
#> 888    T-26-0236_Operator_3     FALSE      TRUE
#> 889    T-26-0236_Operator_4     FALSE      TRUE
#> 890    T-26-0237_Operator_1     FALSE      TRUE
#> 891    T-26-0237_Operator_2     FALSE      TRUE
#> 892    T-26-0237_Operator_3     FALSE      TRUE
#> 893    T-26-0237_Operator_4     FALSE      TRUE
#> 894    T-26-0238_Operator_1     FALSE      TRUE
#> 895    T-26-0238_Operator_2     FALSE      TRUE
#> 896    T-26-0238_Operator_3     FALSE      TRUE
#> 897    T-26-0238_Operator_4     FALSE      TRUE
#> 898    T-26-0239_Operator_1     FALSE      TRUE
#> 899    T-26-0239_Operator_2     FALSE      TRUE
#> 900    T-26-0239_Operator_3     FALSE      TRUE
#> 901    T-26-0239_Operator_4     FALSE      TRUE
#> 902    T-26-0240_Operator_1     FALSE      TRUE
#> 903    T-26-0240_Operator_2     FALSE      TRUE
#> 904    T-26-0240_Operator_3     FALSE      TRUE
#> 905    T-26-0240_Operator_4     FALSE      TRUE
#> 906    T-26-0241_Operator_1     FALSE      TRUE
#> 907    T-26-0241_Operator_2     FALSE      TRUE
#> 908    T-26-0241_Operator_3     FALSE      TRUE
#> 909    T-26-0241_Operator_4     FALSE      TRUE
#> 910    T-26-0242_Operator_1     FALSE      TRUE
#> 911    T-26-0242_Operator_2     FALSE      TRUE
#> 912    T-26-0242_Operator_3     FALSE      TRUE
#> 913    T-26-0242_Operator_4     FALSE      TRUE
#> 914    T-26-0243_Operator_1     FALSE      TRUE
#> 915    T-26-0243_Operator_2     FALSE      TRUE
#> 916    T-26-0243_Operator_3     FALSE      TRUE
#> 917    T-26-0243_Operator_4     FALSE      TRUE
#> 918    T-26-0244_Operator_1     FALSE      TRUE
#> 919    T-26-0244_Operator_2     FALSE      TRUE
#> 920    T-26-0244_Operator_3     FALSE      TRUE
#> 921    T-26-0244_Operator_4     FALSE      TRUE
#> 922    T-26-0245_Operator_1     FALSE      TRUE
#> 923    T-26-0245_Operator_2     FALSE      TRUE
#> 924    T-26-0245_Operator_3     FALSE      TRUE
#> 925    T-26-0245_Operator_4     FALSE      TRUE
#> 926    T-26-0246_Operator_1     FALSE      TRUE
#> 927    T-26-0246_Operator_2     FALSE      TRUE
#> 928    T-26-0246_Operator_3     FALSE      TRUE
#> 929    T-26-0246_Operator_4     FALSE      TRUE
#> 930    T-26-0247_Operator_1     FALSE      TRUE
#> 931    T-26-0247_Operator_2     FALSE      TRUE
#> 932    T-26-0247_Operator_3     FALSE      TRUE
#> 933    T-26-0247_Operator_4     FALSE      TRUE
#> 934    T-26-0248_Operator_1     FALSE      TRUE
#> 935    T-26-0248_Operator_2     FALSE      TRUE
#> 936    T-26-0248_Operator_3     FALSE      TRUE
#> 937    T-26-0248_Operator_4     FALSE      TRUE
#> 938    T-26-0249_Operator_1     FALSE      TRUE
#> 939    T-26-0249_Operator_2     FALSE      TRUE
#> 940    T-26-0249_Operator_3     FALSE      TRUE
#> 941    T-26-0249_Operator_4     FALSE      TRUE
#> 942    T-26-0250_Operator_1     FALSE      TRUE
#> 943    T-26-0250_Operator_2     FALSE      TRUE
#> 944    T-26-0250_Operator_3     FALSE      TRUE
#> 945    T-26-0250_Operator_4     FALSE      TRUE
#> 946    T-26-0251_Operator_1     FALSE      TRUE
#> 947    T-26-0251_Operator_2     FALSE      TRUE
#> 948    T-26-0251_Operator_3     FALSE      TRUE
#> 949    T-26-0251_Operator_4     FALSE      TRUE
#> 950    T-26-0252_Operator_1     FALSE      TRUE
#> 951    T-26-0252_Operator_2     FALSE      TRUE
#> 952    T-26-0252_Operator_3     FALSE      TRUE
#> 953    T-26-0252_Operator_4     FALSE      TRUE
#> 954  T-26-0261-1_Operator_1      TRUE      TRUE
#> 955  T-26-0261-1_Operator_2      TRUE      TRUE
#> 956  T-26-0261-2_Operator_1      TRUE      TRUE
#> 957  T-26-0261-2_Operator_2      TRUE      TRUE
#> 958  T-26-0261-3_Operator_1      TRUE      TRUE
#> 959  T-26-0261-3_Operator_2      TRUE      TRUE
#> 960  T-26-0261-4_Operator_1      TRUE      TRUE
#> 961  T-26-0261-4_Operator_2      TRUE      TRUE
#> 962  T-26-0261-5_Operator_1      TRUE      TRUE
#> 963  T-26-0261-5_Operator_2      TRUE      TRUE
#> 964  T-26-0262-1_Operator_1     FALSE      TRUE
#> 965  T-26-0262-1_Operator_2     FALSE      TRUE
#> 966  T-26-0262-2_Operator_1     FALSE      TRUE
#> 967  T-26-0262-2_Operator_2     FALSE      TRUE
#> 968    T-26-0263_Operator_1      TRUE      TRUE
#> 969    T-26-0263_Operator_2      TRUE      TRUE
#> 970    T-26-0263_Operator_3     FALSE      TRUE
#> 971    T-26-0263_Operator_4      TRUE      TRUE
#> 972  T-26-0264-1_Operator_1      TRUE      TRUE
#> 973  T-26-0264-1_Operator_2      TRUE      TRUE
#> 974  T-26-0264-2_Operator_1      TRUE      TRUE
#> 975  T-26-0264-2_Operator_2      TRUE      TRUE
#> 976  T-26-0264-3_Operator_1      TRUE      TRUE
#> 977  T-26-0264-3_Operator_2      TRUE      TRUE
#> 978  T-26-0264-4_Operator_1      TRUE      TRUE
#> 979  T-26-0264-4_Operator_2      TRUE      TRUE
#> 980    T-26-0265_Operator_1      TRUE      TRUE
#> 981    T-26-0265_Operator_2      TRUE      TRUE
#> 982    T-26-0265_Operator_3     FALSE      TRUE
#> 983    T-26-0265_Operator_4      TRUE      TRUE
#> 984    T-26-0266_Operator_1      TRUE      TRUE
#> 985    T-26-0266_Operator_2      TRUE      TRUE
#> 986    T-26-0266_Operator_3     FALSE      TRUE
#> 987    T-26-0266_Operator_4      TRUE      TRUE
#> 988    T-26-0267_Operator_1     FALSE      TRUE
#> 989    T-26-0267_Operator_2     FALSE      TRUE
#> 990    T-26-0267_Operator_3     FALSE      TRUE
#> 991    T-26-0267_Operator_4     FALSE      TRUE
#> 992    T-26-0268_Operator_1      TRUE      TRUE
#> 993    T-26-0268_Operator_2      TRUE      TRUE
#> 994    T-26-0268_Operator_3     FALSE      TRUE
#> 995    T-26-0268_Operator_4      TRUE      TRUE
#> 996    T-26-0269_Operator_1      TRUE      TRUE
#> 997    T-26-0269_Operator_2      TRUE      TRUE
#> 998    T-26-0269_Operator_3     FALSE      TRUE
#> 999    T-26-0269_Operator_4      TRUE      TRUE
#> 1000 T-26-0270-1_Operator_1      TRUE      TRUE
#> 1001 T-26-0270-1_Operator_2      TRUE      TRUE
#> 1002 T-26-0270-2_Operator_1      TRUE      TRUE
#> 1003 T-26-0270-2_Operator_2      TRUE      TRUE
#> 1004   T-26-0271_Operator_1      TRUE      TRUE
#> 1005   T-26-0271_Operator_2      TRUE      TRUE
#> 1006   T-26-0271_Operator_3     FALSE      TRUE
#> 1007   T-26-0271_Operator_4      TRUE      TRUE
#> 1008   T-26-0272_Operator_1      TRUE      TRUE
#> 1009   T-26-0272_Operator_2      TRUE      TRUE
#> 1010   T-26-0272_Operator_4      TRUE      TRUE
#> 1011   T-26-0273_Operator_1      TRUE      TRUE
#> 1012   T-26-0273_Operator_2      TRUE      TRUE
#> 1013   T-26-0273_Operator_3     FALSE      TRUE
#> 1014   T-26-0273_Operator_4      TRUE      TRUE
#> 1015   T-26-0274_Operator_1      TRUE      TRUE
#> 1016   T-26-0274_Operator_2      TRUE      TRUE
#> 1017   T-26-0274_Operator_3     FALSE      TRUE
#> 1018   T-26-0274_Operator_4      TRUE      TRUE
#> 1019   T-26-0275_Operator_1      TRUE      TRUE
#> 1020   T-26-0275_Operator_2      TRUE      TRUE
#> 1021   T-26-0275_Operator_3     FALSE      TRUE
#> 1022   T-26-0275_Operator_4      TRUE      TRUE
#> 1023   T-26-0276_Operator_1      TRUE      TRUE
#> 1024   T-26-0276_Operator_2      TRUE      TRUE
#> 1025   T-26-0276_Operator_3     FALSE      TRUE
#> 1026   T-26-0276_Operator_4      TRUE      TRUE
#> 1027   T-26-0277_Operator_1      TRUE      TRUE
#> 1028   T-26-0277_Operator_2      TRUE      TRUE
#> 1029   T-26-0277_Operator_4      TRUE      TRUE
#> 1030 T-26-0278-1_Operator_1      TRUE      TRUE
#> 1031 T-26-0278-1_Operator_2      TRUE      TRUE
#> 1032 T-26-0278-2_Operator_1      TRUE      TRUE
#> 1033 T-26-0278-2_Operator_2      TRUE      TRUE
#> 1034   T-26-0279_Operator_1      TRUE      TRUE
#> 1035   T-26-0279_Operator_2      TRUE      TRUE
#> 1036   T-26-0279_Operator_4      TRUE      TRUE
attr(fish_std$coords, "standardization_log")
#>                     specimen scale_factor rotation_deg     y_shift
#> Y       T-26-0001_Operator_1 0.0008402182  -1.07145280  0.36738584
#> Y1      T-26-0001_Operator_2 0.0008392782  -1.41502062  0.36529585
#> Y2      T-26-0001_Operator_3 0.0011609620   0.43341481  0.33066019
#> Y3      T-26-0001_Operator_4 0.0008354680  -1.44412083  0.37758222
#> Y4      T-26-0002_Operator_1 0.0007165890  -3.53802441  0.38665926
#> Y5      T-26-0002_Operator_2 0.0007196833  -3.77269529  0.38736956
#> Y6      T-26-0002_Operator_3 0.0011650605   0.27614362  0.33447822
#> Y7      T-26-0002_Operator_4 0.0007150585  -3.59161624  0.38725673
#> Y8      T-26-0003_Operator_1 0.0008213552  -2.23601041  0.40266940
#> Y9      T-26-0003_Operator_2 0.0008247423  -1.66341376  0.40584165
#> Y10     T-26-0003_Operator_3 0.0011201793   0.13877395  0.40002400
#> Y11     T-26-0003_Operator_4 0.0008219635  -2.00316587  0.40411467
#> Y12     T-26-0004_Operator_1 0.0003258036   0.73595494  0.31999352
#> Y13     T-26-0004_Operator_2 0.0003284431   0.81088820  0.31163786
#> Y14     T-26-0004_Operator_3 0.0011727530   0.14036450  0.31416054
#> Y15     T-26-0004_Operator_4 0.0003231700   0.55410964  0.31501784
#> Y16     T-26-0005_Operator_1 0.0010178117   0.00000000  0.37107684
#> Y17     T-26-0005_Operator_2 0.0010252908  -0.30071464  0.37269271
#> Y18     T-26-0005_Operator_3 0.0011667648   0.53887599  0.35831616
#> Y19     T-26-0005_Operator_4 0.0009966125  -0.17246690  0.38492016
#> Y20     T-26-0006_Operator_1 0.0007803355  -3.42330977  0.39140304
#> Y21     T-26-0006_Operator_2 0.0007815553  -3.83093844  0.40035170
#> Y22     T-26-0006_Operator_3 0.0011588468   0.34766378  0.32171141
#> Y23     T-26-0006_Operator_4 0.0007798080  -3.92694280  0.39230072
#> Y24     T-26-0007_Operator_1 0.0004312514   1.48551818  0.29896482
#> Y25     T-26-0007_Operator_2 0.0004326508   1.63354153  0.29384191
#> Y26     T-26-0007_Operator_3 0.0011383648   0.27748097  0.31338950
#> Y27     T-26-0007_Operator_4 0.0004323876   1.64972265  0.29558878
#> Y28     T-26-0008_Operator_1 0.0004125413  -0.76094726  0.34344059
#> Y29     T-26-0008_Operator_2 0.0004199034   0.10649694  0.34652530
#> Y30     T-26-0008_Operator_3 0.0011607180   0.96867673  0.33932347
#> Y31     T-26-0008_Operator_4 0.0004211150  -0.40774698  0.34668254
#> Y32     T-26-0009_Operator_1 0.0010465725   3.08564115  0.25457875
#> Y33     T-26-0009_Operator_2 0.0010454783   3.57412840  0.25692629
#> Y34     T-26-0009_Operator_3 0.0011509845  -0.13708177  0.30083857
#> Y35     T-26-0009_Operator_4 0.0010363962   3.37154130  0.24466619
#> Y36     T-26-0010_Operator_1 0.0007010165  -3.73913975  0.35921276
#> Y37     T-26-0010_Operator_2 0.0007067138  -3.47578327  0.34946996
#> Y38     T-26-0010_Operator_3 0.0011731188   0.69528135  0.32478632
#> Y39     T-26-0010_Operator_4 0.0006956856  -3.55883761  0.35063074
#> Y40     T-26-0011_Operator_1 0.0003234849   2.18813389  0.32796003
#> Y41     T-26-0011_Operator_2 0.0003260161   1.70440125  0.32422287
#> Y42     T-26-0011_Operator_3 0.0011507848   1.27809592  0.32781672
#> Y43     T-26-0011_Operator_4 0.0003175123   1.81794800  0.42300231
#> Y44     T-26-0012_Operator_1 0.0009564802   6.34722190  0.24175036
#> Y45     T-26-0012_Operator_2 0.0009334166   5.06201325  0.24719998
#> Y46     T-26-0012_Operator_3 0.0011533841   0.82830388  0.33612382
#> Y47     T-26-0012_Operator_4 0.0009647816   5.81452449  0.26114130
#> Y48     T-26-0013_Operator_1 0.0007003620   1.10912316  0.33273044
#> Y49     T-26-0013_Operator_2 0.0007001168   1.32438277  0.32718806
#> Y50     T-26-0013_Operator_3 0.0011181662   0.27547978  0.34114053
#> Y51     T-26-0013_Operator_4 0.0007233514   1.03416233  0.32682534
#> Y52     T-26-0014_Operator_1 0.0007015082   2.29493404  0.30661733
#> Y53     T-26-0014_Operator_2 0.0007094714   2.27003772  0.29780064
#> Y54     T-26-0014_Operator_3 0.0011693363   0.69868316  0.32109155
#> Y55     T-26-0014_Operator_4 0.0007107118   2.26592871  0.30219326
#> Y56     T-26-0015_Operator_1 0.0007819629  -0.57686766  0.31506577
#> Y57     T-26-0015_Operator_2 0.0007889546  -0.76773966  0.30946746
#> Y58     T-26-0015_Operator_3 0.0011932314   0.14039748  0.29570173
#> Y59     T-26-0015_Operator_4 0.0007803727  -0.67184663  0.31404343
#> Y60     T-26-0016_Operator_1 0.0005626404   2.99332753  0.30485773
#> Y61     T-26-0016_Operator_2 0.0005600148   3.23671616  0.30707489
#> Y62     T-26-0016_Operator_3 0.0011795576   0.41918639  0.35175488
#> Y63     T-26-0016_Operator_4 0.0005557074   3.11405863  0.31156683
#> Y64     T-26-0017_Operator_1 0.0008791209  -0.69271119  0.33428571
#> Y65     T-26-0017_Operator_2 0.0008822232  -1.37717801  0.33325981
#> Y66     T-26-0017_Operator_3 0.0011335236   0.00000000  0.31968026
#> Y67     T-26-0017_Operator_4 0.0008929608  -1.03239536  0.33141079
#> Y68     T-26-0018_Operator_1 0.0003405415   0.49381790  0.33092116
#> Y69     T-26-0018_Operator_2 0.0003392130   1.37465002  0.32728392
#> Y70     T-26-0018_Operator_3 0.0011437876   1.10437057  0.32291717
#> Y71     T-26-0018_Operator_4 0.0003543882   0.93296099  0.32272862
#> Y72     T-26-0019_Operator_1 0.0005066285  -1.94293635  0.37748052
#> Y73     T-26-0019_Operator_2 0.0005105948  -1.71716860  0.37686137
#> Y74     T-26-0019_Operator_3 0.0011451331   0.27606793  0.34049747
#> Y75     T-26-0019_Operator_4 0.0005044503  -1.83009946  0.37427334
#> Y76     T-26-0020_Operator_1 0.0007724990  -2.58155773  0.35979143
#> Y77     T-26-0020_Operator_2 0.0007540528  -2.47599517  0.36288831
#> Y78     T-26-0020_Operator_3 0.0012173384  -1.70263896  0.31152993
#> Y79     T-26-0020_Operator_4 0.0007598126  -2.52916172  0.35905324
#> Y80     T-26-0021_Operator_1 0.0007401925  -0.43332116  0.40895633
#> Y81     T-26-0021_Operator_2 0.0007485030  -0.60520216  0.40755988
#> Y82     T-26-0021_Operator_3 0.0011728673   0.14148169  0.39532159
#> Y83     T-26-0021_Operator_4 0.0007482784  -0.51788686  0.39915153
#> Y84     T-26-0022_Operator_1 0.0005910165   4.85523184  0.26625296
#> Y85     T-26-0022_Operator_2 0.0005902028   5.35441400  0.26244339
#> Y86     T-26-0022_Operator_3 0.0011485785   0.27807789  0.35063761
#> Y87     T-26-0022_Operator_4 0.0005907568   5.10447636  0.26721288
#> Y88   T-26-0023-2_Operator_1 0.0014234875  -1.16715492  0.40711744
#> Y89   T-26-0023-2_Operator_2 0.0014409222  -0.99538693  0.40489914
#> Y90     T-26-0023_Operator_3 0.0008746395   1.68469281  0.29130477
#> Y91     T-26-0023_Operator_4 0.0008678604   0.83324414  0.32317691
#> Y92     T-26-0024_Operator_1 0.0006538084  -6.42746549  0.37218045
#> Y93     T-26-0024_Operator_2 0.0006633499  -6.99061724  0.36589254
#> Y94     T-26-0024_Operator_3 0.0011883541  -0.14392498  0.33982684
#> Y95     T-26-0024_Operator_4 0.0006552453  -6.70480739  0.36913768
#> Y96     T-26-0025_Operator_1 0.0006617402  -3.22849334  0.35871846
#> Y97     T-26-0025_Operator_2 0.0006682259  -4.07621158  0.34708787
#> Y98     T-26-0025_Operator_3 0.0012120902  -0.42654523  0.31352694
#> Y99     T-26-0025_Operator_4 0.0006490683  -3.65147044  0.35245380
#> Y100    T-26-0026_Operator_1 0.0006286015  -2.82094819  0.36767939
#> Y101    T-26-0026_Operator_2 0.0006343165  -2.86483041  0.35886457
#> Y102    T-26-0026_Operator_3 0.0011610520  -0.28593245  0.34475607
#> Y103    T-26-0026_Operator_4 0.0006300530  -2.84285659  0.36841406
#> Y104    T-26-0027_Operator_1 0.0006012022   3.43981032  0.31753514
#> Y105    T-26-0027_Operator_2 0.0005999999   3.95680518  0.31280004
#> Y106    T-26-0027_Operator_3 0.0011652272   0.13971278  0.35143353
#> Y107    T-26-0027_Operator_4 0.0005964907   3.69735756  0.31339861
#> Y108    T-26-0028_Operator_1 0.0008306800  -1.86404330  0.36833722
#> Y109    T-26-0028_Operator_2 0.0008445946  -1.57655006  0.35937500
#> Y110    T-26-0028_Operator_3 0.0011706175  -0.14151507  0.36353945
#> Y111    T-26-0028_Operator_4 0.0008302035  -1.72133465  0.36747960
#> Y112    T-26-0029_Operator_1 0.0014644869  -7.76831919  0.36282737
#> Y113    T-26-0029_Operator_2 0.0014886491  -7.55686971  0.35783402
#> Y114    T-26-0029_Operator_3 0.0011115745   0.69867289  0.32992910
#> Y115    T-26-0029_Operator_4 0.0015035695  -7.66265668  0.34679379
#> Y116    T-26-0030_Operator_1 0.0004639295   0.88859798  0.35409418
#> Y117    T-26-0030_Operator_2 0.0004705145   1.27975011  0.35798320
#> Y118    T-26-0030_Operator_3 0.0011461787  -0.41824230  0.36989990
#> Y119    T-26-0030_Operator_4 0.0004622894   1.08367898  0.36132704
#> Y120    T-26-0031_Operator_1 0.0007486896  -5.48642037  0.37309711
#> Y121    T-26-0031_Operator_2 0.0007462687  -5.32023391  0.37238806
#> Y122    T-26-0031_Operator_3 0.0011361559   0.00000000  0.37169554
#> Y123    T-26-0031_Operator_4 0.0007590035  -5.40409349  0.36554177
#> Y124    T-26-0032_Operator_1 0.0003701647   3.21265877  0.32768832
#> Y125    T-26-0032_Operator_2 0.0003719776   4.05124021  0.32535652
#> Y126    T-26-0032_Operator_3 0.0011261438   0.27814151  0.34821194
#> Y127    T-26-0032_Operator_4 0.0003770057   3.63209445  0.32826864
#> Y128    T-26-0033_Operator_1 0.0006875215   0.44342081  0.35183912
#> Y129    T-26-0033_Operator_2 0.0006904490   0.93717554  0.35017258
#> Y130    T-26-0033_Operator_3 0.0011282025   0.13907807  0.35615418
#> Y131    T-26-0033_Operator_4 0.0006899211   0.69083304  0.35033747
#> Y132    T-26-0034_Operator_1 0.0007114906  -6.78502250  0.36564710
#> Y133    T-26-0034_Operator_2 0.0007111531  -8.83096277  0.35125024
#> Y134    T-26-0034_Operator_3 0.0011372471   1.49671906  0.33428686
#> Y135    T-26-0034_Operator_4 0.0007215965  -7.80960080  0.36510547
#> Y136    T-26-0035_Operator_1 0.0009263548   0.46848796  0.37849282
#> Y137    T-26-0035_Operator_2 0.0009380863   1.09068011  0.37601595
#> Y138    T-26-0035_Operator_3 0.0011024490  -0.28295075  0.38177187
#> Y139    T-26-0035_Operator_4 0.0009800270   0.78096109  0.35991493
#> Y140    T-26-0036_Operator_1 0.0004345621   0.02428668  0.36217124
#> Y141    T-26-0036_Operator_2 0.0004397537   0.15992183  0.36565523
#> Y142    T-26-0036_Operator_4 0.0004389066   0.09218175  0.36056639
#> Y143    T-26-0037_Operator_1 0.0003532738   2.00606711  0.35757168
#> Y144    T-26-0037_Operator_2 0.0003577818   3.03320357  0.34895635
#> Y145    T-26-0037_Operator_4 0.0003611133   2.52093073  0.34635315
#> Y146    T-26-0038_Operator_1 0.0008183306   2.20585805  0.34656301
#> Y147    T-26-0038_Operator_2 0.0008220304   2.59350644  0.34381422
#> Y148    T-26-0038_Operator_4 0.0008356725   2.39892129  0.33664859
#> Y149    T-26-0039_Operator_1 0.0007429421  -0.29269024  0.34583952
#> Y150    T-26-0039_Operator_2 0.0007485030  -1.57517445  0.34131737
#> Y151    T-26-0039_Operator_4 0.0007407067  -0.93510831  0.34787291
#> Y152    T-26-0040_Operator_1 0.0006644518   5.84502388  0.33521595
#> Y153    T-26-0040_Operator_2 0.0006761325   6.52306621  0.32251521
#> Y154    T-26-0040_Operator_3 0.0011227395  -0.13877395  0.40921363
#> Y155    T-26-0040_Operator_4 0.0006696452   6.18142261  0.28637111
#> Y156    T-26-0041_Operator_1 0.0008873114  -4.15434169  0.39751553
#> Y157    T-26-0041_Operator_2 0.0009037506  -3.35415751  0.38959150
#> Y158    T-26-0041_Operator_3 0.0011498749   0.00000000  0.35499541
#> Y159    T-26-0041_Operator_4 0.0008852934  -3.75898654  0.38812193
#> Y160    T-26-0042_Operator_1 0.0006172840   2.66693986  0.28364198
#> Y161    T-26-0042_Operator_2 0.0006165228   2.72241796  0.28534710
#> Y162    T-26-0042_Operator_3 0.0011620485   0.41415741  0.32312707
#> Y163    T-26-0042_Operator_4 0.0006109542   2.69460425  0.29355248
#> Y164    T-26-0043_Operator_1 0.0006995453  -3.27854850  0.39751661
#> Y165    T-26-0043_Operator_2 0.0007072136  -3.72378159  0.39603960
#> Y166    T-26-0043_Operator_3 0.0011531442   0.28087037  0.33334046
#> Y167    T-26-0043_Operator_4 0.0006981997  -3.49882941  0.39491047
#> Y168    T-26-0044_Operator_1 0.0006706908   2.76203155  0.27900738
#> Y169    T-26-0044_Operator_2 0.0006668890   1.94717219  0.28392798
#> Y170    T-26-0044_Operator_3 0.0011639888   1.10967420  0.31262911
#> Y171    T-26-0044_Operator_4 0.0006713261   2.35722246  0.27365837
#> Y172    T-26-0045_Operator_1 0.0004052685  -1.38148481  0.34120243
#> Y173    T-26-0045_Operator_2 0.0004117768  -2.21146030  0.34084826
#> Y174    T-26-0045_Operator_3 0.0011600014   0.09209361  0.30459948
#> Y175    T-26-0045_Operator_4 0.0004045448  -1.79413292  0.33875289
#> Y176    T-26-0046_Operator_1 0.0006608656   0.75507846  0.33158964
#> Y177    T-26-0046_Operator_2 0.0006609385   1.64977927  0.32474091
#> Y178    T-26-0046_Operator_3 0.0011450370  -0.42237541  0.35046108
#> Y179    T-26-0046_Operator_4 0.0006622569   1.19410471  0.32407675
#> Y180    T-26-0047_Operator_1 0.0003581233   1.61539182  0.31861052
#> Y181    T-26-0047_Operator_2 0.0003631962   1.88239494  0.30587165
#> Y182    T-26-0047_Operator_3 0.0011599218   0.13903454  0.33817607
#> Y183    T-26-0047_Operator_4 0.0003622511   1.74875532  0.30313101
#> Y184    T-26-0048_Operator_1 0.0005961252  -3.70850270  0.39418778
#> Y185    T-26-0048_Operator_2 0.0006033183  -3.70822611  0.39291101
#> Y186    T-26-0048_Operator_3 0.0011569308  -0.28365133  0.33032662
#> Y187    T-26-0048_Operator_4 0.0006068322  -3.70836819  0.39241593
#> Y188    T-26-0049_Operator_1 0.0004287245  -5.11923083  0.39046088
#> Y189    T-26-0049_Operator_2 0.0004331817  -4.88735434  0.37805935
#> Y190    T-26-0049_Operator_3 0.0011463606   0.84045427  0.31562619
#> Y191    T-26-0049_Operator_4 0.0004341719  -5.00350797  0.38348518
#> Y192    T-26-0050_Operator_1 0.0007482230  -2.94698307  0.37866293
#> Y193    T-26-0050_Operator_2 0.0007607455  45.00000000 -0.50000000
#> Y194    T-26-0050_Operator_4 0.0007400467  25.25048175  0.01343629
#> Y195    T-26-0051_Operator_1 0.0006073489  -1.15179722  0.32903128
#> Y196    T-26-0051_Operator_2 0.0006047777  -0.69104233  0.33005745
#> Y197    T-26-0051_Operator_3 0.0012002229  -0.28018345  0.30679978
#> Y198    T-26-0051_Operator_4 0.0006040168  -0.92184911  0.34427359
#> Y199    T-26-0052_Operator_1 0.0003614676  33.64769527 -0.26775709
#> Y200    T-26-0052_Operator_2 0.0003631741  -6.38865393  0.38069729
#> Y201    T-26-0052_Operator_3 0.0011669531  17.63725884  0.05191752
#> Y202    T-26-0052_Operator_4 0.0003553712 -21.26291213  0.34955111
#> Y203    T-26-0053_Operator_1 0.0003732272   3.72510109  0.32489411
#> Y204    T-26-0053_Operator_2 0.0003749531   3.98583071  0.31583540
#> Y205    T-26-0053_Operator_3 0.0011401030   0.27883132  0.38152578
#> Y206    T-26-0053_Operator_4 0.0003758089   3.85547482  0.31735951
#> Y207    T-26-0054_Operator_1 0.0004085523   2.30068829  0.34291164
#> Y208    T-26-0054_Operator_2 0.0004137930   2.25222790  0.33731023
#> Y209    T-26-0054_Operator_3 0.0011251625   0.41717285  0.36473939
#> Y210    T-26-0054_Operator_4 0.0004150096   2.27645018  0.33454689
#> Y211    T-26-0055_Operator_1 0.0006035003   2.06183769  0.35003018
#> Y212    T-26-0055_Operator_2 0.0006071645   2.67092878  0.34244080
#> Y213    T-26-0055_Operator_3 0.0011610115   0.28721698  0.36677393
#> Y214    T-26-0055_Operator_4 0.0005999394   2.36591696  0.35135421
#> Y215  T-26-0056-2_Operator_1 0.0004553734   2.74629009  0.27709472
#> Y216  T-26-0056-2_Operator_2 0.0004512635   3.78377244  0.27414260
#> Y217    T-26-0056_Operator_3 0.0014209961   1.20423985  0.32058199
#> Y218    T-26-0056_Operator_4 0.0003111620  -3.94558037  0.40419571
#> Y219    T-26-0057_Operator_1 0.0006677796  -0.43476172  0.36789115
#> Y220    T-26-0057_Operator_2 0.0006668890  -0.20135099  0.37095699
#> Y221    T-26-0057_Operator_3 0.0011462923   0.27614362  0.35948425
#> Y222    T-26-0057_Operator_4 0.0006745117  -0.31874980  0.32814252
#> Y223    T-26-0058_Operator_1 0.0005984440   5.74487421  0.28545781
#> Y224    T-26-0058_Operator_2 0.0006119951   5.55589548  0.27539780
#> Y225    T-26-0058_Operator_3 0.0011347484   0.85293212  0.34291839
#> Y226    T-26-0058_Operator_4 0.0006157742   5.65059761  0.27433478
#> Y227    T-26-0059_Operator_1 0.0005915410   1.57334404  0.33466430
#> Y228    T-26-0059_Operator_2 0.0006018053   1.60001203  0.33871618
#> Y229    T-26-0059_Operator_3 0.0011563889   0.56310700  0.35213577
#> Y230    T-26-0059_Operator_4 0.0005892058   1.58663148  0.35122555
#> Y231    T-26-0060_Operator_1 0.0006540222   0.96520636  0.34924787
#> Y232    T-26-0060_Operator_2 0.0006675567   1.77890412  0.33444593
#> Y233    T-26-0060_Operator_3 0.0011936801   0.28721698  0.35571329
#> Y234    T-26-0060_Operator_4 0.0006589121   1.37059785  0.33579053
#> Y235    T-26-0061_Operator_1 0.0003870468   4.36496226  0.30305782
#> Y236    T-26-0061_Operator_2 0.0003895598   4.30557701  0.29723413
#> Y237    T-26-0061_Operator_3 0.0011497169   0.00000000  0.36895091
#> Y238    T-26-0061_Operator_4 0.0003873918   4.33523534  0.28620544
#> Y239    T-26-0062_Operator_1 0.0003113325   3.02919335  0.29031756
#> Y240    T-26-0062_Operator_2 0.0003126954   3.43204019  0.28595997
#> Y241    T-26-0062_Operator_3 0.0011442022   0.27481947  0.33851972
#> Y242    T-26-0062_Operator_4 0.0003099282   3.23122777  0.28273167
#> Y243    T-26-0063_Operator_1 0.0008572653  -2.82152766  0.35297900
#> Y244    T-26-0063_Operator_2 0.0008760403  -2.57758412  0.35501533
#> Y245    T-26-0063_Operator_3 0.0011522491   0.13975655  0.36568067
#> Y246    T-26-0063_Operator_4 0.0008676571  -2.69972809  0.35110657
#> Y247    T-26-0064_Operator_1 0.0006821282   2.55758825  0.37619372
#> Y248    T-26-0064_Operator_2 0.0006882312   2.77134016  0.36315692
#> Y249    T-26-0064_Operator_3 0.0011503260   0.13971278  0.38979399
#> Y250    T-26-0064_Operator_4 0.0006839917   2.66389588  0.34607450
#> Y251    T-26-0065_Operator_1 0.0006677796   0.24027826  0.35275459
#> Y252    T-26-0065_Operator_2 0.0006754475  -0.24156759  0.35804323
#> Y253    T-26-0065_Operator_3 0.0011863816   0.55898719  0.34326529
#> Y254    T-26-0065_Operator_4 0.0006706368   0.00000000  0.35730994
#> Y255    T-26-0067_Operator_1 0.0004968122  -0.70916973  0.36461867
#> Y256    T-26-0067_Operator_2 0.0005059449  -0.60564107  0.35825095
#> Y257    T-26-0067_Operator_3 0.0011449540   0.84458400  0.36441995
#> Y258    T-26-0067_Operator_4 0.0005062004  -0.65740496  0.35918516
#> Y259    T-26-0068_Operator_1 0.0004003203   3.64594235  0.28562850
#> Y260    T-26-0068_Operator_2 0.0004043672   5.98008900  0.25299919
#> Y261    T-26-0068_Operator_3 0.0011567970  -0.83030559  0.36639942
#> Y262    T-26-0068_Operator_4 0.0004054077   4.81171367  0.31012165
#> Y263    T-26-0069_Operator_1 0.0005552471   7.14030317  0.23042754
#> Y264    T-26-0069_Operator_2 0.0005627462   7.21287633  0.23016320
#> Y265    T-26-0069_Operator_3 0.0011504082  -0.14044150  0.33864095
#> Y266    T-26-0069_Operator_4 0.0005625718   7.17659368  0.23420059
#> Y267    T-26-0070_Operator_1 0.0005123389  -3.62613927  0.37780717
#> Y268    T-26-0070_Operator_2 0.0005177323  -3.31224577  0.37237898
#> Y269    T-26-0070_Operator_3 0.0011428530  -0.14078659  0.34081940
#> Y270    T-26-0070_Operator_4 0.0005145129  -3.46858487  0.37054856
#> Y271    T-26-0071_Operator_1 0.0005880623   0.92436251  0.35327845
#> Y272    T-26-0071_Operator_2 0.0005893332   2.08959851  0.34353204
#> Y273    T-26-0071_Operator_3 0.0011421008  -0.41816643  0.37209481
#> Y274    T-26-0071_Operator_4 0.0005803487   1.50728993  0.35870540
#> Y275    T-26-0072_Operator_1 0.0005298482   1.07714890  0.36091485
#> Y276    T-26-0072_Operator_2 0.0005344735   1.06582942  0.35774078
#> Y277    T-26-0072_Operator_3 0.0011485317  -0.27481947  0.37043623
#> Y278    T-26-0072_Operator_4 0.0005246119   1.07149225  0.32954625
#> Y279    T-26-0073_Operator_1 0.0005047956   4.06569678  0.29732458
#> Y280    T-26-0073_Operator_2 0.0005064573   4.31887040  0.29716384
#> Y281    T-26-0073_Operator_3 0.0011571955   0.28288447  0.36453813
#> Y282    T-26-0073_Operator_4 0.0004927550   4.19097815  0.31131572
#> Y283    T-26-0074_Operator_1 0.0005040323   3.94108106  0.29561492
#> Y284    T-26-0074_Operator_2 0.0005120766   1.53449506  0.29457178
#> Y285    T-26-0074_Operator_3 0.0011602321  -0.14044150  0.35169703
#> Y286    T-26-0074_Operator_4 0.0005047831   2.74453625  0.31912613
#> Y287    T-26-0075_Operator_1 0.0004264696  -1.40554990  0.33801277
#> Y288    T-26-0075_Operator_2 0.0004281738   0.43016125  0.34864055
#> Y289    T-26-0075_Operator_3 0.0011702937  -1.55967079  0.37200314
#> Y290    T-26-0075_Operator_4 0.0004158711  -0.48640931  0.33986591
#> Y291    T-26-0076_Operator_1 0.0004187605   8.88894248  0.24727806
#> Y292    T-26-0076_Operator_2 0.0004139645   9.62201647  0.25169042
#> Y293    T-26-0076_Operator_3 0.0011063656   0.00000000  0.37505971
#> Y294    T-26-0076_Operator_4 0.0004165570   9.25423937  0.26118455
#> Y295    T-26-0077_Operator_1 0.0006337136   5.14298223  0.29119138
#> Y296    T-26-0077_Operator_2 0.0006382981   4.41871902  0.29457459
#> Y297    T-26-0077_Operator_3 0.0011382056   0.59260845  0.37257854
#> Y298    T-26-0077_Operator_4 0.0006511120   4.77993587  0.30114387
#> Y299    T-26-0078_Operator_1 0.0003944255   0.84221204  0.39738350
#> Y300    T-26-0078_Operator_2 0.0003994408   0.65854318  0.40766247
#> Y301    T-26-0078_Operator_3 0.0011405866  -0.96402015  0.41419271
#> Y302    T-26-0078_Operator_4 0.0003861906   0.75157082  0.39193615
#> Y303    T-26-0079_Operator_1 0.0004805382  -0.91359838  0.36328688
#> Y304    T-26-0079_Operator_2 0.0004864208  -0.95935832  0.36112685
#> Y305    T-26-0079_Operator_3 0.0011152108  -0.28648791  0.35708478
#> Y306    T-26-0079_Operator_4 0.0004867833  -0.93649218  0.35915362
#> Y307    T-26-0080_Operator_1 0.0005740528   0.85688168  0.36748967
#> Y308    T-26-0080_Operator_2 0.0005797101   1.01886926  0.36753623
#> Y309    T-26-0080_Operator_3 0.0011217509  -0.07955264  0.37691811
#> Y310    T-26-0080_Operator_4 0.0005864146   0.93777423  0.37222553
#> Y311    T-26-0081_Operator_1 0.0006787332   7.44337076  0.22884609
#> Y312    T-26-0081_Operator_2 0.0006720430   6.80257227  0.23017473
#> Y313    T-26-0081_Operator_3 0.0011476060  -0.49891537  0.35311633
#> Y314    T-26-0081_Operator_4 0.0006497017   7.12215557  0.24447234
#> Y315    T-26-0082_Operator_1 0.0006238303   6.14598518  0.27573300
#> Y316    T-26-0082_Operator_2 0.0006177927   8.27853668  0.26348858
#> Y317    T-26-0082_Operator_3 0.0011238419  -0.56035424  0.36724798
#> Y318    T-26-0082_Operator_4 0.0006167936   7.21083902  0.27830959
#> Y319    T-26-0083_Operator_1 0.0009904256   6.26697605  0.29778779
#> Y320    T-26-0083_Operator_2 0.0009876543   6.95543999  0.28584395
#> Y321    T-26-0083_Operator_3 0.0011132637   0.28157147  0.39942457
#> Y322    T-26-0083_Operator_4 0.0009781271   6.61182804  0.30243299
#> Y323    T-26-0084_Operator_1 0.0008179959  -7.30295245  0.38425358
#> Y324    T-26-0084_Operator_2 0.0008240626  -8.90988101  0.37213267
#> Y325    T-26-0084_Operator_3 0.0011259520   0.98533452  0.34236413
#> Y326    T-26-0084_Operator_4 0.0008253910  -8.11213135  0.37191500
#> Y327    T-26-0085_Operator_1 0.0006651147   0.38151737  0.37994679
#> Y328    T-26-0085_Operator_2 0.0006724950  -0.37914131  0.37547613
#> Y329    T-26-0085_Operator_3 0.0011510299  -0.27883132  0.38710286
#> Y330    T-26-0085_Operator_4 0.0006595819   0.00000000  0.37500000
#> Y331    T-26-0086_Operator_1 0.0004509923   1.00666725  0.35590798
#> Y332    T-26-0086_Operator_2 0.0004545455   1.73476644  0.34863636
#> Y333    T-26-0086_Operator_3 0.0011627332   0.09562981  0.37434176
#> Y334    T-26-0086_Operator_4 0.0004570825   1.36519819  0.34994120
#> Y335    T-26-0087_Operator_1 0.0005401026  -0.74030767  0.34364029
#> Y336    T-26-0087_Operator_2 0.0005339028   0.27274840  0.34329952
#> Y337    T-26-0087_Operator_3 0.0011484380  -1.50604385  0.33157041
#> Y338    T-26-0087_Operator_4 0.0005335231  -0.23553594  0.39766920
#> Y339    T-26-0088_Operator_1 0.0005196155  -5.36067591  0.40465056
#> Y340    T-26-0088_Operator_2 0.0005220569  -6.13719251  0.37357505
#> Y341    T-26-0088_Operator_3 0.0011553561  -0.09362789  0.37111378
#> Y342    T-26-0088_Operator_4 0.0005183695  -5.74750350  0.37309953
#> Y343    T-26-0089_Operator_1 0.0011428571   7.91674180  0.27942857
#> Y344    T-26-0089_Operator_2 0.0011540681   8.45136303  0.26283901
#> Y345    T-26-0089_Operator_3 0.0011286290  -0.22045753  0.39753241
#> Y346    T-26-0089_Operator_4 0.0011348703   8.18242643  0.24129157
#> Y347    T-26-0090_Operator_1 0.0008419869  -1.00819593  0.38984033
#> Y348    T-26-0090_Operator_2 0.0008453085  -0.06768770  0.39842181
#> Y349    T-26-0090_Operator_3 0.0011218769   0.00000000  0.39065804
#> Y350    T-26-0090_Operator_4 0.0008411752  -0.53502373  0.38422906
#> Y351    T-26-0091_Operator_1 0.0004346881  -3.70185255  0.38082286
#> Y352    T-26-0091_Operator_2 0.0004477278  -3.60336376  0.36948735
#> Y353    T-26-0091_Operator_3 0.0011826404  -0.28435501  0.37541675
#> Y354    T-26-0091_Operator_4 0.0004403011  -3.65328242  0.36862295
#> Y355    T-26-0092_Operator_1 0.0004501463  -7.38666391  0.38333693
#> Y356    T-26-0092_Operator_2 0.0004527960  -7.72958650  0.36484039
#> Y357    T-26-0092_Operator_3 0.0011369517   0.42021134  0.34173659
#> Y358    T-26-0092_Operator_4 0.0004432746  -7.55682203  0.36566696
#> Y359    T-26-0093_Operator_1 0.0004782783  -5.10338805  0.35005976
#> Y360    T-26-0093_Operator_2 0.0004864996  -4.97601056  0.34456337
#> Y361    T-26-0093_Operator_3 0.0011615365  -0.41413628  0.36572638
#> Y362    T-26-0093_Operator_4 0.0004733517  -5.04011145  0.34926635
#> Y363    T-26-0094_Operator_1 0.0005603811  -5.89562065  0.38203979
#> Y364    T-26-0094_Operator_2 0.0005725737  -5.88895264  0.37374749
#> Y365    T-26-0094_Operator_3 0.0011437268  -0.27951144  0.37449837
#> Y366    T-26-0094_Operator_4 0.0005782185  -5.89229566  0.37873023
#> Y367    T-26-0095_Operator_1 0.0005231494  -8.38735887  0.39563170
#> Y368    T-26-0095_Operator_2 0.0005231494  -7.84716593  0.37836777
#> Y369    T-26-0095_Operator_3 0.0011777996   0.56172725  0.31350887
#> Y370    T-26-0095_Operator_4 0.0005222109  -8.11949604  0.38490105
#> Y371    T-26-0096_Operator_1 0.0006163328 -11.32589452  0.39553159
#> Y372    T-26-0096_Operator_2 0.0006248047 -11.07124626  0.36972821
#> Y373    T-26-0096_Operator_3 0.0011223425  -0.14009809  0.32323320
#> Y374    T-26-0096_Operator_4 0.0006239755 -11.19978307  0.37642040
#> Y375    T-26-0097_Operator_1 0.0004365859  -3.07640819  0.39179961
#> Y376    T-26-0097_Operator_2 0.0004354452  -3.06988881  0.38961463
#> Y377    T-26-0097_Operator_3 0.0011410253  -1.12056728  0.37459302
#> Y378    T-26-0097_Operator_4 0.0004421639  -3.07315064  0.38778323
#> Y379    T-26-0098_Operator_1 0.0004963599   3.89961680  0.33049308
#> Y380    T-26-0098_Operator_2 0.0004943154   4.69984585  0.32081068
#> Y381    T-26-0098_Operator_3 0.0011156314   0.14044169  0.38214151
#> Y382    T-26-0098_Operator_4 0.0004941444   4.29620363  0.32103770
#> Y383    T-26-0099_Operator_1 0.0009188364   2.51327692  0.31424160
#> Y384    T-26-0099_Operator_2 0.0009068921   2.17315017  0.31574945
#> Y385    T-26-0099_Operator_3 0.0011270480   0.09329349  0.34993867
#> Y386    T-26-0099_Operator_4 0.0009101301   2.34307624  0.32358402
#> Y387    T-26-0100_Operator_1 0.0005871991   2.14988672  0.36523782
#> Y388    T-26-0100_Operator_2 0.0005863957   1.87686384  0.37128614
#> Y389    T-26-0100_Operator_3 0.0011074893  -0.13907789  0.37735660
#> Y390    T-26-0100_Operator_4 0.0006153112   2.01387653  0.33501662
#> Y391    T-26-0101_Operator_1 0.0005409792  -1.98119667  0.33310793
#> Y392    T-26-0101_Operator_2 0.0005356186  -1.75914542  0.35002678
#> Y393    T-26-0101_Operator_3 0.0011416233  -0.26838336  0.32065433
#> Y394    T-26-0101_Operator_4 0.0005328576  -1.86837121  0.35217038
#> Y395    T-26-0102_Operator_1 0.0005323396  -0.88753356  0.37090764
#> Y396    T-26-0102_Operator_2 0.0005257624  -1.14611540  0.36934805
#> Y397    T-26-0102_Operator_3 0.0011198462   0.41314072  0.34581265
#> Y398    T-26-0102_Operator_4 0.0005326958  -1.01856375  0.36972125
#> Y399    T-26-0103_Operator_1 0.0004124562  -1.30286815  0.35667148
#> Y400    T-26-0103_Operator_2 0.0004191993  -1.91685037  0.36187382
#> Y401    T-26-0103_Operator_3 0.0011814700   0.14013102  0.32761770
#> Y402    T-26-0103_Operator_4 0.0004101580  -1.60802254  0.36602354
#> Y403    T-26-0104_Operator_1 0.0004273504  -1.86156578  0.36858974
#> Y404    T-26-0104_Operator_2 0.0004379242  -2.82468365  0.37497263
#> Y405    T-26-0104_Operator_3 0.0011358092  -0.07338172  0.34110668
#> Y406    T-26-0104_Operator_4 0.0004220154  -2.34307416  0.37065947
#> Y407    T-26-0107_Operator_1 0.0003761520  -1.23457686  0.34446116
#> Y408    T-26-0107_Operator_2 0.0003712872  -1.01545718  0.37320543
#> Y409    T-26-0107_Operator_3 0.0011211048   0.30782061  0.37839360
#> Y410    T-26-0107_Operator_4 0.0003804865  -1.12555927  0.36716188
#> Y411    T-26-0108_Operator_1 0.0004295533   0.10355539  0.33354811
#> Y412    T-26-0108_Operator_2 0.0004339336  -2.78209566  0.33358646
#> Y413    T-26-0108_Operator_3 0.0011373148   1.64833312  0.32530616
#> Y414    T-26-0108_Operator_4 0.0004352205  -1.34567611  0.41785083
#> Y415    T-26-0109_Operator_1 0.0004316857  -1.75325710  0.37589035
#> Y416    T-26-0109_Operator_2 0.0004200503  -0.64795179  0.38049568
#> Y417    T-26-0109_Operator_3 0.0011014026   0.46209629  0.37962480
#> Y418    T-26-0109_Operator_4 0.0004259555  -1.19889498  0.37721747
#> Y419    T-26-0111_Operator_1 0.0011337868  -4.38590326  0.43707483
#> Y420    T-26-0111_Operator_2 0.0011841326  -4.04201933  0.41533452
#> Y421    T-26-0111_Operator_3 0.0011250402  -0.17936047  0.41503196
#> Y422    T-26-0111_Operator_4 0.0011934484  -4.21200893  0.39564009
#> Y423  T-26-0112-2_Operator_1 0.0005815644   2.32394369  0.32175051
#> Y424  T-26-0112-2_Operator_2 0.0005787037   2.93416130  0.32031250
#> Y425    T-26-0112_Operator_1 0.0009548062   4.48924407  0.30887932
#> Y426    T-26-0112_Operator_2 0.0009557187   4.14559727  0.31156381
#> Y427    T-26-0112_Operator_4 0.0028555274  12.16183048  0.24994146
#> Y428    T-26-0113_Operator_1 0.0005664118  -3.45946585  0.44477485
#> Y429    T-26-0113_Operator_2 0.0005676980  -7.35988821  0.41607550
#> Y430    T-26-0113_Operator_3 0.0011300266   2.22030635  0.36141079
#> Y431    T-26-0113_Operator_4 0.0005607358  -5.42580334  0.44193861
#> Y432    T-26-0114_Operator_1 0.0005041593  -0.65326717  0.39185783
#> Y433    T-26-0114_Operator_2 0.0004102283  -1.27941701  0.39997280
#> Y434    T-26-0114_Operator_3 0.0012152059   0.75296839  0.38160119
#> Y435    T-26-0114_Operator_4 0.0004508932  -0.99841459  0.39961133
#> Y436    T-26-0115_Operator_1 0.0004129672  -0.67404648  0.40811480
#> Y437    T-26-0115_Operator_2 0.0005047107   1.77590528  0.33773550
#> Y438    T-26-0115_Operator_3 0.0009970094  -1.69216613  0.40076541
#> Y439    T-26-0115_Operator_4 0.0004693915   0.42312860  0.44021032
#> Y440    T-26-0116_Operator_1 0.0005068424   2.48955292  0.32387228
#> Y441    T-26-0116_Operator_2 0.0004920855  -4.04380987  0.38099748
#> Y442    T-26-0116_Operator_3 0.0011005503   3.20065020  0.31263949
#> Y443    T-26-0116_Operator_4 0.0005098810  -0.88460568  0.42702073
#> Y444    T-26-0117_Operator_1 0.0004900760  -3.12880985  0.38948787
#> Y445    T-26-0117_Operator_2 0.0004508566   0.98802242  0.36496844
#> Y446    T-26-0117_Operator_4 0.0004503857  -0.97211257  0.39428951
#> Y447    T-26-0118_Operator_1 0.0004515354   0.47473710  0.36882898
#> Y448    T-26-0118_Operator_2 0.0004897160  -4.13307062  0.38132566
#> Y449    T-26-0118_Operator_3 0.0010957585   1.42766894  0.34924202
#> Y450    T-26-0118_Operator_4 0.0004591322  -1.70830083  0.43417100
#> Y451    T-26-0120_Operator_1 0.0005701254   0.70403094  0.36573546
#> Y452    T-26-0120_Operator_2 0.0005728469   3.82095157  0.36795878
#> Y453    T-26-0120_Operator_3 0.0011442304  -1.39037867  0.37222932
#> Y454    T-26-0120_Operator_4 0.0005710934   2.24812710  0.35207138
#> Y455    T-26-0121_Operator_1 0.0005329070   1.50324907  0.32067679
#> Y456    T-26-0121_Operator_2 0.0018018018  45.00000000 -0.10270270
#> Y457    T-26-0121_Operator_4 0.0010175942   2.93289304  0.37109320
#> Y458    T-26-0122_Operator_1 0.0004349085   5.01794661  0.25956821
#> Y459    T-26-0122_Operator_2 0.0004335887   3.89680099  0.26578968
#> Y460    T-26-0122_Operator_3 0.0011597579   0.27950062  0.31445986
#> Y461    T-26-0122_Operator_4 0.0004394488   4.45669958  0.26150587
#> Y462    T-26-0123_Operator_1 0.0004712535   7.73480495  0.25518379
#> Y463    T-26-0123_Operator_2 0.0004767201   6.81910779  0.25425079
#> Y464    T-26-0123_Operator_3 0.0011015122   0.00000000  0.37322750
#> Y465    T-26-0123_Operator_4 0.0004851049   7.27850722  0.24857306
#> Y466    T-26-0125_Operator_1 0.0005619556  -2.88215169  0.39688115
#> Y467    T-26-0125_Operator_2 0.0005606953  -3.06946954  0.38029156
#> Y468    T-26-0125_Operator_3 0.0011496852   0.28264052  0.35650395
#> Y469    T-26-0125_Operator_4 0.0005538635  -2.97640179  0.38613286
#> Y470    T-26-0126_Operator_1 0.0005602241  -0.92985979  0.36974790
#> Y471    T-26-0126_Operator_2 0.0005652911  -2.70523672  0.36706218
#> Y472    T-26-0126_Operator_4 0.0005510158  -1.81699296  0.37918097
#> Y473    T-26-0127_Operator_1 0.0004330879   2.68039126  0.35383283
#> Y474    T-26-0127_Operator_2 0.0004384042   3.52215533  0.34765454
#> Y475    T-26-0127_Operator_3 0.0011044798  -0.55537532  0.36510848
#> Y476    T-26-0127_Operator_4 0.0004467044   3.09908368  0.34817859
#> Y477    T-26-0128_Operator_1 0.0005356186   1.98003479  0.40064274
#> Y478    T-26-0128_Operator_2 0.0005361930   2.74585010  0.38873995
#> Y479    T-26-0128_Operator_3 0.0011127271   0.18605743  0.21220093
#> Y480    T-26-0128_Operator_4 0.0005459791   2.36115899  0.38863337
#> Y481    T-26-0130_Operator_1 0.0008754015   5.17382605  0.38459320
#> Y482    T-26-0130_Operator_2 0.0008784776   4.93083429  0.38096629
#> Y483    T-26-0130_Operator_3 0.0011024629  -0.56172801  0.42282254
#> Y484    T-26-0130_Operator_4 0.0008999410   5.05218575  0.35297394
#> Y485    T-26-0131_Operator_1 0.0006385696   5.47157126  0.29342273
#> Y486    T-26-0131_Operator_2 0.0006376872   5.56057523  0.28648129
#> Y487    T-26-0131_Operator_3 0.0010953846   0.36844555  0.38379585
#> Y488    T-26-0131_Operator_4 0.0006293203   5.51588576  0.28553016
#> Y489    T-26-0132_Operator_1 0.0006830601   2.88135925  0.27493169
#> Y490    T-26-0132_Operator_2 0.0006891799   1.83421979  0.27498277
#> Y491    T-26-0132_Operator_3 0.0011137389  -0.18598083  0.32181446
#> Y492    T-26-0132_Operator_4 0.0006817102   2.35717373  0.28073337
#> Y493    T-26-0133_Operator_1 0.0006837607  -4.08080187  0.43538462
#> Y494    T-26-0133_Operator_2 0.0006944444  -2.52577658  0.40451389
#> Y495    T-26-0133_Operator_3 0.0011279786   0.28459073  0.37000029
#> Y496    T-26-0133_Operator_4 0.0006927837  -3.31411608  0.41190563
#> Y497    T-26-0134_Operator_1 0.0007125045  -0.94599819  0.36284289
#> Y498    T-26-0134_Operator_2 0.0007173601  -0.11716912  0.35581062
#> Y499    T-26-0134_Operator_3 0.0011512952  -0.27724640  0.35587022
#> Y500    T-26-0134_Operator_4 0.0007093949  -0.53479146  0.36599033
#> Y501    T-26-0135_Operator_1 0.0006629102  -2.32601605  0.39691747
#> Y502    T-26-0135_Operator_2 0.0006702413  -0.20229889  0.35891421
#> Y503    T-26-0135_Operator_3 0.0011567812   0.64374571  0.33964903
#> Y504    T-26-0135_Operator_4 0.0006632175  -1.27203883  0.38943567
#> Y505    T-26-0136_Operator_1 0.0006666667  -1.52479576  0.37233333
#> Y506    T-26-0136_Operator_2 0.0006663704  -0.29781624  0.36339408
#> Y507    T-26-0136_Operator_3 0.0011310190   0.55447982  0.35039041
#> Y508    T-26-0136_Operator_4 0.0006693597  -0.91336670  0.37012480
#> Y509    T-26-0137_Operator_1 0.0003782864  -2.57110972  0.38254208
#> Y510    T-26-0137_Operator_2 0.0003827751  -2.35966518  0.37617225
#> Y511    T-26-0137_Operator_3 0.0011542102   0.09344565  0.36607324
#> Y512    T-26-0137_Operator_4 0.0003831907  -2.46522405  0.37929035
#> Y513    T-26-0138_Operator_1 0.0007254262  -0.42001328  0.38719623
#> Y514    T-26-0138_Operator_2 0.0007358352   0.12417791  0.37711553
#> Y515    T-26-0138_Operator_3 0.0011372920   0.37515573  0.20722807
#> Y516    T-26-0138_Operator_4 0.0007236079  -0.14862685  0.38397093
#> Y517    T-26-0139_Operator_1 0.0006686727  -1.88868776  0.37930458
#> Y518    T-26-0139_Operator_2 0.0006724194  -0.93545131  0.37997313
#> Y519    T-26-0139_Operator_3 0.0011513780   0.09329362  0.36997892
#> Y520    T-26-0139_Operator_4 0.0006795292  -1.41272088  0.37713975
#> Y521    T-26-0140_Operator_1 0.0008959233  -2.24903328  0.36994151
#> Y522    T-26-0140_Operator_2 0.0008976661  -2.15543642  0.36624776
#> Y523    T-26-0140_Operator_3 0.0011560264   0.00000000  0.20380986
#> Y524    T-26-0140_Operator_4 0.0008864266  -2.20257762  0.37412299
#> Y525    T-26-0141_Operator_1 0.0006825939   0.11238860  0.33924915
#> Y526    T-26-0141_Operator_2 0.0006828269   0.47500348  0.33259338
#> Y527    T-26-0141_Operator_3 0.0011710379   0.09321855  0.20138534
#> Y528    T-26-0141_Operator_4 0.0006838219   0.29314316  0.33398103
#> Y529    T-26-0142_Operator_1 0.0008566536  -2.01004036  0.38535148
#> Y530    T-26-0142_Operator_2 0.0008620690  -2.27564700  0.38793103
#> Y531    T-26-0142_Operator_3 0.0011373446   0.28179141  0.19892897
#> Y532    T-26-0142_Operator_4 0.0008630645  -2.14295086  0.38680219
#> Y533    T-26-0143_Operator_1 0.0007244629  -1.78299936  0.38082586
#> Y534    T-26-0143_Operator_2 0.0007347539   0.02481411  0.36333578
#> Y535    T-26-0143_Operator_3 0.0011451233   0.83437781  0.19686983
#> Y536    T-26-0143_Operator_4 0.0007196621  -0.88219839  0.37223263
#> Y537    T-26-0144_Operator_1 0.0005096840  -2.48653267  0.40749235
#> Y538    T-26-0144_Operator_2 0.0005127330  -0.48479178  0.37668772
#> Y539    T-26-0144_Operator_3 0.0011364701   1.22089535  0.34557657
#> Y540    T-26-0144_Operator_4 0.0005115885  -1.48966129  0.38557453
#> Y541    T-26-0145_Operator_1 0.0016220600   3.25130996  0.36212490
#> Y542    T-26-0145_Operator_2 0.0016083635   2.97945250  0.36556815
#> Y543    T-26-0145_Operator_3 0.0010908890   0.55447982  0.38456673
#> Y544    T-26-0145_Operator_4 0.0016390380   3.11515823  0.36652003
#> Y545    T-26-0146_Operator_1 0.0005998800   0.66158468  0.32633473
#> Y546    T-26-0146_Operator_2 0.0006009615   0.86755931  0.31340144
#> Y547    T-26-0146_Operator_3 0.0012240276  -0.57972370  0.33456396
#> Y548    T-26-0146_Operator_4 0.0005825703   0.76429861  0.32492714
#> Y549    T-26-0147_Operator_1 0.0005292405  -0.83806710  0.37589309
#> Y550    T-26-0147_Operator_2 0.0005279831   0.14995347  0.36122862
#> Y551    T-26-0147_Operator_3 0.0011395435   0.00000000  0.36128083
#> Y552    T-26-0147_Operator_4 0.0005330698  -0.34631388  0.36816545
#> Y553    T-26-0148_Operator_1 0.0004189066  -0.27096679  0.33152959
#> Y554    T-26-0148_Operator_2 0.0004190530   0.98085434  0.30646750
#> Y555    T-26-0148_Operator_3 0.0011754532   1.20120907  0.31044962
#> Y556    T-26-0148_Operator_4 0.0004154111   0.35411823  0.31445913
#> Y557    T-26-0149_Operator_1 0.0002390343  -0.66248459  0.34665950
#> Y558    T-26-0149_Operator_2 0.0002386255   1.52450393  0.32162744
#> Y559    T-26-0149_Operator_3 0.0011778012   0.46661125  0.31680158
#> Y560    T-26-0149_Operator_4 0.0002362596   0.42937851  0.33781703
#> Y561    T-26-0150_Operator_1 0.0003471620  -1.72916580  0.36408610
#> Y562    T-26-0150_Operator_2 0.0003485940  -0.89535537  0.35167327
#> Y563    T-26-0150_Operator_3 0.0011544771  -0.73923776  0.33682012
#> Y564    T-26-0150_Operator_4 0.0003495700  -1.31362189  0.36159508
#> Y565    T-26-0151_Operator_1 0.0006462036  -0.89745611  0.35428110
#> Y566    T-26-0151_Operator_2 0.0006487188  -0.74962163  0.35566007
#> Y567    T-26-0151_Operator_3 0.0011819666  -0.18975380  0.33805747
#> Y568    T-26-0151_Operator_4 0.0006428739  -0.82449469  0.35407662
#> Y569    T-26-0152_Operator_1 0.0017381238  -4.17332155  0.40556252
#> Y570    T-26-0152_Operator_2 0.0017543860  -4.43853142  0.40614035
#> Y571    T-26-0152_Operator_3 0.0011388529   0.09359843  0.34815822
#> Y572    T-26-0152_Operator_4 0.0017855549  -4.30553361  0.39614856
#> Y573    T-26-0153_Operator_1 0.0007459903  -2.31988241  0.37206266
#> Y574    T-26-0153_Operator_2 0.0007457122  -2.92607134  0.36912752
#> Y575    T-26-0153_Operator_3 0.0011517380   0.46577665  0.32529344
#> Y576    T-26-0153_Operator_4 0.0007452053  -2.61938751  0.38109578
#> Y577    T-26-0154_Operator_1 0.0008839130   4.00682758  0.32130195
#> Y578    T-26-0154_Operator_2 0.0008748906   4.45648020  0.31466929
#> Y579    T-26-0154_Operator_3 0.0011439394  -0.18912770  0.37372848
#> Y580    T-26-0154_Operator_4 0.0008793667   4.23020739  0.30915104
#> Y581    T-26-0155_Operator_1 0.0012070006   0.52195132  0.34369342
#> Y582    T-26-0155_Operator_2 0.0012080942   0.65702865  0.33841740
#> Y583    T-26-0155_Operator_3 0.0011535708  -0.09329349  0.35067197
#> Y584    T-26-0155_Operator_4 0.0011965573   0.58940529  0.34875397
#> Y585    T-26-0156_Operator_1 0.0002890591  -1.27944114  0.36775546
#> Y586    T-26-0156_Operator_2 0.0002911208   0.98170617  0.33770015
#> Y587    T-26-0156_Operator_3 0.0011573579   1.58848032  0.33364628
#> Y588    T-26-0156_Operator_4 0.0002906278  -0.15101908  0.35539174
#> Y589    T-26-0157_Operator_1 0.0006319115   4.35401038  0.30000000
#> Y590    T-26-0157_Operator_2 0.0006257822   4.03004087  0.29505632
#> Y591    T-26-0157_Operator_3 0.0011636743   0.47113897  0.36237092
#> Y592    T-26-0157_Operator_4 0.0006265181   4.19305676  0.30693217
#> Y593    T-26-0158_Operator_1 0.0007039775   0.02311246  0.34899683
#> Y594    T-26-0158_Operator_2 0.0007072136   1.00100278  0.33274399
#> Y595    T-26-0158_Operator_3 0.0011564630   0.09314183  0.34062835
#> Y596    T-26-0158_Operator_4 0.0006940993   0.51032859  0.34707048
#> Y597    T-26-0159_Operator_1 0.0006512537  -2.09551578  0.38896125
#> Y598    T-26-0159_Operator_2 0.0006591958  -1.90988365  0.38233355
#> Y599    T-26-0159_Operator_3 0.0011660545   0.18788756  0.35217728
#> Y600    T-26-0159_Operator_4 0.0006535730  -2.00344609  0.38238562
#> Y601    T-26-0160_Operator_1 0.0006927607  -3.77500817  0.39851056
#> Y602    T-26-0160_Operator_2 0.0006942034  -3.75922303  0.39656369
#> Y603    T-26-0160_Operator_3 0.0011731182  -0.09421418  0.33846113
#> Y604    T-26-0160_Operator_4 0.0006889980  -3.76719985  0.39471008
#> Y605    T-26-0161_Operator_1 0.0007412898   1.35629756  0.34395849
#> Y606    T-26-0161_Operator_2 0.0007429421   3.02416595  0.31500743
#> Y607    T-26-0161_Operator_3 0.0011426420   1.97493401  0.34154820
#> Y608    T-26-0161_Operator_4 0.0007368040   2.18480773  0.32913588
#> Y609    T-26-0162_Operator_1 0.0007578628  -0.88764579  0.34880637
#> Y610    T-26-0162_Operator_2 0.0007573847  -0.86530868  0.33829837
#> Y611    T-26-0162_Operator_3 0.0011349673   1.02468195  0.31899647
#> Y612    T-26-0162_Operator_4 0.0007441257  -0.87653211  0.36758432
#> Y613    T-26-0163_Operator_1 0.0006209252  -1.23852124  0.39909966
#> Y614    T-26-0163_Operator_2 0.0006222775  -1.50464859  0.39607965
#> Y615    T-26-0163_Operator_3 0.0011312212   0.09253996  0.30082363
#> Y616    T-26-0163_Operator_4 0.0006266532  -1.37095541  0.39461260
#> Y617    T-26-0164_Operator_1 0.0012079731  -5.93447669  0.42933357
#> Y618    T-26-0164_Operator_2 0.0012148203  -6.47277441  0.42083380
#> Y619    T-26-0164_Operator_3 0.0011509963  -0.28412006  0.34025044
#> Y620    T-26-0164_Operator_4 0.0012026834  -6.20330982  0.41560530
#> Y621    T-26-0165_Operator_1 0.0007644284  -7.42325364  0.38113138
#> Y622    T-26-0165_Operator_2 0.0007642339  -7.39321978  0.37020787
#> Y623    T-26-0165_Operator_3 0.0012169803   0.14074236  0.32843222
#> Y624    T-26-0165_Operator_4 0.0007622294  -7.40827377  0.37162685
#> Y625    T-26-0166_Operator_1 0.0013568521  -7.61255670  0.40366350
#> Y626    T-26-0166_Operator_2 0.0013596193  -7.38604315  0.39734874
#> Y627    T-26-0166_Operator_3 0.0011085308   0.09239074  0.31249249
#> Y628    T-26-0166_Operator_4 0.0013587492  -7.50003922  0.39527441
#> Y629    T-26-0167_Operator_1 0.0002093145  -1.38179015  0.36237572
#> Y630    T-26-0167_Operator_2 0.0002105706  -0.25375610  0.34716088
#> Y631    T-26-0167_Operator_3 0.0011524692   0.55982123  0.27267085
#> Y632    T-26-0167_Operator_4 0.0002107824  -0.82182369  0.35069204
#> Y633    T-26-0168_Operator_1 0.0007089685  -2.54735093  0.36494151
#> Y634    T-26-0168_Operator_2 0.0007130125  -2.52441551  0.35846702
#> Y635    T-26-0168_Operator_3 0.0012062875   0.57431823  0.16383420
#> Y636    T-26-0168_Operator_4 0.0007076755  -2.53592089  0.36290485
#> Y637    T-26-0169_Operator_1 0.0005743825   1.91224439  0.31476163
#> Y638    T-26-0169_Operator_2 0.0005711022   1.92178954  0.31896059
#> Y639    T-26-0169_Operator_3 0.0012004569   0.65318129  0.33032348
#> Y640    T-26-0169_Operator_4 0.0005702561   1.91701629  0.30066697
#> Y641    T-26-0170_Operator_1 0.0006029545  -1.03476501  0.36905819
#> Y642    T-26-0170_Operator_2 0.0006069188  -0.53068330  0.36040869
#> Y643    T-26-0170_Operator_3 0.0011572151   0.28357347  0.33146400
#> Y644    T-26-0170_Operator_4 0.0005961316  -0.78354592  0.35783991
#> Y645    T-26-0171_Operator_1 0.0005859947  -2.42387382  0.36961617
#> Y646    T-26-0171_Operator_2 0.0005897965  -2.80374761  0.36228251
#> Y647    T-26-0171_Operator_3 0.0011465018   0.18781021  0.35479571
#> Y648    T-26-0171_Operator_4 0.0005863830  -2.61234296  0.37396811
#> Y649    T-26-0172_Operator_1 0.0006121824  -2.07003065  0.39562290
#> Y650    T-26-0172_Operator_2 0.0006220840  -2.11261772  0.38335925
#> Y651    T-26-0172_Operator_3 0.0011910837  -0.18999042  0.34108668
#> Y652    T-26-0172_Operator_4 0.0006093767  -2.09102809  0.38724581
#> Y653    T-26-0173_Operator_1 0.0008537282   1.38751575  0.34305659
#> Y654    T-26-0173_Operator_2 0.0008556765   1.19167337  0.34127201
#> Y655    T-26-0173_Operator_3 0.0011485185   0.84809930  0.35646330
#> Y656    T-26-0173_Operator_4 0.0008551218   1.29087322  0.35341074
#> Y657    T-26-0174_Operator_1 0.0007312614  -1.67566562  0.34972578
#> Y658    T-26-0174_Operator_2 0.0007363770  -1.09067806  0.34499264
#> Y659    T-26-0174_Operator_3 0.0011827473   0.18635989  0.32355922
#> Y660    T-26-0174_Operator_4 0.0007311882  -1.38708998  0.34473438
#> Y661    T-26-0175_Operator_1 0.0006648936   0.51535682  0.36602394
#> Y662    T-26-0175_Operator_2 0.0006634965   0.98578448  0.35989144
#> Y663    T-26-0175_Operator_3 0.0011435567   0.00000000  0.36044491
#> Y664    T-26-0175_Operator_4 0.0006746805   0.74788522  0.35275030
#> Y665    T-26-0176_Operator_1 0.0006811989  -0.75294778  0.37363760
#> Y666    T-26-0176_Operator_2 0.0006829048  -0.31091842  0.36205324
#> Y667    T-26-0176_Operator_3 0.0011587296   0.00000000  0.34921966
#> Y668    T-26-0176_Operator_4 0.0006999654  -0.53164172  0.36961394
#> Y669    T-26-0177_Operator_1 0.0006163328  -7.46658573  0.35362096
#> Y670    T-26-0177_Operator_2 0.0006192591  -6.39876715  0.34384330
#> Y671    T-26-0177_Operator_3 0.0011475428   0.37569374  0.33630363
#> Y672    T-26-0177_Operator_4 0.0006098163  -6.93271018  0.35093649
#> Y673    T-26-0178_Operator_1 0.0006170935  -4.25216118  0.37133601
#> Y674    T-26-0178_Operator_2 0.0006207325  -4.87549695  0.36788765
#> Y675    T-26-0178_Operator_3 0.0011656463  -0.28225400  0.34628440
#> Y676    T-26-0178_Operator_4 0.0006125049  -4.56082864  0.37063162
#> Y677  T-26-0179-3_Operator_1 0.0006156373   2.48776291  0.32054172
#> Y678  T-26-0179-3_Operator_2 0.0006176652   3.90470656  0.29812662
#> Y679    T-26-0179_Operator_1 0.0011474469  -5.01134735  0.40380608
#> Y680    T-26-0179_Operator_2 0.0011603176  -5.77865148  0.39615157
#> Y681    T-26-0179_Operator_3 0.0016421391  -6.10271322  0.38986941
#> Y682    T-26-0179_Operator_4 0.0007879929   0.21053148  0.33153027
#> Y683    T-26-0180_Operator_1 0.0006119951   3.22594839  0.31548348
#> Y684    T-26-0180_Operator_2 0.0006147540   3.34734799  0.30051234
#> Y685    T-26-0180_Operator_3 0.0011722544   0.95010322  0.34868692
#> Y686    T-26-0180_Operator_4 0.0006152544   3.28655753  0.30175950
#> Y687    T-26-0181_Operator_1 0.0007104796  -1.48368902  0.36678508
#> Y688    T-26-0181_Operator_2 0.0007132668  -1.64284637  0.36661912
#> Y689    T-26-0181_Operator_3 0.0011420776   0.83565427  0.33398710
#> Y690    T-26-0181_Operator_4 0.0007087921  -1.56324033  0.37021308
#> Y691    T-26-0182_Operator_1 0.0007202878   0.95952763  0.35990403
#> Y692    T-26-0182_Operator_2 0.0007183908   1.04693766  0.36099138
#> Y693    T-26-0182_Operator_3 0.0011590735   0.84524237  0.35611199
#> Y694    T-26-0182_Operator_4 0.0007222621   1.00308884  0.35180771
#> Y695    T-26-0183_Operator_1 0.0005968368   0.14038140  0.36481647
#> Y696    T-26-0183_Operator_2 0.0006022282  -0.50524069  0.36841313
#> Y697    T-26-0183_Operator_3 0.0011479176   0.46426664  0.36076996
#> Y698    T-26-0183_Operator_4 0.0005993529  -0.18118774  0.36666435
#> Y699    T-26-0184_Operator_1 0.0005511160  -8.01370145  0.39005236
#> Y700    T-26-0184_Operator_2 0.0005551956  -6.67440443  0.38109542
#> Y701    T-26-0184_Operator_3 0.0011413667   0.27769419  0.37809664
#> Y702    T-26-0184_Operator_4 0.0005562348  -7.34499063  0.38584727
#> Y703    T-26-0185_Operator_1 0.0007846214  -2.58714130  0.39263790
#> Y704    T-26-0185_Operator_2 0.0007861635  -3.36330037  0.39465409
#> Y705    T-26-0185_Operator_3 0.0011479014  -0.18337812  0.34555694
#> Y706    T-26-0185_Operator_4 0.0007773408  -2.97067031  0.39343046
#> Y707    T-26-0186_Operator_1 0.0005844535   1.38670509  0.33430742
#> Y708    T-26-0186_Operator_2 0.0005849664   2.48782444  0.31983036
#> Y709    T-26-0186_Operator_3 0.0011423124   0.27950024  0.34732048
#> Y710    T-26-0186_Operator_4 0.0005875202   1.93212338  0.32406941
#> Y711    T-26-0187_Operator_1 0.0005662514   4.32412019  0.30322763
#> Y712    T-26-0187_Operator_2 0.0005622716   4.95566904  0.30095586
#> Y713    T-26-0187_Operator_3 0.0011658590   0.00000000  0.36802997
#> Y714    T-26-0187_Operator_4 0.0005663168   4.63648191  0.29375647
#> Y715    T-26-0188_Operator_1 0.0008007476   1.77108183  0.38829571
#> Y716    T-26-0188_Operator_2 0.0007998931   1.87268977  0.37581659
#> Y717    T-26-0188_Operator_3 0.0011499700   0.28087037  0.40486292
#> Y718    T-26-0188_Operator_4 0.0007981222   1.82176085  0.37051026
#> Y719    T-26-0189_Operator_1 0.0007335858  -1.74463450  0.36734347
#> Y720    T-26-0189_Operator_2 0.0007342144  -1.86686773  0.37114537
#> Y721    T-26-0189_Operator_3 0.0011415607   0.67046909  0.35240426
#> Y722    T-26-0189_Operator_4 0.0007371918  -1.80537379  0.37031469
#> Y723    T-26-0190_Operator_1 0.0006799640 -89.70847800  0.49807366
#> Y724    T-26-0190_Operator_2 0.0006821282   0.42606644  0.33253752
#> Y725    T-26-0190_Operator_4 0.0012810527 -45.35837393  0.47379863
#> Y726    T-26-0191_Operator_1 0.0006657790   2.87382242  0.32434554
#> Y727    T-26-0191_Operator_2 0.0006664445   3.30920808  0.31706098
#> Y728    T-26-0191_Operator_4 0.0006676668   3.08981158  0.32160543
#> Y729    T-26-0192_Operator_1 0.0006279435  -3.76558311  0.40214568
#> Y730    T-26-0192_Operator_2 0.0006297229  -3.44840395  0.39662028
#> Y731    T-26-0192_Operator_4 0.0006294177  -3.60892872  0.40120722
#> Y732    T-26-0193_Operator_1 0.0006700917  -2.24618713  0.34978755
#> Y733    T-26-0193_Operator_2 0.0006751433  -3.87590479  0.34527943
#> Y734    T-26-0193_Operator_4 0.0006720968  -3.05760692  0.35086509
#> Y735    T-26-0194_Operator_1 0.0005078720   2.51331047  0.30726257
#> Y736    T-26-0194_Operator_2 0.0005024285   2.76973810  0.29927982
#> Y737    T-26-0194_Operator_4 0.0005072301   2.64061712  0.29526369
#> Y738    T-26-0195_Operator_1 0.0006170935  -5.03830550  0.39437396
#> Y739    T-26-0195_Operator_2 0.0006195787  -4.60369517  0.38114436
#> Y740    T-26-0195_Operator_4 0.0006120985  -4.82287560  0.38579772
#> Y741    T-26-0196_Operator_1 0.0008203445   1.41705249  0.36286546
#> Y742    T-26-0196_Operator_2 0.0008172158   2.58323382  0.35290116
#> Y743    T-26-0196_Operator_4 0.0008253869   1.99400213  0.36303447
#> Y744    T-26-0197_Operator_1 0.0006430868   0.87483963  0.34469453
#> Y745    T-26-0197_Operator_2 0.0006462733   1.48028903  0.33810854
#> Y746    T-26-0197_Operator_3 0.0011580387   1.69715835  0.31649219
#> Y747    T-26-0197_Operator_4 0.0006421280   1.17524661  0.32320034
#> Y748    T-26-0198_Operator_1 0.0006839945   0.34009759  0.33960328
#> Y749    T-26-0198_Operator_2 0.0006876789  -0.19169058  0.34080233
#> Y750    T-26-0198_Operator_3 0.0011557674   0.97812522  0.33369301
#> Y751    T-26-0198_Operator_4 0.0006895762   0.07612534  0.35679915
#> Y752    T-26-0199_Operator_1 0.0008892841  -1.36324688  0.41210938
#> Y753    T-26-0199_Operator_2 0.0008867874  -1.99951040  0.42225801
#> Y754    T-26-0199_Operator_3 0.0011381205  -0.64374571  0.39717883
#> Y755    T-26-0199_Operator_4 0.0008861077  -1.67993274  0.41986662
#> Y756    T-26-0200_Operator_1 0.0006265664   1.13708197  0.29104010
#> Y757    T-26-0200_Operator_2 0.0006274837   0.72997589  0.28257691
#> Y758    T-26-0200_Operator_3 0.0011660209   1.37701612  0.29255734
#> Y759    T-26-0200_Operator_4 0.0006240943   0.93442628  0.28092294
#> Y760    T-26-0201_Operator_1 0.0007560482   1.93633955  0.31439017
#> Y761    T-26-0201_Operator_2 0.0007583421   2.36693289  0.31357448
#> Y762    T-26-0201_Operator_3 0.0011611204   0.13810514  0.34633530
#> Y763    T-26-0201_Operator_4 0.0007464497   2.15083153  0.31199843
#> Y764    T-26-0202_Operator_1 0.0005440696   3.74916360  0.28645267
#> Y765    T-26-0202_Operator_2 0.0005425936   5.28953039  0.26207271
#> Y766    T-26-0202_Operator_3 0.0011985816   0.94074392  0.33699240
#> Y767    T-26-0202_Operator_4 0.0005369655   4.51747967  0.27730322
#> Y768    T-26-0203_Operator_1 0.0006548788  -0.12292215  0.35036018
#> Y769    T-26-0203_Operator_2 0.0006520320  -0.02196643  0.34970662
#> Y770    T-26-0203_Operator_3 0.0011303699   0.41515752  0.34352449
#> Y771    T-26-0203_Operator_4 0.0006511129  -0.07277060  0.35083785
#> Y772    T-26-0204_Operator_1 0.0006311139   0.39948703  0.32486589
#> Y773    T-26-0204_Operator_2 0.0006315125   0.57959284  0.31875592
#> Y774    T-26-0204_Operator_3 0.0011529514   0.00000000  0.33271810
#> Y775    T-26-0204_Operator_4 0.0006357849   0.48859208  0.31571838
#> Y776    T-26-0205_Operator_1 0.0006915629   1.60080197  0.34336100
#> Y777    T-26-0205_Operator_2 0.0006901311   2.35585018  0.34334023
#> Y778    T-26-0205_Operator_3 0.0011374883  -0.27747011  0.36084650
#> Y779    T-26-0205_Operator_4 0.0006963449   1.97733860  0.33415363
#> Y780    T-26-0206_Operator_1 0.0007629703   0.89932196  0.34142959
#> Y781    T-26-0206_Operator_2 0.0007606489   0.96718317  0.34254568
#> Y782    T-26-0206_Operator_3 0.0011322414   0.09216947  0.34929268
#> Y783    T-26-0206_Operator_4 0.0007673060   0.93296193  0.33105763
#> Y784    T-26-0207_Operator_1 0.0009032061   0.15165602  0.35443298
#> Y785    T-26-0207_Operator_2 0.0009049774   0.70354335  0.35022624
#> Y786    T-26-0207_Operator_3 0.0011343382  -0.83633176  0.36156988
#> Y787    T-26-0207_Operator_4 0.0009096301   0.42643599  0.35682241
#> Y788    T-26-0208_Operator_1 0.0007764982  -0.25385067  0.39944348
#> Y789    T-26-0208_Operator_2 0.0007867821   0.02653811  0.39299764
#> Y790    T-26-0208_Operator_3 0.0011738922  -0.83437893  0.15646867
#> Y791    T-26-0208_Operator_4 0.0007937654  -0.11436258  0.39745900
#> Y792    T-26-0209_Operator_1 0.0005845673 -88.94721314  0.49970772
#> Y793    T-26-0209_Operator_2 0.0005845673   1.89548377  0.36174983
#> Y794    T-26-0209_Operator_4 0.0009172620 -46.36054679  0.30975343
#> Y795    T-26-0210_Operator_1 0.0010695187  -0.90995810  0.39090909
#> Y796    T-26-0210_Operator_2 0.0010799136   0.35845552  0.37886933
#> Y797    T-26-0210_Operator_4 0.0010585920  -0.28163710  0.36844030
#> Y798    T-26-0211_Operator_1 0.0007518797  -0.25612605  0.36140376
#> Y799    T-26-0211_Operator_2 0.0007564297   0.12910248  0.35690847
#> Y800    T-26-0211_Operator_4 0.0007583651  -0.06430771  0.35690484
#> Y801    T-26-0212_Operator_1 0.0008605852   6.87010893  0.26835886
#> Y802    T-26-0212_Operator_2 0.0008593524   7.29396634  0.27227162
#> Y803    T-26-0212_Operator_4 0.0008606089   7.08091372  0.26553743
#> Y804    T-26-0213_Operator_1 0.0007682456   4.05811438  0.31241977
#> Y805    T-26-0213_Operator_2 0.0007664791   3.79690602  0.31489530
#> Y806    T-26-0213_Operator_4 0.0007662101   3.92772256  0.29365042
#> Y807    T-26-0214_Operator_1 0.0004654048   3.71997644  0.27435638
#> Y808    T-26-0214_Operator_2 0.0004622497   3.67006189  0.27696453
#> Y809    T-26-0214_Operator_4 0.0004594024   3.69517741  0.27834294
#> Y810    T-26-0215_Operator_1 0.0007543373   2.16217280  0.31430706
#> Y811    T-26-0215_Operator_2 0.0007511269   1.80499534  0.32010511
#> Y812    T-26-0215_Operator_4 0.0007594871   1.98426055  0.30960265
#> Y813    T-26-0216_Operator_1 0.0008045052   0.59707985  0.33266291
#> Y814    T-26-0216_Operator_2 0.0008084074   0.48459300  0.32821342
#> Y815    T-26-0216_Operator_3 0.0011735400   0.13944928  0.33254655
#> Y816    T-26-0216_Operator_4 0.0007988107   0.54132797  0.33573176
#> Y817    T-26-0217_Operator_1 0.0006011422  -3.30696326  0.38187556
#> Y818    T-26-0217_Operator_2 0.0006005404  -4.67390439  0.39460517
#> Y819    T-26-0217_Operator_3 0.0011915397  -0.70218495  0.32390811
#> Y820    T-26-0217_Operator_4 0.0006031214  -3.98757001  0.39618170
#> Y821    T-26-0218_Operator_1 0.0008007476   2.47055528  0.32930704
#> Y822    T-26-0218_Operator_2 0.0007967067   2.63453067  0.32751299
#> Y823    T-26-0218_Operator_3 0.0011785917   0.27680006  0.35786093
#> Y824    T-26-0218_Operator_4 0.0007899462   2.55200972  0.32483022
#> Y825    T-26-0219_Operator_1 0.0011829644  -2.28615255  0.36553599
#> Y826    T-26-0219_Operator_2 0.0011890606  -1.61812266  0.36187039
#> Y827    T-26-0219_Operator_3 0.0011009757  -1.09640405  0.35328289
#> Y828    T-26-0219_Operator_4 0.0012012099  -1.95567611  0.36388490
#> Y829    T-26-0220_Operator_1 0.0008322930   2.74589483  0.32188931
#> Y830    T-26-0220_Operator_2 0.0008368201   3.65577450  0.32008368
#> Y831    T-26-0220_Operator_3 0.0011739554  -0.75258850  0.20862428
#> Y832    T-26-0220_Operator_4 0.0008238590   3.19722272  0.32229362
#> Y833    T-26-0221_Operator_1 0.0007135212  -6.44714719  0.38571745
#> Y834    T-26-0221_Operator_2 0.0007135212  -5.73727054  0.38619336
#> Y835    T-26-0221_Operator_3 0.0011416653   1.13438849  0.36524667
#> Y836    T-26-0221_Operator_4 0.0007042472  -6.09333468  0.38573378
#> Y837    T-26-0222_Operator_1 0.0002917153   4.45824115  0.26794049
#> Y838    T-26-0222_Operator_2 0.0002914319   4.62809115  0.26447433
#> Y839    T-26-0222_Operator_4 0.0002935093   4.54284466  0.25091362
#> Y840    T-26-0223_Operator_1 0.0006015038  -2.11265794  0.35714286
#> Y841    T-26-0223_Operator_2 0.0006033183  -0.58442490  0.35731523
#> Y842    T-26-0223_Operator_4 0.0006050269  -1.34922867  0.35638597
#> Y843    T-26-0224_Operator_1 0.0006113714  -0.01996136  0.33768090
#> Y844    T-26-0224_Operator_2 0.0006148171   0.06071610  0.34537350
#> Y845    T-26-0224_Operator_4 0.0006161194   0.02009908  0.34509772
#> Y846    T-26-0225_Operator_1 0.0005310674  -1.35815232  0.36165693
#> Y847    T-26-0225_Operator_2 0.0005329070  -1.51824176  0.37112550
#> Y848    T-26-0225_Operator_4 0.0005296091  -1.43802382  0.37070917
#> Y849    T-26-0226_Operator_1 0.0010443864  -1.57174591  0.40130548
#> Y850    T-26-0226_Operator_2 0.0010438413  -1.50835844  0.40274843
#> Y851    T-26-0226_Operator_4 0.0010344193  -1.54016702  0.39701011
#> Y852    T-26-0227_Operator_1 0.0007249876  -0.52193511  0.37179827
#> Y853    T-26-0227_Operator_2 0.0007221953   0.98343383  0.35784813
#> Y854    T-26-0227_Operator_4 0.0007178256   0.22622505  0.37049134
#> Y855    T-26-0228_Operator_1 0.0006495615  -2.70505175  0.38665151
#> Y856    T-26-0228_Operator_2 0.0006529546  -2.88285720  0.38540646
#> Y857    T-26-0228_Operator_3 0.0011380142   1.34453246  0.35545645
#> Y858    T-26-0228_Operator_4 0.0006490653  -2.79395803  0.38373488
#> Y859    T-26-0229_Operator_1 0.0005492996  -3.23621854  0.36459764
#> Y860    T-26-0229_Operator_2 0.0005522320  -3.07146212  0.36829266
#> Y861    T-26-0229_Operator_4 0.0005507175  -3.15410088  0.36061891
#> Y862  T-26-0230-1_Operator_1 0.0008045052   2.18339344  0.37811746
#> Y863  T-26-0230-1_Operator_2 0.0043352539  45.00000000 -0.14812045
#> Y864  T-26-0230-2_Operator_1 0.0008940545  -3.77929157  0.44903889
#> Y865  T-26-0230-2_Operator_2 0.0008924587  -4.29570383  0.44779116
#> Y866  T-26-0230-3_Operator_1 0.0008631852  -4.53379115  0.43353474
#> Y867  T-26-0230-3_Operator_2 0.0008646779  -5.19442891  0.43356420
#> Y868  T-26-0230-4_Operator_1 0.0008368201  -3.75128791  0.41799163
#> Y869  T-26-0230-4_Operator_2 0.0008460237  -3.28901319  0.41835871
#> Y870    T-26-0231_Operator_1 0.0008133388  -0.34287372  0.40822855
#> Y871    T-26-0231_Operator_2 0.0008182188  -0.45113855  0.40904107
#> Y872    T-26-0231_Operator_4 0.0008008637  -0.39683994  0.40740815
#> Y873    T-26-0232_Operator_1 0.0008992806  -2.32683345  0.40917266
#> Y874    T-26-0232_Operator_2 0.0009090909  -2.10753366  0.39954545
#> Y875    T-26-0232_Operator_4 0.0009160630  -2.21777338  0.39971309
#> Y876    T-26-0233_Operator_1 0.0009886307  -1.27348362  0.40822244
#> Y877    T-26-0233_Operator_2 0.0009899353  -1.15632927  0.40216172
#> Y878    T-26-0233_Operator_4 0.0009508017  -1.21519432  0.40210165
#> Y879    T-26-0234_Operator_1 0.0002971916  -0.41747189  0.37493198
#> Y880    T-26-0234_Operator_2 0.0002987750  -0.05026826  0.37585898
#> Y881    T-26-0234_Operator_4 0.0002953829  -0.23419347  0.35232301
#> Y882    T-26-0235_Operator_1 0.0008233841   2.21899462  0.35220255
#> Y883    T-26-0235_Operator_2 0.0008156607   2.52599512  0.35848287
#> Y884    T-26-0235_Operator_4 0.0008178273   2.37210718  0.35328014
#> Y885    T-26-0236_Operator_1 0.0003565910   0.20510088  0.34161403
#> Y886    T-26-0236_Operator_2 0.0003568879   0.71148753  0.33815132
#> Y887    T-26-0236_Operator_3 0.0011419761   1.02127855  0.27258345
#> Y888    T-26-0236_Operator_4 0.0003545424   0.45834856  0.32152406
#> Y889    T-26-0237_Operator_1 0.0003573343   0.71889809  0.33759157
#> Y890    T-26-0237_Operator_2 0.0003571429   1.37732499  0.33303571
#> Y891    T-26-0237_Operator_3 0.0011504936   0.28156030  0.22775065
#> Y892    T-26-0237_Operator_4 0.0003553702   1.04727772  0.31243526
#> Y893    T-26-0238_Operator_1 0.0004730369   0.14480790  0.35028382
#> Y894    T-26-0238_Operator_2 0.0004732608   0.69221654  0.34074775
#> Y895    T-26-0238_Operator_3 0.0011423043   1.39376131  0.32550959
#> Y896    T-26-0238_Operator_4 0.0004752213   0.41844488  0.33255437
#> Y897    T-26-0239_Operator_1 0.0005236973  -4.06310496  0.41018591
#> Y898    T-26-0239_Operator_2 0.0005256242  -4.03329654  0.40617608
#> Y899    T-26-0239_Operator_3 0.0011506953   0.14108912  0.39729161
#> Y900    T-26-0239_Operator_4 0.0005314965  -4.04848928  0.40058730
#> Y901    T-26-0240_Operator_1 0.0007814533   0.71715589  0.37106021
#> Y902    T-26-0240_Operator_2 0.0007796256   1.36839773  0.36993273
#> Y903    T-26-0240_Operator_3 0.0011692723  -0.03914309  0.35229318
#> Y904    T-26-0240_Operator_4 0.0007924232   1.04114140  0.36056363
#> Y905    T-26-0241_Operator_1 0.0011428571  -0.86329573  0.39257143
#> Y906    T-26-0241_Operator_2 0.0011456945  -1.38751575  0.39516895
#> Y907    T-26-0241_Operator_3 0.0011235565   0.42126280  0.36448663
#> Y908    T-26-0241_Operator_4 0.0011397011  -1.12407587  0.39214096
#> Y909    T-26-0242_Operator_1 0.0003497115  -4.30614712  0.35457842
#> Y910    T-26-0242_Operator_2 0.0003519680  -3.78274255  0.35234940
#> Y911    T-26-0242_Operator_3 0.0011612323   1.10885581  0.30149314
#> Y912    T-26-0242_Operator_4 0.0003454276  -4.04550801  0.35771148
#> Y913    T-26-0243_Operator_1 0.0011527378  -1.18552449  0.37204611
#> Y914    T-26-0243_Operator_2 0.0011565146  -1.19108873  0.37451817
#> Y915    T-26-0243_Operator_3 0.0011681272  -0.13646106  0.33617066
#> Y916    T-26-0243_Operator_4 0.0011145365  -1.18830010  0.39985667
#> Y917    T-26-0244_Operator_1 0.0014727541  -1.93805517  0.40034315
#> Y918    T-26-0244_Operator_2 0.0014771049  -1.89268289  0.39931019
#> Y919    T-26-0244_Operator_3 0.0011411805  -0.27950024  0.39240293
#> Y920    T-26-0244_Operator_4 0.0014840538  -1.91563015  0.39379517
#> Y921    T-26-0245_Operator_1 0.0007923930   1.65831351  0.33874802
#> Y922    T-26-0245_Operator_2 0.0007903052   1.79644303  0.33179698
#> Y923    T-26-0245_Operator_3 0.0010992688   2.41294947  0.33715165
#> Y924    T-26-0245_Operator_4 0.0007958793   1.72718798  0.33575281
#> Y925    T-26-0246_Operator_1 0.0008061266  -2.64338261  0.39036679
#> Y926    T-26-0246_Operator_2 0.0008159935  -3.38053432  0.38208894
#> Y927    T-26-0246_Operator_3 0.0011309705   1.39038052  0.32833470
#> Y928    T-26-0246_Operator_4 0.0007897360  -3.00945313  0.39659039
#> Y929    T-26-0247_Operator_1 0.0011587486  -1.57534089  0.38682851
#> Y930    T-26-0247_Operator_2 0.0011461318  -2.07191300  0.41919771
#> Y931    T-26-0247_Operator_3 0.0011532331   0.09468138  0.35856472
#> Y932    T-26-0247_Operator_4 0.0011309697  -1.82252943  0.41462197
#> Y933    T-26-0248_Operator_1 0.0015822785  -2.92366660  0.39768038
#> Y934    T-26-0248_Operator_2 0.0015923567  -2.87417348  0.39543471
#> Y935    T-26-0248_Operator_3 0.0011189972   0.69875987  0.37974733
#> Y936    T-26-0248_Operator_4 0.0015759696  -2.89896420  0.40379021
#> Y937    T-26-0249_Operator_1 0.0015128593   3.20125096  0.37897126
#> Y938    T-26-0249_Operator_2 0.0015090536   3.12597419  0.38707299
#> Y939    T-26-0249_Operator_3 0.0010757792   0.41515807  0.38243289
#> Y940    T-26-0249_Operator_4 0.0015489179   3.16375757  0.32944555
#> Y941    T-26-0250_Operator_1 0.0015885624  -8.91933398  0.38430024
#> Y942    T-26-0250_Operator_2 0.0015961692  -9.30851801  0.37895770
#> Y943    T-26-0250_Operator_3 0.0011366869  -0.83228214  0.33436836
#> Y944    T-26-0250_Operator_4 0.0015606053  -9.11400020  0.40221871
#> Y945    T-26-0251_Operator_1 0.0010362694  -6.64864518  0.42279793
#> Y946    T-26-0251_Operator_2 0.0010346611  -6.54746652  0.41567512
#> Y947    T-26-0251_Operator_3 0.0011426843   0.84871941  0.38136525
#> Y948    T-26-0251_Operator_4 0.0010267141  -6.59885012  0.38707788
#> Y949    T-26-0252_Operator_1 0.0015015015 -10.78192163  0.41666667
#> Y950    T-26-0252_Operator_2 0.0014973803 -10.44674673  0.41390063
#> Y951    T-26-0252_Operator_3 0.0011348607   0.28010691  0.34497046
#> Y952    T-26-0252_Operator_4 0.0014954971 -10.61495710  0.36159623
#> Y953  T-26-0261-1_Operator_1 0.0008238366  -8.40939712  0.41473292
#> Y954  T-26-0261-1_Operator_2 0.0008288438  -7.73843809  0.40343970
#> Y955  T-26-0261-2_Operator_1 0.0009316764  -0.60825814  0.36972089
#> Y956  T-26-0261-2_Operator_2 0.0009447331  -0.54749781  0.37293340
#> Y957  T-26-0261-3_Operator_1 0.0009367681   1.68177635  0.34496487
#> Y958  T-26-0261-3_Operator_2 0.0009442871   0.86492177  0.35757035
#> Y959  T-26-0261-4_Operator_1 0.0012586532  -4.49910674  0.36595343
#> Y960  T-26-0261-4_Operator_2 0.0012634239  -4.78915345  0.36228680
#> Y961  T-26-0261-5_Operator_1 0.0008971289  -0.56504936  0.37305626
#> Y962  T-26-0261-5_Operator_2 0.0009100564  -0.09306291  0.36576668
#> Y963  T-26-0262-1_Operator_1 0.0010666667  -6.38738112  0.38213333
#> Y964  T-26-0262-1_Operator_2 0.0010598834  -6.82957021  0.38023317
#> Y965  T-26-0262-2_Operator_1 0.0011185682  -2.42600988  0.35178971
#> Y966  T-26-0262-2_Operator_2 0.0011252809  -2.15751201  0.35315084
#> Y967    T-26-0263_Operator_1 0.0008696915  -2.56157440  0.43636728
#> Y968    T-26-0263_Operator_2 0.0008773215  -2.27204864  0.43463955
#> Y969    T-26-0263_Operator_3 0.0011073918   0.00000000  0.41931829
#> Y970    T-26-0263_Operator_4 0.0009052436  -2.41309348  0.42200240
#> Y971  T-26-0264-1_Operator_1 0.0008493766   0.78894780  0.41860169
#> Y972  T-26-0264-1_Operator_2 0.0008616975  -0.03028853  0.42546316
#> Y973  T-26-0264-2_Operator_1 0.0008865248   5.51047444  0.34205053
#> Y974  T-26-0264-2_Operator_2 0.0009160303   5.91420495  0.32824433
#> Y975  T-26-0264-3_Operator_1 0.0008484160   5.36738087  0.34997204
#> Y976  T-26-0264-3_Operator_2 0.0008615736   5.77163006  0.34534755
#> Y977  T-26-0264-4_Operator_1 0.0010021717 -13.58896463  0.44705226
#> Y978  T-26-0264-4_Operator_2 0.0009948596 -12.78617204  0.43848485
#> Y979    T-26-0265_Operator_1 0.0004808848  -0.11501862  0.37761481
#> Y980    T-26-0265_Operator_2 0.0004825090   0.18084691  0.37575392
#> Y981    T-26-0265_Operator_3 0.0011423518   0.55762753  0.36679313
#> Y982    T-26-0265_Operator_4 0.0004856899   0.03287193  0.37353461
#> Y983    T-26-0266_Operator_1 0.0004473272  -0.01487043  0.38347126
#> Y984    T-26-0266_Operator_2 0.0004463289  -0.37233541  0.38893863
#> Y985    T-26-0266_Operator_3 0.0011580027   1.24838960  0.35845950
#> Y986    T-26-0266_Operator_4 0.0004432530  -0.19346553  0.38344087
#> Y987    T-26-0267_Operator_1 0.0002286498  -0.27912141  0.35880873
#> Y988    T-26-0267_Operator_2 0.0002289377   0.78149905  0.34993132
#> Y989    T-26-0267_Operator_3 0.0011744724   2.67936369  0.30779369
#> Y990    T-26-0267_Operator_4 0.0002296491   0.24966972  0.35782560
#> Y991    T-26-0268_Operator_1 0.0005411255  -0.09445389  0.39853896
#> Y992    T-26-0268_Operator_2 0.0005451077   1.44665053  0.38525484
#> Y993    T-26-0268_Operator_3 0.0011149018   1.11968922  0.37824058
#> Y994    T-26-0268_Operator_4 0.0005442079   0.67824800  0.38847547
#> Y995    T-26-0269_Operator_1 0.0005213764   4.18318563  0.30630865
#> Y996    T-26-0269_Operator_2 0.0005319149   5.07362080  0.28750000
#> Y997    T-26-0269_Operator_3 0.0011523210   0.42133989  0.35937521
#> Y998    T-26-0269_Operator_4 0.0005132675   4.62533257  0.31230836
#> Y999  T-26-0270-1_Operator_1 0.0004681648   1.91504877  0.36961610
#> Y1000 T-26-0270-1_Operator_2 0.0004766774   3.62322265  0.33642006
#> Y1001 T-26-0270-2_Operator_1 0.0004311274  -8.79933646  0.39415822
#> Y1002 T-26-0270-2_Operator_2 0.0004376687  -9.06384708  0.38992631
#> Y1003   T-26-0271_Operator_1 0.0004005608  -4.11462635  0.38724214
#> Y1004   T-26-0271_Operator_2 0.0004016871  -3.79404517  0.38692509
#> Y1005   T-26-0271_Operator_3 0.0011764710  -0.19189993  0.38327280
#> Y1006   T-26-0271_Operator_4 0.0003912357  -3.95762065  0.39852833
#> Y1007   T-26-0272_Operator_1 0.0005778677  -3.45348404  0.42054320
#> Y1008   T-26-0272_Operator_2 0.0005813389  -3.95583310  0.40979539
#> Y1009   T-26-0272_Operator_4 0.0005900269  -3.70315929  0.42217840
#> Y1010   T-26-0273_Operator_1 0.0004362050  -2.13526395  0.39683751
#> Y1011   T-26-0273_Operator_2 0.0004401085  -1.40366522  0.38711217
#> Y1012   T-26-0273_Operator_3 0.0011569312   0.55898719  0.36091986
#> Y1013   T-26-0273_Operator_4 0.0004339097  -1.77010258  0.38532461
#> Y1014   T-26-0274_Operator_1 0.0005492996  -6.33228397  0.41128811
#> Y1015   T-26-0274_Operator_2 0.0005575690  -6.19648121  0.40902314
#> Y1016   T-26-0274_Operator_3 0.0011727595   0.27882037  0.40292193
#> Y1017   T-26-0274_Operator_4 0.0005630456  -6.26502536  0.40668532
#> Y1018   T-26-0275_Operator_1 0.0005952381   0.83879554  0.40029762
#> Y1019   T-26-0275_Operator_2 0.0006016847   1.24837872  0.39139591
#> Y1020   T-26-0275_Operator_3 0.0011652323  -0.96634301  0.41648143
#> Y1021   T-26-0275_Operator_4 0.0005912171   1.04198405  0.39794115
#> Y1022   T-26-0276_Operator_1 0.0006343165  -1.53612961  0.39755788
#> Y1023   T-26-0276_Operator_2 0.0006344505  -2.15898171  0.39626734
#> Y1024   T-26-0276_Operator_3 0.0011008482  -1.10432749  0.40038023
#> Y1025   T-26-0276_Operator_4 0.0006551019  -1.84761027  0.39672711
#> Y1026   T-26-0277_Operator_1 0.0005574136   7.81897769  0.32525084
#> Y1027   T-26-0277_Operator_2 0.0005681818   7.83692079  0.32187500
#> Y1028   T-26-0277_Operator_4 0.0005698006   7.82789515  0.31709972
#> Y1029 T-26-0278-1_Operator_1 0.0006491399  -2.54046740  0.37439143
#> Y1030 T-26-0278-1_Operator_2 0.0006538084  -3.57310534  0.37174436
#> Y1031 T-26-0278-2_Operator_1 0.0006351223  -3.52702993  0.43680534
#> Y1032 T-26-0278-2_Operator_2 0.0006412312  -3.36646066  0.43384610
#> Y1033   T-26-0279_Operator_1 0.0006375518  -2.02676844  0.39703538
#> Y1034   T-26-0279_Operator_2 0.0006441224  -2.50417339  0.39876522
#> Y1035   T-26-0279_Operator_4 0.0006321876  -2.26463565  0.39636423
#>       scale_bar_placed
#> Y                 TRUE
#> Y1                TRUE
#> Y2               FALSE
#> Y3                TRUE
#> Y4                TRUE
#> Y5                TRUE
#> Y6                TRUE
#> Y7                TRUE
#> Y8                TRUE
#> Y9                TRUE
#> Y10               TRUE
#> Y11               TRUE
#> Y12               TRUE
#> Y13               TRUE
#> Y14               TRUE
#> Y15               TRUE
#> Y16               TRUE
#> Y17               TRUE
#> Y18               TRUE
#> Y19               TRUE
#> Y20               TRUE
#> Y21               TRUE
#> Y22               TRUE
#> Y23               TRUE
#> Y24               TRUE
#> Y25               TRUE
#> Y26               TRUE
#> Y27               TRUE
#> Y28               TRUE
#> Y29               TRUE
#> Y30               TRUE
#> Y31               TRUE
#> Y32               TRUE
#> Y33               TRUE
#> Y34              FALSE
#> Y35               TRUE
#> Y36               TRUE
#> Y37               TRUE
#> Y38               TRUE
#> Y39               TRUE
#> Y40               TRUE
#> Y41               TRUE
#> Y42               TRUE
#> Y43               TRUE
#> Y44               TRUE
#> Y45               TRUE
#> Y46               TRUE
#> Y47               TRUE
#> Y48               TRUE
#> Y49               TRUE
#> Y50               TRUE
#> Y51               TRUE
#> Y52               TRUE
#> Y53               TRUE
#> Y54               TRUE
#> Y55               TRUE
#> Y56               TRUE
#> Y57               TRUE
#> Y58               TRUE
#> Y59               TRUE
#> Y60               TRUE
#> Y61               TRUE
#> Y62               TRUE
#> Y63               TRUE
#> Y64               TRUE
#> Y65               TRUE
#> Y66               TRUE
#> Y67               TRUE
#> Y68               TRUE
#> Y69               TRUE
#> Y70               TRUE
#> Y71               TRUE
#> Y72               TRUE
#> Y73               TRUE
#> Y74               TRUE
#> Y75               TRUE
#> Y76               TRUE
#> Y77               TRUE
#> Y78               TRUE
#> Y79               TRUE
#> Y80               TRUE
#> Y81               TRUE
#> Y82               TRUE
#> Y83               TRUE
#> Y84               TRUE
#> Y85               TRUE
#> Y86               TRUE
#> Y87               TRUE
#> Y88               TRUE
#> Y89               TRUE
#> Y90               TRUE
#> Y91               TRUE
#> Y92               TRUE
#> Y93               TRUE
#> Y94               TRUE
#> Y95               TRUE
#> Y96               TRUE
#> Y97               TRUE
#> Y98               TRUE
#> Y99               TRUE
#> Y100              TRUE
#> Y101              TRUE
#> Y102              TRUE
#> Y103              TRUE
#> Y104              TRUE
#> Y105              TRUE
#> Y106              TRUE
#> Y107              TRUE
#> Y108              TRUE
#> Y109              TRUE
#> Y110              TRUE
#> Y111              TRUE
#> Y112              TRUE
#> Y113              TRUE
#> Y114              TRUE
#> Y115              TRUE
#> Y116              TRUE
#> Y117              TRUE
#> Y118              TRUE
#> Y119              TRUE
#> Y120              TRUE
#> Y121              TRUE
#> Y122              TRUE
#> Y123              TRUE
#> Y124              TRUE
#> Y125              TRUE
#> Y126              TRUE
#> Y127              TRUE
#> Y128              TRUE
#> Y129              TRUE
#> Y130              TRUE
#> Y131              TRUE
#> Y132              TRUE
#> Y133              TRUE
#> Y134              TRUE
#> Y135              TRUE
#> Y136              TRUE
#> Y137              TRUE
#> Y138              TRUE
#> Y139              TRUE
#> Y140              TRUE
#> Y141              TRUE
#> Y142              TRUE
#> Y143              TRUE
#> Y144              TRUE
#> Y145              TRUE
#> Y146              TRUE
#> Y147              TRUE
#> Y148              TRUE
#> Y149              TRUE
#> Y150              TRUE
#> Y151              TRUE
#> Y152              TRUE
#> Y153              TRUE
#> Y154              TRUE
#> Y155              TRUE
#> Y156              TRUE
#> Y157              TRUE
#> Y158              TRUE
#> Y159              TRUE
#> Y160              TRUE
#> Y161              TRUE
#> Y162              TRUE
#> Y163              TRUE
#> Y164              TRUE
#> Y165              TRUE
#> Y166              TRUE
#> Y167              TRUE
#> Y168              TRUE
#> Y169              TRUE
#> Y170              TRUE
#> Y171              TRUE
#> Y172              TRUE
#> Y173              TRUE
#> Y174              TRUE
#> Y175              TRUE
#> Y176              TRUE
#> Y177              TRUE
#> Y178              TRUE
#> Y179              TRUE
#> Y180              TRUE
#> Y181              TRUE
#> Y182              TRUE
#> Y183              TRUE
#> Y184              TRUE
#> Y185              TRUE
#> Y186              TRUE
#> Y187              TRUE
#> Y188              TRUE
#> Y189              TRUE
#> Y190              TRUE
#> Y191              TRUE
#> Y192              TRUE
#> Y193              TRUE
#> Y194              TRUE
#> Y195              TRUE
#> Y196              TRUE
#> Y197              TRUE
#> Y198              TRUE
#> Y199              TRUE
#> Y200              TRUE
#> Y201              TRUE
#> Y202              TRUE
#> Y203              TRUE
#> Y204              TRUE
#> Y205              TRUE
#> Y206              TRUE
#> Y207              TRUE
#> Y208              TRUE
#> Y209              TRUE
#> Y210              TRUE
#> Y211              TRUE
#> Y212              TRUE
#> Y213              TRUE
#> Y214              TRUE
#> Y215              TRUE
#> Y216              TRUE
#> Y217              TRUE
#> Y218              TRUE
#> Y219              TRUE
#> Y220              TRUE
#> Y221              TRUE
#> Y222              TRUE
#> Y223              TRUE
#> Y224             FALSE
#> Y225              TRUE
#> Y226              TRUE
#> Y227              TRUE
#> Y228              TRUE
#> Y229              TRUE
#> Y230              TRUE
#> Y231              TRUE
#> Y232              TRUE
#> Y233              TRUE
#> Y234              TRUE
#> Y235              TRUE
#> Y236              TRUE
#> Y237              TRUE
#> Y238              TRUE
#> Y239              TRUE
#> Y240              TRUE
#> Y241              TRUE
#> Y242              TRUE
#> Y243              TRUE
#> Y244              TRUE
#> Y245              TRUE
#> Y246              TRUE
#> Y247              TRUE
#> Y248              TRUE
#> Y249              TRUE
#> Y250              TRUE
#> Y251              TRUE
#> Y252              TRUE
#> Y253              TRUE
#> Y254              TRUE
#> Y255              TRUE
#> Y256              TRUE
#> Y257              TRUE
#> Y258              TRUE
#> Y259              TRUE
#> Y260              TRUE
#> Y261              TRUE
#> Y262              TRUE
#> Y263              TRUE
#> Y264              TRUE
#> Y265              TRUE
#> Y266              TRUE
#> Y267              TRUE
#> Y268              TRUE
#> Y269              TRUE
#> Y270              TRUE
#> Y271              TRUE
#> Y272              TRUE
#> Y273              TRUE
#> Y274              TRUE
#> Y275              TRUE
#> Y276              TRUE
#> Y277              TRUE
#> Y278              TRUE
#> Y279              TRUE
#> Y280              TRUE
#> Y281              TRUE
#> Y282              TRUE
#> Y283              TRUE
#> Y284              TRUE
#> Y285              TRUE
#> Y286              TRUE
#> Y287              TRUE
#> Y288              TRUE
#> Y289              TRUE
#> Y290              TRUE
#> Y291              TRUE
#> Y292              TRUE
#> Y293              TRUE
#> Y294              TRUE
#> Y295              TRUE
#> Y296              TRUE
#> Y297              TRUE
#> Y298              TRUE
#> Y299              TRUE
#> Y300              TRUE
#> Y301              TRUE
#> Y302              TRUE
#> Y303              TRUE
#> Y304              TRUE
#> Y305              TRUE
#> Y306              TRUE
#> Y307              TRUE
#> Y308              TRUE
#> Y309              TRUE
#> Y310              TRUE
#> Y311              TRUE
#> Y312              TRUE
#> Y313              TRUE
#> Y314              TRUE
#> Y315              TRUE
#> Y316              TRUE
#> Y317              TRUE
#> Y318              TRUE
#> Y319              TRUE
#> Y320              TRUE
#> Y321              TRUE
#> Y322              TRUE
#> Y323              TRUE
#> Y324              TRUE
#> Y325              TRUE
#> Y326              TRUE
#> Y327              TRUE
#> Y328              TRUE
#> Y329             FALSE
#> Y330              TRUE
#> Y331              TRUE
#> Y332              TRUE
#> Y333              TRUE
#> Y334              TRUE
#> Y335              TRUE
#> Y336              TRUE
#> Y337              TRUE
#> Y338              TRUE
#> Y339              TRUE
#> Y340              TRUE
#> Y341              TRUE
#> Y342              TRUE
#> Y343              TRUE
#> Y344              TRUE
#> Y345              TRUE
#> Y346              TRUE
#> Y347              TRUE
#> Y348              TRUE
#> Y349              TRUE
#> Y350              TRUE
#> Y351              TRUE
#> Y352              TRUE
#> Y353              TRUE
#> Y354              TRUE
#> Y355              TRUE
#> Y356              TRUE
#> Y357              TRUE
#> Y358              TRUE
#> Y359              TRUE
#> Y360              TRUE
#> Y361              TRUE
#> Y362              TRUE
#> Y363              TRUE
#> Y364              TRUE
#> Y365              TRUE
#> Y366              TRUE
#> Y367              TRUE
#> Y368              TRUE
#> Y369              TRUE
#> Y370              TRUE
#> Y371              TRUE
#> Y372              TRUE
#> Y373              TRUE
#> Y374              TRUE
#> Y375              TRUE
#> Y376              TRUE
#> Y377              TRUE
#> Y378              TRUE
#> Y379              TRUE
#> Y380              TRUE
#> Y381              TRUE
#> Y382              TRUE
#> Y383              TRUE
#> Y384              TRUE
#> Y385              TRUE
#> Y386              TRUE
#> Y387              TRUE
#> Y388              TRUE
#> Y389              TRUE
#> Y390              TRUE
#> Y391              TRUE
#> Y392              TRUE
#> Y393              TRUE
#> Y394              TRUE
#> Y395              TRUE
#> Y396              TRUE
#> Y397              TRUE
#> Y398              TRUE
#> Y399              TRUE
#> Y400              TRUE
#> Y401              TRUE
#> Y402              TRUE
#> Y403              TRUE
#> Y404              TRUE
#> Y405              TRUE
#> Y406              TRUE
#> Y407              TRUE
#> Y408             FALSE
#> Y409              TRUE
#> Y410              TRUE
#> Y411              TRUE
#> Y412              TRUE
#> Y413              TRUE
#> Y414              TRUE
#> Y415              TRUE
#> Y416              TRUE
#> Y417              TRUE
#> Y418              TRUE
#> Y419              TRUE
#> Y420              TRUE
#> Y421              TRUE
#> Y422              TRUE
#> Y423              TRUE
#> Y424              TRUE
#> Y425              TRUE
#> Y426              TRUE
#> Y427              TRUE
#> Y428              TRUE
#> Y429              TRUE
#> Y430              TRUE
#> Y431              TRUE
#> Y432              TRUE
#> Y433              TRUE
#> Y434              TRUE
#> Y435              TRUE
#> Y436              TRUE
#> Y437              TRUE
#> Y438              TRUE
#> Y439              TRUE
#> Y440              TRUE
#> Y441              TRUE
#> Y442              TRUE
#> Y443              TRUE
#> Y444              TRUE
#> Y445              TRUE
#> Y446              TRUE
#> Y447              TRUE
#> Y448              TRUE
#> Y449              TRUE
#> Y450              TRUE
#> Y451              TRUE
#> Y452              TRUE
#> Y453              TRUE
#> Y454              TRUE
#> Y455              TRUE
#> Y456              TRUE
#> Y457              TRUE
#> Y458              TRUE
#> Y459              TRUE
#> Y460              TRUE
#> Y461              TRUE
#> Y462              TRUE
#> Y463              TRUE
#> Y464              TRUE
#> Y465              TRUE
#> Y466              TRUE
#> Y467              TRUE
#> Y468              TRUE
#> Y469              TRUE
#> Y470              TRUE
#> Y471              TRUE
#> Y472              TRUE
#> Y473              TRUE
#> Y474              TRUE
#> Y475              TRUE
#> Y476              TRUE
#> Y477              TRUE
#> Y478              TRUE
#> Y479             FALSE
#> Y480              TRUE
#> Y481              TRUE
#> Y482              TRUE
#> Y483              TRUE
#> Y484              TRUE
#> Y485              TRUE
#> Y486              TRUE
#> Y487              TRUE
#> Y488              TRUE
#> Y489              TRUE
#> Y490              TRUE
#> Y491              TRUE
#> Y492              TRUE
#> Y493              TRUE
#> Y494              TRUE
#> Y495              TRUE
#> Y496              TRUE
#> Y497              TRUE
#> Y498              TRUE
#> Y499              TRUE
#> Y500              TRUE
#> Y501              TRUE
#> Y502              TRUE
#> Y503              TRUE
#> Y504              TRUE
#> Y505              TRUE
#> Y506              TRUE
#> Y507             FALSE
#> Y508              TRUE
#> Y509              TRUE
#> Y510              TRUE
#> Y511              TRUE
#> Y512              TRUE
#> Y513              TRUE
#> Y514              TRUE
#> Y515             FALSE
#> Y516              TRUE
#> Y517              TRUE
#> Y518              TRUE
#> Y519              TRUE
#> Y520              TRUE
#> Y521              TRUE
#> Y522              TRUE
#> Y523             FALSE
#> Y524              TRUE
#> Y525              TRUE
#> Y526              TRUE
#> Y527             FALSE
#> Y528              TRUE
#> Y529              TRUE
#> Y530              TRUE
#> Y531             FALSE
#> Y532              TRUE
#> Y533              TRUE
#> Y534              TRUE
#> Y535             FALSE
#> Y536              TRUE
#> Y537              TRUE
#> Y538              TRUE
#> Y539              TRUE
#> Y540              TRUE
#> Y541              TRUE
#> Y542              TRUE
#> Y543              TRUE
#> Y544              TRUE
#> Y545              TRUE
#> Y546              TRUE
#> Y547              TRUE
#> Y548              TRUE
#> Y549              TRUE
#> Y550              TRUE
#> Y551              TRUE
#> Y552              TRUE
#> Y553              TRUE
#> Y554              TRUE
#> Y555             FALSE
#> Y556              TRUE
#> Y557              TRUE
#> Y558              TRUE
#> Y559              TRUE
#> Y560              TRUE
#> Y561              TRUE
#> Y562              TRUE
#> Y563              TRUE
#> Y564              TRUE
#> Y565              TRUE
#> Y566              TRUE
#> Y567              TRUE
#> Y568              TRUE
#> Y569              TRUE
#> Y570              TRUE
#> Y571              TRUE
#> Y572              TRUE
#> Y573              TRUE
#> Y574              TRUE
#> Y575              TRUE
#> Y576              TRUE
#> Y577              TRUE
#> Y578              TRUE
#> Y579              TRUE
#> Y580              TRUE
#> Y581              TRUE
#> Y582              TRUE
#> Y583              TRUE
#> Y584              TRUE
#> Y585              TRUE
#> Y586              TRUE
#> Y587              TRUE
#> Y588              TRUE
#> Y589              TRUE
#> Y590              TRUE
#> Y591              TRUE
#> Y592              TRUE
#> Y593              TRUE
#> Y594              TRUE
#> Y595              TRUE
#> Y596              TRUE
#> Y597              TRUE
#> Y598              TRUE
#> Y599              TRUE
#> Y600              TRUE
#> Y601              TRUE
#> Y602              TRUE
#> Y603              TRUE
#> Y604              TRUE
#> Y605              TRUE
#> Y606              TRUE
#> Y607              TRUE
#> Y608              TRUE
#> Y609              TRUE
#> Y610              TRUE
#> Y611              TRUE
#> Y612              TRUE
#> Y613              TRUE
#> Y614              TRUE
#> Y615             FALSE
#> Y616              TRUE
#> Y617              TRUE
#> Y618              TRUE
#> Y619              TRUE
#> Y620              TRUE
#> Y621              TRUE
#> Y622              TRUE
#> Y623              TRUE
#> Y624              TRUE
#> Y625              TRUE
#> Y626              TRUE
#> Y627              TRUE
#> Y628              TRUE
#> Y629              TRUE
#> Y630              TRUE
#> Y631             FALSE
#> Y632              TRUE
#> Y633              TRUE
#> Y634              TRUE
#> Y635             FALSE
#> Y636              TRUE
#> Y637              TRUE
#> Y638              TRUE
#> Y639              TRUE
#> Y640              TRUE
#> Y641              TRUE
#> Y642              TRUE
#> Y643              TRUE
#> Y644              TRUE
#> Y645              TRUE
#> Y646              TRUE
#> Y647              TRUE
#> Y648              TRUE
#> Y649              TRUE
#> Y650              TRUE
#> Y651              TRUE
#> Y652              TRUE
#> Y653              TRUE
#> Y654              TRUE
#> Y655              TRUE
#> Y656              TRUE
#> Y657              TRUE
#> Y658              TRUE
#> Y659             FALSE
#> Y660              TRUE
#> Y661              TRUE
#> Y662              TRUE
#> Y663              TRUE
#> Y664              TRUE
#> Y665              TRUE
#> Y666              TRUE
#> Y667              TRUE
#> Y668              TRUE
#> Y669              TRUE
#> Y670              TRUE
#> Y671              TRUE
#> Y672              TRUE
#> Y673              TRUE
#> Y674              TRUE
#> Y675              TRUE
#> Y676              TRUE
#> Y677              TRUE
#> Y678              TRUE
#> Y679              TRUE
#> Y680              TRUE
#> Y681              TRUE
#> Y682              TRUE
#> Y683              TRUE
#> Y684              TRUE
#> Y685              TRUE
#> Y686              TRUE
#> Y687              TRUE
#> Y688              TRUE
#> Y689              TRUE
#> Y690              TRUE
#> Y691              TRUE
#> Y692              TRUE
#> Y693              TRUE
#> Y694              TRUE
#> Y695              TRUE
#> Y696              TRUE
#> Y697              TRUE
#> Y698              TRUE
#> Y699              TRUE
#> Y700              TRUE
#> Y701              TRUE
#> Y702              TRUE
#> Y703              TRUE
#> Y704              TRUE
#> Y705              TRUE
#> Y706              TRUE
#> Y707              TRUE
#> Y708              TRUE
#> Y709              TRUE
#> Y710              TRUE
#> Y711              TRUE
#> Y712              TRUE
#> Y713              TRUE
#> Y714              TRUE
#> Y715              TRUE
#> Y716              TRUE
#> Y717              TRUE
#> Y718              TRUE
#> Y719              TRUE
#> Y720              TRUE
#> Y721              TRUE
#> Y722              TRUE
#> Y723              TRUE
#> Y724              TRUE
#> Y725              TRUE
#> Y726              TRUE
#> Y727              TRUE
#> Y728              TRUE
#> Y729              TRUE
#> Y730              TRUE
#> Y731              TRUE
#> Y732              TRUE
#> Y733              TRUE
#> Y734              TRUE
#> Y735              TRUE
#> Y736              TRUE
#> Y737              TRUE
#> Y738              TRUE
#> Y739              TRUE
#> Y740              TRUE
#> Y741              TRUE
#> Y742              TRUE
#> Y743              TRUE
#> Y744              TRUE
#> Y745              TRUE
#> Y746              TRUE
#> Y747              TRUE
#> Y748              TRUE
#> Y749              TRUE
#> Y750              TRUE
#> Y751              TRUE
#> Y752              TRUE
#> Y753              TRUE
#> Y754              TRUE
#> Y755              TRUE
#> Y756              TRUE
#> Y757              TRUE
#> Y758              TRUE
#> Y759              TRUE
#> Y760              TRUE
#> Y761              TRUE
#> Y762              TRUE
#> Y763              TRUE
#> Y764              TRUE
#> Y765              TRUE
#> Y766              TRUE
#> Y767              TRUE
#> Y768              TRUE
#> Y769              TRUE
#> Y770              TRUE
#> Y771              TRUE
#> Y772              TRUE
#> Y773              TRUE
#> Y774              TRUE
#> Y775              TRUE
#> Y776              TRUE
#> Y777              TRUE
#> Y778              TRUE
#> Y779              TRUE
#> Y780              TRUE
#> Y781              TRUE
#> Y782              TRUE
#> Y783              TRUE
#> Y784              TRUE
#> Y785              TRUE
#> Y786              TRUE
#> Y787              TRUE
#> Y788              TRUE
#> Y789              TRUE
#> Y790             FALSE
#> Y791              TRUE
#> Y792              TRUE
#> Y793              TRUE
#> Y794              TRUE
#> Y795              TRUE
#> Y796              TRUE
#> Y797              TRUE
#> Y798              TRUE
#> Y799              TRUE
#> Y800              TRUE
#> Y801              TRUE
#> Y802              TRUE
#> Y803              TRUE
#> Y804              TRUE
#> Y805              TRUE
#> Y806              TRUE
#> Y807              TRUE
#> Y808              TRUE
#> Y809              TRUE
#> Y810              TRUE
#> Y811              TRUE
#> Y812              TRUE
#> Y813              TRUE
#> Y814              TRUE
#> Y815              TRUE
#> Y816              TRUE
#> Y817              TRUE
#> Y818              TRUE
#> Y819              TRUE
#> Y820              TRUE
#> Y821              TRUE
#> Y822              TRUE
#> Y823              TRUE
#> Y824              TRUE
#> Y825              TRUE
#> Y826              TRUE
#> Y827              TRUE
#> Y828              TRUE
#> Y829              TRUE
#> Y830              TRUE
#> Y831             FALSE
#> Y832              TRUE
#> Y833              TRUE
#> Y834              TRUE
#> Y835              TRUE
#> Y836              TRUE
#> Y837              TRUE
#> Y838              TRUE
#> Y839              TRUE
#> Y840              TRUE
#> Y841              TRUE
#> Y842              TRUE
#> Y843              TRUE
#> Y844              TRUE
#> Y845              TRUE
#> Y846              TRUE
#> Y847              TRUE
#> Y848              TRUE
#> Y849              TRUE
#> Y850              TRUE
#> Y851              TRUE
#> Y852              TRUE
#> Y853              TRUE
#> Y854              TRUE
#> Y855              TRUE
#> Y856              TRUE
#> Y857              TRUE
#> Y858              TRUE
#> Y859              TRUE
#> Y860              TRUE
#> Y861              TRUE
#> Y862              TRUE
#> Y863              TRUE
#> Y864              TRUE
#> Y865              TRUE
#> Y866              TRUE
#> Y867              TRUE
#> Y868              TRUE
#> Y869              TRUE
#> Y870              TRUE
#> Y871              TRUE
#> Y872              TRUE
#> Y873              TRUE
#> Y874              TRUE
#> Y875              TRUE
#> Y876             FALSE
#> Y877              TRUE
#> Y878              TRUE
#> Y879              TRUE
#> Y880              TRUE
#> Y881              TRUE
#> Y882              TRUE
#> Y883              TRUE
#> Y884              TRUE
#> Y885              TRUE
#> Y886              TRUE
#> Y887             FALSE
#> Y888              TRUE
#> Y889              TRUE
#> Y890              TRUE
#> Y891             FALSE
#> Y892              TRUE
#> Y893              TRUE
#> Y894              TRUE
#> Y895              TRUE
#> Y896              TRUE
#> Y897              TRUE
#> Y898              TRUE
#> Y899              TRUE
#> Y900              TRUE
#> Y901              TRUE
#> Y902              TRUE
#> Y903              TRUE
#> Y904              TRUE
#> Y905              TRUE
#> Y906              TRUE
#> Y907              TRUE
#> Y908              TRUE
#> Y909              TRUE
#> Y910              TRUE
#> Y911             FALSE
#> Y912              TRUE
#> Y913              TRUE
#> Y914              TRUE
#> Y915              TRUE
#> Y916              TRUE
#> Y917              TRUE
#> Y918              TRUE
#> Y919              TRUE
#> Y920              TRUE
#> Y921              TRUE
#> Y922              TRUE
#> Y923              TRUE
#> Y924              TRUE
#> Y925              TRUE
#> Y926              TRUE
#> Y927              TRUE
#> Y928              TRUE
#> Y929              TRUE
#> Y930              TRUE
#> Y931              TRUE
#> Y932              TRUE
#> Y933              TRUE
#> Y934              TRUE
#> Y935              TRUE
#> Y936              TRUE
#> Y937              TRUE
#> Y938              TRUE
#> Y939              TRUE
#> Y940              TRUE
#> Y941              TRUE
#> Y942              TRUE
#> Y943              TRUE
#> Y944              TRUE
#> Y945              TRUE
#> Y946              TRUE
#> Y947              TRUE
#> Y948              TRUE
#> Y949              TRUE
#> Y950              TRUE
#> Y951              TRUE
#> Y952              TRUE
#> Y953              TRUE
#> Y954              TRUE
#> Y955              TRUE
#> Y956              TRUE
#> Y957              TRUE
#> Y958              TRUE
#> Y959              TRUE
#> Y960              TRUE
#> Y961              TRUE
#> Y962              TRUE
#> Y963              TRUE
#> Y964              TRUE
#> Y965              TRUE
#> Y966              TRUE
#> Y967              TRUE
#> Y968              TRUE
#> Y969              TRUE
#> Y970              TRUE
#> Y971              TRUE
#> Y972              TRUE
#> Y973              TRUE
#> Y974              TRUE
#> Y975              TRUE
#> Y976              TRUE
#> Y977              TRUE
#> Y978              TRUE
#> Y979              TRUE
#> Y980              TRUE
#> Y981              TRUE
#> Y982              TRUE
#> Y983              TRUE
#> Y984              TRUE
#> Y985              TRUE
#> Y986              TRUE
#> Y987              TRUE
#> Y988              TRUE
#> Y989              TRUE
#> Y990              TRUE
#> Y991              TRUE
#> Y992              TRUE
#> Y993              TRUE
#> Y994              TRUE
#> Y995              TRUE
#> Y996              TRUE
#> Y997              TRUE
#> Y998              TRUE
#> Y999              TRUE
#> Y1000             TRUE
#> Y1001             TRUE
#> Y1002             TRUE
#> Y1003             TRUE
#> Y1004             TRUE
#> Y1005             TRUE
#> Y1006             TRUE
#> Y1007             TRUE
#> Y1008             TRUE
#> Y1009             TRUE
#> Y1010             TRUE
#> Y1011             TRUE
#> Y1012             TRUE
#> Y1013             TRUE
#> Y1014             TRUE
#> Y1015             TRUE
#> Y1016             TRUE
#> Y1017             TRUE
#> Y1018             TRUE
#> Y1019             TRUE
#> Y1020             TRUE
#> Y1021             TRUE
#> Y1022             TRUE
#> Y1023             TRUE
#> Y1024             TRUE
#> Y1025             TRUE
#> Y1026             TRUE
#> Y1027             TRUE
#> Y1028             TRUE
#> Y1029             TRUE
#> Y1030             TRUE
#> Y1031             TRUE
#> Y1032             TRUE
#> Y1033             TRUE
#> Y1034             TRUE
#> Y1035             TRUE

# equivalent to the pre-existing two-call workflow:
fish_std2 <- standardize_geometry(standardize_orientation(fish), orient = FALSE)
#> standardize_orientation(): 1006 of 1036 specimen(s) mirrored (234 horizontally, 1004 vertically) to a consistent head-left, belly-down orientation.
#> standardize_geometry(): standardized 1036 specimen(s) (isotropic rescale + scale bar + rotation); no landmark coordinate value was corrected (see correct_geometry_conventions() for that).

# then, only if/where desired, actively correct remaining conventions:
fish_corrected <- correct_geometry_conventions(fish_std)
#> correct_geometry_conventions(): corrected 9633 landmark coordinate(s) across 911 specimen(s).
```
