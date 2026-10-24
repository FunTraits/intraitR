# Parameters of an analysis project

The settings of every step of the analysis written by
[`write_analysis_project()`](https://funtraits.github.io/intraitR/reference/write_analysis_project.md)
(and chosen in
[`launch_intrait_analyses()`](https://funtraits.github.io/intraitR/reference/launch_intrait_analyses.md)),
with their defaults. They end up, commented, in the project's
`utils/parameters.R`, the one place where they are read.

## Usage

``` r
analysis_params(...)
```

## Arguments

- ...:

  Values replacing the defaults, by name: `seed`, `min_n`, `species`,
  `sites`, `sources`, `ratios`, `impute`, `orientation`, `geometry`,
  `scale_cm`, `scale_action`, `no_caudal_fin`, `ventral_mouth`,
  `no_pectoral_fin`, `ts_axes`, `ts_remove_outliers`, `ts_style`,
  `disparity_iter`, `pf_style`, `pf_itv_reference`, `pf_arrows`,
  `itv_nested`, `acc_metric`, `acc_n_perm`, `acc_conv_tol`,
  `acc_asymptote`, `shape`, `shape_remove_outliers`, `shape_style`,
  `shape_disparity_iter`, `fig_width_mm`, `fig_height_mm`, `fig_dpi`.

## Value

A named list.

## Examples

``` r
str(analysis_params(min_n = 10, acc_n_perm = 49))
#> List of 33
#>  $ seed                 : int 16
#>  $ min_n                : num 10
#>  $ species              : NULL
#>  $ sites                : NULL
#>  $ sources              : NULL
#>  $ ratios               : chr [1:9] "BEl" "VEp" "REs" "OGp" ...
#>  $ impute               : logi FALSE
#>  $ orientation          : logi FALSE
#>  $ geometry             : logi FALSE
#>  $ scale_cm             : num 1
#>  $ scale_action         : chr "pixels"
#>  $ no_caudal_fin        : logi FALSE
#>  $ ventral_mouth        : logi FALSE
#>  $ no_pectoral_fin      : logi FALSE
#>  $ ts_axes              : int [1:2] 1 2
#>  $ ts_remove_outliers   : logi FALSE
#>  $ ts_style             : chr "spider"
#>  $ disparity_iter       : int 999
#>  $ pf_style             : chr "hull"
#>  $ pf_itv_reference     : logi TRUE
#>  $ pf_arrows            : logi FALSE
#>  $ itv_nested           : chr "site"
#>  $ acc_metric           : chr "variance"
#>  $ acc_n_perm           : num 49
#>  $ acc_conv_tol         : num 0.05
#>  $ acc_asymptote        : num 0.95
#>  $ shape                : logi TRUE
#>  $ shape_remove_outliers: logi FALSE
#>  $ shape_style          : chr "spider"
#>  $ shape_disparity_iter : int 999
#>  $ fig_width_mm         : num 180
#>  $ fig_height_mm        : num 140
#>  $ fig_dpi              : int 300
```
