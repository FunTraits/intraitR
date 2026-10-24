# Open the database (read-only by default)

Read-only is the normal mode: the database is derived, and must never be
written to by hand. It also lets several R processes open the same file
simultaneously.

## Usage

``` r
fishmorph_db_connect(db_path, read_only = TRUE)
```

## Arguments

- db_path:

  Path of the `.duckdb` file.

- read_only:

  Open the database read-only (default `TRUE`). Use `FALSE` only to
  rebuild it.

## Value

A DBI connection; close it with
[`DBI::dbDisconnect()`](https://dbi.r-dbi.org/reference/dbDisconnect.html).
