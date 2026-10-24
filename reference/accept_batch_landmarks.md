# Record the predictions of an automatic pre-pass without reviewing them

Writes the landmarks found by
[`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
to the measurement journal as they are, without anyone looking at them –
what the digitizer would record if every pre-filled photograph were
saved untouched. It is meant for a large batch on which the model is
known to do well; the price is that every error the model made is now a
measurement.

## Usage

``` r
accept_batch_landmarks(
  batch,
  journal_dir,
  operator,
  photos = NULL,
  include_flagged = FALSE,
  ruler_mm = 10,
  xlsx_path = NULL,
  dry_run = FALSE
)
```

## Arguments

- batch:

  Output folder of
  [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md),
  or its returned list.

- journal_dir:

  Folder of the landmark journal.

- operator:

  Operator recorded with the records (who ACCEPTED them).

- photos:

  Optional: restrict to these photographs (paths, file names or codes,
  i.e. file names without extension).

- include_flagged:

  Also accept the photographs the pre-pass flagged.

- ruler_mm:

  Real distance between landmarks 20 and 21, in mm, used for `mm_per_px`
  when the ruler was detected.

- xlsx_path:

  Optional workbook rebuilt from the journal afterwards
  ([`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)).

- dry_run:

  Report what would be recorded, write nothing.

## Value

Invisibly, a data.frame: `photo`, `code`, `flags`, `status`
(`"accepted"`, `"dry-run"`, `"flagged"`, `"already measured"`,
`"plate"`, `"no landmarks"`, `"incomplete"`), `n_points`.

## Details

What is accepted, and what is not:

- photographs the pre-pass FLAGGED (`flags` non-empty: upside down, at
  the border, low confidence, no readable ruler, several fish...) are
  left out unless `include_flagged = TRUE` – they are the ones a person
  should open;

- a photograph that already has a measurement in the journal is never
  overwritten;

- plates (several fish on one photograph) are left out, as in the
  digitizer;

- the conventions of the digitizer are applied (perpendicular depths,
  derived ventral points and LM23), exactly as when a pre-filled
  photograph opens.

Nothing is hidden: every point keeps the status `"predicted"` (the
derived ones `"derived"`), the entry is `reviewed = "no"`, and the
record says it came from here (`app_version`).
[`landmark_journal_qc()`](https://funtraits.github.io/intraitR/reference/landmark_journal_qc.md)
and the Results of the hub list such specimens as not reviewed, and
opening one in the digitizer (mode `"correct"`) and saving it turns it
into an ordinary, checked measurement.

## See also

[`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md),
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
[`retract_landmarks()`](https://funtraits.github.io/intraitR/reference/retract_landmarks.md)

## Examples

``` r
if (FALSE) { # \dontrun{
res <- batch_landmarks("prepared/T26/20260615", out_dir = "batch_T26")
accept_batch_landmarks(res, "measurements/landmark_journal", operator = "AT",
                       dry_run = TRUE)
} # }
```
