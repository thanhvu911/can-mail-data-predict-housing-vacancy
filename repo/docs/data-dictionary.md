# Data dictionary — `data/comparison_table.csv`

84 rows: 6 counties × 14 years (2010–2024, 2020 excluded). One row = one county's data
for one year.

| Column | Type | Description |
|---|---|---|
| `County` | text | County name (e.g. `Lancaster`). |
| `State` | text | Two-letter state abbreviation. |
| `Year` | integer | Calendar year, 2010–2024 (2020 omitted — see methodology). |
| `Census Vacancy Rate` | decimal (0–1) | ACS 1-Year Estimate, Table B25002: vacant housing units ÷ total housing units. |
| `USPS Vacancy Rate (Narrow)` | decimal (0–1) | (short-term + long-term vacant addresses) ÷ total addresses, averaged across the year's 4 quarters. |
| `USPS Vacancy Rate (Broad)` | decimal (0–1) | Narrow-rate numerator + "No-Stat" addresses ÷ total addresses, same quarterly averaging. |
| `Gap Census Minus USPS Narrow` | decimal | `Census Vacancy Rate − USPS Vacancy Rate (Narrow)`. Positive = USPS Narrow reads low. |
| `Gap Census Minus USPS Broad` | decimal | `Census Vacancy Rate − USPS Vacancy Rate (Broad)`. Negative = USPS Broad reads high. |
| `Census YoY Direction` | text | `Up` / `Down` / `Flat` / `(first year)`, vs. this county's own prior year Census rate. |
| `USPS YoY Direction (Narrow)` | text | Same, for the USPS Narrow rate. |
| `Direction Match (Narrow)` | text | `Match` / `No Match`, blank for each county's first year (no prior year to compare). |

All rates are stored as decimals (0.045 = 4.5%), matching how they're stored in the
Fabric semantic model and displayed on the report (Format → Percentage).
