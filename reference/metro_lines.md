# Metro SP Line Reference Table

A reference tibble mapping metro line numbers to their Portuguese and
English color names. Covers all METRO SP and ViaMobilidade lines
including planned future lines and the network total.

## Usage

``` r
metro_lines
```

## Format

A tibble with 13 rows and 3 columns:

- line_number:

  Official line number (integer). Includes 1, 2, 3, 4, 5, 6, 15, 16, 17,
  19, 20, 22, and 99 (network total).

- line_name_pt:

  Portuguese color name of the line (character).

- line_name:

  English color name of the line (character).

## Details

This dataset serves as a dimension/lookup table for joining line names
onto passenger and station datasets. Not all lines have passenger data —
some (e.g., Lines 6, 16, 17) are planned future lines with only spatial
geometry available in
[`lines`](https://viniciusoike.github.io/metrosp/reference/lines.md).

## See also

[`metro_colors`](https://viniciusoike.github.io/metrosp/reference/metro_colors.md)
for official hex color codes,
[`lines`](https://viniciusoike.github.io/metrosp/reference/lines.md) for
spatial line geometries.
