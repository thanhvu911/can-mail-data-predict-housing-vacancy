# DAX measures

These are the DAX calculated columns and measures behind the `Comparison` table in the
Fabric semantic model, all defined over a single fact table built in Power Query
(county, year, Census vacancy rate, USPS Narrow/Broad rates).

`USPS Direction` and the three `Avg *` measures below are quoted exactly as built and
debugged during this project. The remaining measures reproduce the same design —
documented step by step while building this project — as clean, working DAX.

## Calculated columns

```dax
Gap Narrow = Comparison[Census Vacancy Rate] - Comparison[USPS Narrow Rate (avg)]

Gap Broad = Comparison[Census Vacancy Rate] - Comparison[USPS Broad Rate (avg)]
```

Year-over-year comparisons use `LOOKUPVALUE` to pull each county's own prior-year rate,
rather than a date table — the data has an intentional one-year gap (2020 is excluded,
since the Census Bureau suspended the 1-Year ACS release that year), so a plain "previous
row" offset would silently splice 2019 to 2021. `LOOKUPVALUE` against `Year - 1` returns
blank across that gap instead, which the direction logic below treats correctly as a
fresh start rather than a fabricated trend:

```dax
Previous Census Rate =
LOOKUPVALUE(
    Comparison[Census Vacancy Rate],
    Comparison[County], Comparison[County],
    Comparison[Year], Comparison[Year] - 1
)

Previous USPS Narrow Rate (avg) =
LOOKUPVALUE(
    Comparison[USPS Narrow Rate (avg)],
    Comparison[County], Comparison[County],
    Comparison[Year], Comparison[Year] - 1
)
```

```dax
Census Direction =
IF(
    ISBLANK(Comparison[Previous Census Rate]), "First Year",
    IF(Comparison[Census Vacancy Rate] > Comparison[Previous Census Rate], "Up",
        IF(Comparison[Census Vacancy Rate] < Comparison[Previous Census Rate], "Down", "Flat")
    )
)

USPS Direction =
IF(
    ISBLANK(Comparison[Previous USPS Narrow Rate (avg)]), "First Year",
    IF(Comparison[USPS Narrow Rate (avg)] > Comparison[Previous USPS Narrow Rate (avg)], "Up",
        IF(Comparison[USPS Narrow Rate (avg)] < Comparison[Previous USPS Narrow Rate (avg)], "Down", "Flat")
    )
)

Direction Match =
IF(
    OR(Comparison[Census Direction] = "First Year", Comparison[USPS Direction] = "First Year"),
    BLANK(),
    IF(Comparison[Census Direction] = Comparison[USPS Direction], "Match", "No Match")
)
```

## Measures

Three plain averages, used everywhere a chart aggregates across county-year rows —
dragging the raw columns above straight into a chart lets Power BI apply its default
summarization (Sum) the moment more than one row is in scope, which silently corrupts a
column of percentages:

```dax
Avg Census Vacancy Rate = AVERAGE(Comparison[Census Vacancy Rate])
Avg USPS Narrow Rate    = AVERAGE(Comparison[USPS Narrow Rate (avg)])
Avg USPS Broad Rate     = AVERAGE(Comparison[USPS Broad Rate (avg)])
```

```dax
Average Gap Narrow = AVERAGE(Comparison[Gap Narrow])
Average Gap Broad  = AVERAGE(Comparison[Gap Broad])

Gap StdDev Narrow = STDEVX.P(Comparison, Comparison[Gap Narrow])
Gap StdDev Broad  = STDEVX.P(Comparison, Comparison[Gap Broad])

Directional Match Rate =
DIVIDE(
    CALCULATE(COUNTROWS(Comparison), Comparison[Direction Match] = "Match"),
    CALCULATE(COUNTROWS(Comparison), Comparison[Direction Match] IN {"Match", "No Match"})
)
```

Pearson correlation has no built-in DAX function, so it's built by hand from its
definition — sums, sums of squares, and a sum of cross-products, all evaluated over the
table with `SUMX`. (The variable holding the running sum was originally named `SumX`,
which — case-insensitively — collides with the built-in `SUMX(...)` function itself and
throws `The syntax for 'SumX' is incorrect` the moment it's referenced on its own;
renaming it to `SigmaX` was the fix.)

```dax
Correlation (Narrow) =
VAR SigmaX   = SUMX(Comparison, Comparison[Census Vacancy Rate])
VAR SigmaY   = SUMX(Comparison, Comparison[USPS Narrow Rate (avg)])
VAR SigmaXY  = SUMX(Comparison, Comparison[Census Vacancy Rate] * Comparison[USPS Narrow Rate (avg)])
VAR SigmaX2  = SUMX(Comparison, Comparison[Census Vacancy Rate] ^ 2)
VAR SigmaY2  = SUMX(Comparison, Comparison[USPS Narrow Rate (avg)] ^ 2)
VAR N        = COUNTROWS(Comparison)
VAR Numerator   = N * SigmaXY - SigmaX * SigmaY
VAR Denominator = SQRT((N * SigmaX2 - SigmaX ^ 2) * (N * SigmaY2 - SigmaY ^ 2))
RETURN
    DIVIDE(Numerator, Denominator)

Correlation (Broad) =
VAR SigmaX   = SUMX(Comparison, Comparison[Census Vacancy Rate])
VAR SigmaY   = SUMX(Comparison, Comparison[USPS Broad Rate (avg)])
VAR SigmaXY  = SUMX(Comparison, Comparison[Census Vacancy Rate] * Comparison[USPS Broad Rate (avg)])
VAR SigmaX2  = SUMX(Comparison, Comparison[Census Vacancy Rate] ^ 2)
VAR SigmaY2  = SUMX(Comparison, Comparison[USPS Broad Rate (avg)] ^ 2)
VAR N        = COUNTROWS(Comparison)
VAR Numerator   = N * SigmaXY - SigmaX * SigmaY
VAR Denominator = SQRT((N * SigmaX2 - SigmaX ^ 2) * (N * SigmaY2 - SigmaY ^ 2))
RETURN
    DIVIDE(Numerator, Denominator)
```

Both `Correlation (Narrow)` and every other measure above respond live to the report's
County and Year slicers — filtering to one county recalculates every number in this file
for that county alone, which is what the per-county screenshots in [`/screenshots`](../screenshots) show.
