// Query: "Comparison"  — the final output of this dataflow.
// Exported from the real Dataflow Gen2 (see dataflow-gen2/README.md). Verbatim except
// for redacted workspace/lakehouse identifiers.
//
// Reads every annual Census vacancy CSV, computes the Census vacancy rate, then joins
// in "USPS Annual" by County FIPS + Year. This is the table the Power BI report and
// every DAX measure in /powerbi are built on top of (see /data/comparison_table.csv
// for the actual computed output, extracted from the semantic model this feeds).

shared Comparison = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "<WORKSPACE_ID>"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "<LAKEHOUSE_ID>"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Files", ItemKind = "Folder"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Name = "Census"]}[Content],

  #"Expanded Content" = Table.ExpandTableColumn(#"Navigation 3", "Content",
    {"Content", "Name", "Extension", "Date accessed", "Date modified", "Date created", "Attributes", "Folder Path"},
    {"Content.1", "Name.1", "Extension.1", "Date accessed.1", "Date modified.1", "Date created.1", "Attributes.1", "Folder Path.1"}),
  #"Removed other columns" = Table.SelectColumns(#"Expanded Content",
    {"Content.1", "Name.1", "Extension.1", "Date accessed.1", "Date modified.1", "Date created.1", "Attributes.1", "Folder Path.1"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed other columns",
    {{"Content.1", "Content"}, {"Name.1", "Name"}, {"Extension.1", "Extension"}, {"Date accessed.1", "Date accessed"},
     {"Date modified.1", "Date modified"}, {"Date created.1", "Date created"}, {"Attributes.1", "Attributes"}, {"Folder Path.1", "Folder Path"}}),
  #"Filtered hidden files" = Table.SelectRows(#"Renamed columns", each [Attributes]?[Hidden]? <> true),

  // Parse every Census annual CSV through the "Transform file (2)" helper
  // (see helper-queries/transform-file-census.pq).
  #"Invoke custom function" = Table.AddColumn(#"Filtered hidden files", "Transform file (2)", each #"Transform file (2)"([Content])),
  #"Removed other columns 1" = Table.SelectColumns(#"Invoke custom function", {"Transform file (2)", "Name"}),
  #"Expanded table column" = Table.ExpandTableColumn(#"Removed other columns 1", "Transform file (2)",
    Table.ColumnNames(#"Transform file (2)"(#"Sample file (2)"))),

  // GEO_ID looks like "0500000US42071" — the FIPS code is always the last 5 digits.
  #"Changed column type" = Table.TransformColumnTypes(#"Expanded table column", {
    {"GEO_ID", type text}, {"NAME", type text},
    {"B25002_001E", Int64.Type}, {"B25002_001M", type text},
    {"B25002_002E", Int64.Type}, {"B25002_002M", type text},
    {"B25002_003E", Int64.Type}, {"B25002_003M", type text}
  }),
  #"Added custom" = Table.TransformColumnTypes(
    Table.AddColumn(#"Changed column type", "County FIPS", each Text.End([GEO_ID], 5)),
    {{"County FIPS", type text}}),

  // Year comes from the filename (each year's Census extract is its own CSV,
  // e.g. "2019.csv"), not from any column inside the file itself.
  #"Added custom 1" = Table.AddColumn(#"Added custom", "Year", each Number.FromText(Text.BeforeDelimiter([Name], "."))),

  // NAME arrives as "Lancaster County, Pennsylvania" — split into County / State.
  #"Added custom 2" = Table.TransformColumnTypes(
    Table.AddColumn(#"Added custom 1", "County", each Text.BeforeDelimiter([NAME], ",")),
    {{"County", type text}}),
  #"Added custom 3" = Table.TransformColumnTypes(
    Table.AddColumn(#"Added custom 2", "State", each Text.Trim(Text.AfterDelimiter([NAME], ","))),
    {{"State", type text}}),

  // B25002 is the Census table for occupancy status: 001E = total housing units,
  // 002E = occupied, 003E = vacant. The "M" columns are margins of error — not used.
  #"Renamed columns 1" = Table.RenameColumns(#"Added custom 3",
    {{"B25002_001E", "Total Housing Units"}, {"B25002_002E", "Occupied"}, {"B25002_003E", "Vacant"}}),
  #"Removed columns" = Table.RemoveColumns(#"Renamed columns 1",
    {"GEO_ID", "NAME", "B25002_001M", "B25002_002M", "B25002_003M"}),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Removed columns", {{"Year", Int64.Type}}),

  #"Added custom 4" = Table.TransformColumnTypes(
    Table.AddColumn(#"Changed column type 1", "Census Vacancy Rate", each [Vacant] / [Total Housing Units]),
    {{"Census Vacancy Rate", type number}}),

  // The join: bring in the matching county-year's averaged USPS rates.
  // LeftOuter keeps every Census row even where USPS coverage is missing.
  #"Merged queries" = Table.NestedJoin(#"Added custom 4", {"County FIPS", "Year"}, #"USPS Annual", {"County FIPS", "Year"}, "USPS Annual", JoinKind.LeftOuter),
  #"Expanded USPS Annual" = Table.ExpandTableColumn(#"Merged queries", "USPS Annual",
    {"USPS Narrow Rate (avg)", "USPS Broad Rate (avg)", "Quarters Averaged"},
    {"USPS Narrow Rate (avg)", "USPS Broad Rate (avg)", "Quarters Averaged"})
in
  #"Expanded USPS Annual";
