// Query: "USPS Annual"
// Exported from the real Dataflow Gen2 (see dataflow-gen2/README.md). Verbatim.
//
// USPS reports quarterly; Census reports annually. This query is the bridge between
// them — it averages "USPS Data"'s quarterly Narrow/Broad rates up to one row per
// county-year, so they can be joined against the Census annual estimate on equal footing.

shared #"USPS Annual" = let
  Source = #"USPS Data",
  #"Grouped rows" = Table.Group(Source, {"County FIPS", "Year"}, {
    {"USPS Narrow Rate (avg)", each List.Average([USPS Narrow Rate]), type nullable number},
    {"USPS Broad Rate (avg)", each List.Average([USPS Broad Rate]), type nullable number},
    {"Quarters Averaged", each Table.RowCount(_), Int64.Type}
  })
in
  #"Grouped rows";
