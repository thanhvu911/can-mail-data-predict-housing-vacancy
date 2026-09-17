# Report definition (PBIR)

This is the real Power BI report definition, extracted directly from the project's
`.pbix` file (a `.pbix` is a standard zip archive — no Power BI tooling is needed to read
it, just a zip library). Modern Power BI reports save in **PBIR** (Power BI Report),
Microsoft's newer JSON-based format — this is what these files actually look like inside
a saved report, not a hand-written approximation.

Visual folders are named for what each visual is (`bar-chart-gap-by-county`, etc.) instead
of the random hex IDs Power BI assigns internally, for readability — the JSON content
inside each one is untouched. `page.json` describes the 1920×1080 canvas; each
`visual.json` records that visual's type, exact position/size, and its real field
bindings (which columns and measures feed its X/Y/Legend/Values wells).

This report is **live-connected** to a Fabric semantic model rather than importing a
copy of the data (see `Connections` behavior in the original `.pbix`), so no query
results are cached in these files — the actual numbers live in
[`/data/comparison_table.csv`](../../data/comparison_table.csv) and are computed on
demand by the DAX in [`/powerbi/dax-measures.md`](../dax-measures.md).
