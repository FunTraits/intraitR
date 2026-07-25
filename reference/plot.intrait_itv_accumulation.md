# Plot intraspecific-variability rarefaction curves

One panel per trait series (arranged with
[`graphics::par()`](https://rdrr.io/r/graphics/par.html) `mfrow`), each
showing the rarefied mean against sub-sample size for every group, with
the resampling quantile band as a shaded envelope and the estimated
stabilisation sample size `n*` as a vertical dashed line. For
*convergence* framing a horizontal reference line marks the full-sample
value. For *accumulation* framing the observed portion is drawn solid
and, when `extrapolate = TRUE`, the fitted saturating model is extended
in a dashed line beyond the observed range up towards its estimated
asymptote (drawn as a horizontal dotted line), so the plateau the curve
is heading for is visible even when it lies well beyond the individuals
actually sampled – the interpolation/extrapolation style of a
rarefaction curve.

## Usage

``` r
# S3 method for class 'intrait_itv_accumulation'
plot(
  x,
  series = NULL,
  band = TRUE,
  extrapolate = TRUE,
  xmax = NULL,
  legend = c("panel", "each", "none"),
  ...
)
```

## Arguments

- x:

  An object of class `"intrait_itv_accumulation"`.

- series:

  Optional character vector selecting which trait series (panels) to
  draw; defaults to all.

- band:

  Logical, draw the resampling quantile band. Defaults to `TRUE`.

- extrapolate:

  Logical, for accumulation metrics extend the fitted curve beyond the
  observed range up to `n*` (or `xmax`) and draw the fitted asymptote.
  Ignored for convergence framing. Defaults to `TRUE`.

- xmax:

  Optional numeric, the largest sample size to extrapolate to. `NULL`
  (default) uses the largest finite `n*` in the panel, capped at ten
  times the observed maximum so a single very slowly saturating series
  cannot squash the observed range; the fitted asymptote is always drawn
  regardless, so the target remains visible even if the curve is cut off
  before reaching it.

- legend:

  Character, where to place the colour/line-type keys. One of `"panel"`
  (default; a single shared legend in its own cell of the panel grid),
  `"each"` (a legend inside every panel, the former behaviour) or
  `"none"` (no legend).

- ...:

  Further arguments passed to
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html).

## Value

Invisibly returns `x`.

## Details

With many groups and/or many trait panels, repeating the colour and
line-type keys inside every panel quickly overplots the curves. By
default (`legend = "panel"`) the keys are therefore drawn *once*, in a
dedicated cell of the panel grid (one extra slot is reserved for it),
leaving the data panels uncluttered. `legend = "each"` restores the
previous behaviour (a key in every panel), and `legend = "none"`
suppresses the keys entirely – useful when composing the panels into a
figure whose legend is added separately.
