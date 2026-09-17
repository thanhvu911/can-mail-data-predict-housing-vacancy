// Query: "USPS Data"
// Exported from the real Dataflow Gen2 via Home → Export template, then extracted
// from the resulting .pqt (itself a zip archive — see dataflow-gen2/README.md).
// Workspace/lakehouse identifiers redacted; every transform step is verbatim.
//
// Reads every quarterly USPS vacancy CSV out of the Lakehouse's
// Files/USPS Vacancy Rates folder, combines them into one flat table, and derives
// the two USPS vacancy rates (Narrow / Broad) at the county-quarter grain.

shared #"USPS Data" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "<WORKSPACE_ID>"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "<LAKEHOUSE_ID>"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Files", ItemKind = "Folder"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Name = "USPS Vacancy Rates"]}[Content],

  // Every year sits in its own subfolder; expanding "Content" flattens
  // year-folder rows down to one row per actual quarterly CSV file.
  #"Expanded Content" = Table.ExpandTableColumn(#"Navigation 3", "Content",
    {"Content", "Name", "Extension", "Date accessed", "Date modified", "Date created", "Attributes", "Folder Path"},
    {"Content.1", "Name.1", "Extension.1", "Date accessed.1", "Date modified.1", "Date created.1", "Attributes.1", "Folder Path.1"}),
  #"Removed other columns" = Table.SelectColumns(#"Expanded Content",
    {"Content.1", "Name.1", "Extension.1", "Date accessed.1", "Date modified.1", "Date created.1", "Attributes.1", "Folder Path.1"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed other columns",
    {{"Content.1", "Content"}, {"Name.1", "Name"}, {"Extension.1", "Extension"}, {"Date accessed.1", "Date accessed"},
     {"Date modified.1", "Date modified"}, {"Date created.1", "Date created"}, {"Attributes.1", "Attributes"}, {"Folder Path.1", "Folder Path"}}),
  #"Filtered rows" = Table.SelectRows(#"Renamed columns", each ([Extension] = ".csv")),
  #"Filtered hidden files" = Table.SelectRows(#"Filtered rows", each [Attributes]?[Hidden]? <> true),

  // Parse every file through the "Transform file" helper function
  // (see helper-queries/transform-file-usps.pq), keeping the filename alongside it.
  #"Invoke custom function" = Table.AddColumn(#"Filtered hidden files", "Transform file", each #"Transform file"([Content])),
  #"Removed other columns 1" = Table.SelectColumns(#"Invoke custom function", {"Transform file", "Name"}),
  #"Expanded table column" = Table.ExpandTableColumn(#"Removed other columns 1", "Transform file",
    Table.ColumnNames(#"Transform file"(#"Sample file"))),

  // Type every USPS column (61 fields total — only a handful are used downstream;
  // the rest are USPS's own age-bucketed vacancy breakdowns, kept for completeness).
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded table column", {
    {"geoid", type text}, {"ams_res", type number}, {"ams_bus", type number}, {"ams_oth", type number},
    {"res_vac", type number}, {"bus_vac", type number}, {"oth_vac", type number},
    {"avg_vac_r", type number}, {"avg_vac_b", type number}, {"avg_vac_o", type number},
    {"vac_3_res", type number}, {"vac_3_bus", type number}, {"vac_3_oth", type number},
    {"vac_3_6_r", type number}, {"vac_3_6_b", type number}, {"vac_3_6_o", type number},
    {"vac_6_12r", type number}, {"vac_6_12b", type number}, {"vac_6_12o", type number},
    {"vac_12_24r", type number}, {"vac_12_24b", type number}, {"vac_12_24o", type number},
    {"vac_24_36r", type number}, {"vac_24_36b", type number}, {"vac_24_36o", type number},
    {"vac_36_res", type number}, {"vac_36_bus", type number}, {"vac_36_oth", type number},
    {"pqv_is_res", type number}, {"pqv_is_bus", type number}, {"pqv_is_oth", type number},
    {"pqv_ns_res", type number}, {"pqv_ns_bus", type number}, {"pqv_ns_oth", type number},
    {"nostat_res", type number}, {"nostat_bus", type number}, {"nostat_oth", type number},
    {"avg_ns_res", type number}, {"avg_ns_bus", type number}, {"avg_ns_oth", type number},
    {"ns_3_res", type number}, {"ns_3_bus", type number}, {"ns_3_oth", type number},
    {"ns_3_6_res", type number}, {"ns_3_6_bus", type number}, {"ns_3_6_oth", type number},
    {"ns_6_12_r", type number}, {"ns_6_12_b", type number}, {"ns_6_12_o", type number},
    {"ns_12_24_r", type number}, {"ns_12_24_b", type number}, {"ns_12_24_o", type number},
    {"ns_24_36_r", type number}, {"ns_24_36_b", type number}, {"ns_24_36_o", type number},
    {"ns_36_res", type number}, {"ns_36_bus", type number}, {"ns_36_oth", type number},
    {"pqns_is_r", type number}, {"pqns_is_b", type number}, {"pqns_is_o", type number}
  }),

  // County FIPS = first 5 characters of the 11-digit geoid (state + county).
  #"Added custom" = Table.TransformColumnTypes(
    Table.AddColumn(#"Changed column type", "County FIPS", each Text.Start([geoid], 5)),
    {{"County FIPS", type text}}),

  // Keep only the six counties this project tracks.
  #"Filtered rows 1" = Table.SelectRows(#"Added custom", each
    [County FIPS] = "42071" or [County FIPS] = "17019" or [County FIPS] = "39113" or
    [County FIPS] = "17031" or [County FIPS] = "53033" or [County FIPS] = "36067"),

  // "Period" = the filename without its extension, e.g. "Q4 2019.csv" -> "Q4 2019".
  #"Added custom 1" = Table.TransformColumnTypes(
    Table.AddColumn(#"Filtered rows 1", "Period", each Text.BeforeDelimiter([Name], ".")),
    {{"Period", type text}}),

  // Roll each county-quarter file down to one row: sum addresses, vacant addresses,
  // and "no-stat" (undeliverable-as-addressed, not confirmed vacant) addresses.
  #"Grouped rows" = Table.Group(#"Added custom 1", {"Period", "County FIPS"}, {
    {"Sum of ams_res", each List.Sum([ams_res]), type nullable number},
    {"Sum of res_vac", each List.Sum([res_vac]), type nullable number},
    {"Sum of nostat_res", each List.Sum([nostat_res]), type nullable number}
  }),

  // Narrow rate = confirmed-vacant addresses only. Broad rate additionally counts
  // "no-stat" addresses as vacant — the two are intentionally different definitions,
  // not two measurements of the same thing (see docs/methodology.md).
  #"Added custom 2" = Table.TransformColumnTypes(
    Table.AddColumn(#"Grouped rows", "USPS Narrow Rate", each [Sum of res_vac] / [Sum of ams_res]),
    {{"USPS Narrow Rate", type number}}),
  #"Added custom 3" = Table.TransformColumnTypes(
    Table.AddColumn(#"Added custom 2", "USPS Broad Rate", each ([Sum of res_vac] + [Sum of nostat_res]) / [Sum of ams_res]),
    {{"USPS Broad Rate", type number}}),

  // Year = last 4 characters of "Period" (e.g. "Q4 2019" -> "2019").
  #"Added custom 4" = Table.TransformColumnTypes(
    Table.AddColumn(#"Added custom 3", "Year", each Number.FromText(Text.End([Period], 4))),
    {{"Year", Int64.Type}})
in
  #"Added custom 4";
