# Reset the session-level group/species colour cache

[`plot.intrait_morphospace()`](https://funtraits.github.io/intraitR/reference/plot.intrait_morphospace.md)
and
[`plot.intrait_traitspace()`](https://funtraits.github.io/intraitR/reference/plot.intrait_traitspace.md)
assign group colours from a small cache that persists for the duration
of the R session (see Details), so that the same species is always drawn
in the same colour across separate plot calls – e.g. a morphological
space and a trait space built from the same dataset, even though each
typically retains a slightly different subset of specimens (and possibly
species) after its own upstream missing-data or outlier filtering.
`reset_group_colors()` clears that cache, so that the next plot call
starts reassigning colours from scratch, in the order species are then
encountered.

## Usage

``` r
reset_group_colors()
```

## Value

Invisibly returns `NULL`.

## Details

Call this function when starting to work with an unrelated dataset in
the same R session (otherwise its species would be assigned colours
continuing on from wherever the previous dataset's species left off,
which is harmless but not particularly meaningful), or at the top of a
script whose figures must not depend on what happened to run earlier in
the session (for full reproducibility of colour assignment regardless of
call history).

## See also

[`group_colors()`](https://funtraits.github.io/intraitR/reference/group_colors.md)
(look up the current colours without resetting them)

## Examples

``` r
reset_group_colors()
```
