# Methodology

## The question

The U.S. Census Bureau's American Community Survey (ACS) is the standard source for a
county's residential vacancy rate, but it's only released annually and can lag or be
suppressed for smaller geographies. The U.S. Postal Service publishes vacancy counts
quarterly, for every ZIP code in the country, as a byproduct of mail delivery — far more
current and far more granular than Census data, if it's actually reliable.

This project tests that directly: for six U.S. counties over fifteen years, how well does
USPS vacancy data actually track the Census vacancy rate? "Track" is broken into three
separate, deliberately different questions, because a data source can be strong on one
and weak on another:

1. **Do the two series move together?** — Pearson correlation, pooled and per county.
2. **Does USPS call the right direction?** — the share of year-over-year changes where
   USPS correctly flagged vacancy going up or down.
3. **How far off is USPS, on average, and how consistently?** — the average gap between
   the two rates, and its standard deviation.

## Data sources

**Census** — ACS 1-Year Estimates, Table B25002 (Occupancy Status), for six counties,
2010–2019 and 2021–2024 (the Bureau suspended the 1-year ACS for 2020 due to pandemic
data-collection issues, so that year is excluded rather than interpolated).

**USPS** — the quarterly Vacant Address Report, aggregated to the ZIP/county level, for
the same six counties and years. Two rates are computed from it:

- **Narrow rate** — short-term + long-term vacant addresses ÷ total addresses.
- **Broad rate** — the narrow-rate numerator plus "No-Stat" addresses (addresses the
  carrier can't confirm as occupied or vacant) ÷ total addresses. No-Stat is a much
  looser category, which is part of why the broad rate behaves differently below.

Four quarterly rates are averaged into one annual rate per county-year, to sit on the
same time grain as the annual Census estimate.

## Counties

One subject county plus five others sampled at random (population ≥ 65,000, for ACS
1-year eligibility) from a pool of U.S. counties outside the subject county's state:

| County | State | FIPS |
|---|---|---|
| Lancaster | PA | 42071 |
| Montgomery | OH | 39113 |
| Champaign | IL | 17019 |
| King | WA | 53033 |
| Cook | IL | 17031 |
| Onondaga | NY | 36067 |

## Pipeline

```
USPS quarterly CSVs  ─┐
                       ├─▶  Fabric Lakehouse (Files)  ─▶  Dataflow Gen2 (Power Query)  ─▶  Fabric semantic model  ─▶  Power BI report (live connection)
Census ACS CSVs      ─┘
```

Both raw sources land in a Fabric Lakehouse, one subfolder per year (USPS) or per county
(Census). A Dataflow Gen2 combines and reshapes each source with Power Query M, then a
DAX layer over the merged table computes the actual comparison — see
[`/powerbi/dax-measures.md`](../powerbi/dax-measures.md). The Power BI report connects
**live** to that semantic model rather than importing a copy, so every number on the
dashboard is computed by the model, on demand, not cached in the report file.

## Data quality issues found and fixed along the way

- **USPS header casing changes across years** (uppercase before ~2014, lowercase after) —
  broke the combined query silently at the file boundary; fixed by normalizing column
  names in Power Query.
- **A USPS classification shift around 2012** — the Broad rate jumps in every one of the
  six counties between 2011 and 2012 with no matching move in Census, consistent with a
  change in how USPS defines "No-Stat," not a real vacancy spike. This is why the Broad
  rate is treated with more caution than the Narrow rate throughout this project.
- **A one-year gap in the Census series (2020)** — handled explicitly in DAX with
  `LOOKUPVALUE(..., Year - 1)` rather than an adjacent-row offset, so year-over-year
  comparisons don't silently splice 2019 to 2021 (see `dax-measures.md`).
- **Aggregation risk on percentage columns** — a calculated column dragged straight into
  a Power BI chart gets summed, not averaged, the instant more than one row is in scope;
  every chart in this report uses an explicit `AVERAGE()`-based measure instead of the
  raw column, precisely to avoid this.

## Reproducing the numbers

[`/data/comparison_table.csv`](../data/comparison_table.csv) is the full 84-row
county-year table the dashboard is built on (6 counties × 14 years, 2020 excluded). The
headline statistics reported in the [README](../README.md) are reproducible directly from
that file — pooled Pearson correlation, the directional-match share, and the mean/standard
deviation of the gap column.
