# Open a session landmark journal (append-only)

Creates `journal_dir` if needed and a TSV file specific to this session.
The file is only ever written to by appending: it is never re-read nor
rewritten while the session runs, and becomes immutable the moment the
session ends. This is the capture layer behind
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
and the reason a crashed session costs at most the specimen being
digitized rather than the whole data set.

## Usage

``` r
landmark_journal_open(
  journal_dir,
  operator = NULL,
  app_version = NA_character_
)
```

## Arguments

- journal_dir:

  Directory holding the journals. Created if absent.

- operator:

  Operator identifier, traced in every row and in the session file name.
  `NULL` (default) uses the system user.

- app_version:

  Version of the digitizing tool, traced in every row: it is what makes
  it possible to know, in two years, with which geometry a given
  specimen was digitized.

## Value

An object of class `"intrait_journal"`: a handle to pass to
[`landmark_journal_append()`](https://funtraits.github.io/intraitR/reference/landmark_journal_append.md),
carrying the journal `path`, the `operator` and the `session_id`.

## See also

[`landmark_journal_append()`](https://funtraits.github.io/intraitR/reference/landmark_journal_append.md),
[`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md),
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md),
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)

## Examples

``` r
d <- file.path(tempdir(), "journal_demo")
jr <- landmark_journal_open(d, operator = "AT")
#> Session journal: /tmp/Rtmpg1NZEF/journal_demo/landmarks_AT_20260727T135434Z.tsv
basename(jr$path)
#> [1] "landmarks_AT_20260727T135434Z.tsv"
unlink(d, recursive = TRUE)
```
