# Retract the landmarks of a photograph (it goes back to "not measured")

The journal is append-only and is the source of truth: deleting a row of
the workbook would not stand, since the digitizer rebuilds the workbook
from the journal. A measurement is therefore withdrawn by APPENDING a
retraction record for each of its keys (`mode = "retracted"`);
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
then leaves those keys out, so the photograph is "to measure" again
everywhere – the digitizer's "new" queue,
[`measure_queue()`](https://funtraits.github.io/intraitR/reference/measure_queue.md),
the workbook rebuilt from the journal. Nothing is erased: the earlier
records stay in the journal and
[`landmark_journal_history()`](https://funtraits.github.io/intraitR/reference/landmark_journal_history.md)
shows them, retraction included. A later digitization of the same key
simply supersedes the retraction.

## Usage

``` r
retract_landmarks(
  journal_dir,
  photo = NULL,
  row_key = NULL,
  xlsx_path = NULL,
  operator = NULL
)
```

## Arguments

- journal_dir:

  Landmark journal directory.

- photo:

  Photograph code(s) (file name without extension): every live key
  recorded on that photograph is retracted – all the individuals of a
  plate, all the repeats.

- row_key:

  Key(s) to retract directly, in addition to `photo`.

- xlsx_path:

  Optional workbook of
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md):
  the rows of the retracted specimens are removed from every sheet now
  (atomic write, the previous file kept as `.prev.xlsx`), rather than at
  the next rebuild. Do not run this while a digitizer has that workbook
  open: it would write its own copy back.

- operator:

  Who retracts (recorded in the journal).

## Value

Invisibly, a data.frame of the retracted keys (`row_key`, `specimen`,
`photo_file`); zero rows when nothing was measured.

## Details

Typical use: the prepared image of a measured photograph has been
re-cropped or turned, so its landmarks, which are in the pixels of that
image, no longer fall on the fish.

## See also

[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md),
[`landmark_journal_history()`](https://funtraits.github.io/intraitR/reference/landmark_journal_history.md)

## Examples

``` r
d <- file.path(tempdir(), "retract_demo")
jr <- landmark_journal_open(d, operator = "AT")
#> Session journal: /tmp/RtmpgJS8xD/retract_demo/landmarks_AT_20261024T184956Z.tsv
landmark_journal_append(jr, "fish_01", cbind(c(10, 20), c(5, 6)), 1:2,
                        specimen = "fish_01", photo_file = "fish_01.jpg")
nrow(consolidate_landmarks(d))          # 1
#> [1] 1
retract_landmarks(d, photo = "fish_01")
#> Session journal: /tmp/RtmpgJS8xD/retract_demo/landmarks_runner_20261024T184956Z.tsv
#> 1 measurement(s) retracted: fish_01.
nrow(consolidate_landmarks(d))          # 0
#> [1] 0
unlink(d, recursive = TRUE)
```
