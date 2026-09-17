# Dataflow Gen2 — the data pipeline behind this project

Everything in [`/powerbi`](../powerbi) and [`/data`](../data) starts here. This folder
is the actual Microsoft Fabric **Dataflow Gen2** that turns raw USPS and Census CSV
files sitting in a Lakehouse into the single clean table (`Comparison`) that the Power
BI report and every DAX measure are built on.

## What a Dataflow Gen2 is, in plain terms

Think of it as a recipe that runs itself. Someone drops a new quarterly USPS file or a
new year of Census data into a folder; the dataflow reads every file in that folder,
reshapes and combines them the same way every time, and writes out one clean, ready-to-
use table. Refresh it — by hand or on a schedule — and it redoes the whole recipe from
scratch on whatever files are there now, so the two source datasets can be years apart
in format and update schedule and still land in the same shape.

Technically, it's Fabric's browser-based version of the Power Query editor familiar
from Excel and Power BI Desktop — same buttons (Combine Files, Merge Queries, Add
Column), same underlying language (Power Query M), just running in the cloud against
files in a Lakehouse instead of files on a laptop.

## How this got from Fabric onto GitHub

Fabric's Dataflow Gen2 has no direct "push to GitHub" button, and workspace-level Git
integration (the more automatic option, which syncs an entire Fabric workspace to a
repo) needs an admin-enabled Git connection that isn't turned on for this workspace.
The path used instead — and the one worth knowing, because it works from any Fabric
tenant with no admin setup — is:

1. In the dataflow's editor, **Home → Export template** (Fabric calls this a `.pqt`
   file — a *Power Query Template*).
2. A `.pqt` is a plain zip archive. Unzipped, it contains `MashupDocument.pq` — every
   query in the dataflow, written out as plain-text Power Query M — plus two small JSON
   metadata files.
3. `MashupDocument.pq` is what's split out into the files in [`queries/`](queries),
   one file per query (or logical group), with comments and the original filenames the
   Fabric editor itself uses so a reader can find their way back to what they'd see
   on-screen.

The two internal identifiers Fabric embeds in every query — the workspace ID and
Lakehouse ID — are replaced with `<WORKSPACE_ID>` / `<LAKEHOUSE_ID>` placeholders here;
they're tenant-specific plumbing with nothing to do with the transformation logic
itself, and dropping them means this code reads the same way regardless of whose Fabric
tenant it's viewed from. Everything else below is the **real, unedited M code** this
dataflow runs.

## The pipeline, end to end

```
Lakehouse/Files/USPS Vacancy Rates/**/*.csv   Lakehouse/Files/Census/*.csv
              │                                          │
              ▼                                          ▼
    ┌───────────────────┐                      (parsed directly in
    │     USPS Data      │                       the Comparison query)
    │  01-usps-data.pq   │                                │
    │  one row per        │                               │
    │  county-quarter     │                               │
    └─────────┬───────────┘                                │
              ▼                                            │
    ┌───────────────────┐                                  │
    │    USPS Annual      │                                │
    │ 02-usps-annual.pq   │                                │
    │  quarterly → one     │                               │
    │  row per county-year │                               │
    └─────────┬───────────┘                                │
              │                                             │
              └──────────────────┐             ┌───────────┘
                                  ▼             ▼
                          ┌───────────────────────────┐
                          │        Comparison           │
                          │      03-comparison.pq        │
                          │  Census rate + joined USPS    │
                          │  Narrow/Broad rate, one row    │
                          │  per county-year (the output)   │
                          └───────────────────────────────┘
                                          │
                                          ▼
                         Fabric semantic model → Power BI report
                         (/powerbi) and the extracted CSV (/data)
```

| Query | File | What it does |
|---|---|---|
| `USPS Data` | [`queries/01-usps-data.pq`](queries/01-usps-data.pq) | Combines every quarterly USPS CSV across all years into one table, keeps only the 6 tracked counties, and computes the Narrow and Broad vacancy rate for each county-quarter. |
| `USPS Annual` | [`queries/02-usps-annual.pq`](queries/02-usps-annual.pq) | Averages `USPS Data`'s quarterly rates up to one row per county-year, so USPS's quarterly cadence lines up with Census's annual one. |
| `Comparison` | [`queries/03-comparison.pq`](queries/03-comparison.pq) | Combines every annual Census CSV, computes the Census vacancy rate, and left-joins in the matching county-year from `USPS Annual`. **This is the final output** — the table everything downstream is built from. |
| *(helper queries)* | [`queries/helper-queries/`](queries/helper-queries) | Auto-generated by Fabric's "Combine Files" button the first time each source folder was connected — the per-file CSV parsing functions, not hand-written logic. Included for completeness. |

## Data-quality fixes worth calling out

Two real issues surfaced and were fixed while building this pipeline (documented in
more depth in [`../docs/methodology.md`](../docs/methodology.md)):

- **USPS's own header casing is inconsistent across years** — older files use
  `GEOID`/`AMS_RES`, newer files use `geoid`/`ams_res`. Combine Files' auto-generated
  parsing function is hard-coded to one casing (whichever file it sampled), so files in
  the other casing come back entirely blank unless the per-file helper query is patched
  to lowercase headers before the files are combined, not after.
- **Combine Files silently drops the filename column.** Fabric's own automatic "keep
  only the parsed result" step (auto-inserted right after "Invoke custom function" in
  both `01-usps-data.pq` and `03-comparison.pq`) has to be edited to also keep `"Name"`
  — otherwise there is no way to recover which file (and therefore which year) each row
  came from.

## Reproducing or extending this

Anyone with their own Fabric workspace and a similarly-shaped Lakehouse folder can
paste these `.pq` files into a new Dataflow Gen2's Advanced Editor (per query), swap in
their own workspace/Lakehouse IDs in place of the placeholders, and get the same
pipeline running end to end. The `queries/` folder structure mirrors Fabric's own
Queries pane grouping exactly, so it's also just a readable reference for how this
project's raw-CSV-to-clean-table logic actually works, independent of Fabric itself.
