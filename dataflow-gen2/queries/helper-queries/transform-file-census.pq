// Helper query group: "Transform file from Census" (Fabric's own name for this
// group). Same role as transform-file-usps.pq, generated the same way by Combine
// Files, for the Census annual-extract CSVs instead of the USPS quarterly ones.

// "Sample file (2)" — the first real, non-hidden Census .csv found.
shared #"Sample file (2)" = let
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
  #"Navigation 4" = #"Filtered hidden files"{0}[Content]
in
  #"Navigation 4";

// "Parameter (2)" — the sample file's binary, exposed as an editable parameter.
shared #"Parameter (2)" = let
  #"Parameter (2)" = #"Sample file (2)" meta [IsParameterQuery = true, IsParameterQueryRequired = false, Type = type binary, BinaryIdentifier = #"Sample file (2)"]
in
  #"Parameter (2)";

// "Transform file (2)" — per-file parsing logic for the Census extracts: CSV,
// comma-delimited, UTF-8, 8 columns (GEO_ID, NAME, plus 3 Estimate/Margin pairs),
// with headers promoted and types set immediately (Census's own column names are
// stable across years, so unlike the USPS files there's no casing fix needed here).
[FunctionQueryBinding = "{""exemplarFormulaName"":""Transform Sample file (2)""}"]
shared #"Transform file (2)" = (#"Parameter (2)" as binary) => let
  Source = Csv.Document(#"Parameter (2)", [Delimiter = ",", Columns = 8, Encoding = 65001]),
  #"Promoted headers" = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {
    {"GEO_ID", type text}, {"NAME", type text},
    {"B25002_001E", Int64.Type}, {"B25002_001M", type text},
    {"B25002_002E", Int64.Type}, {"B25002_002M", type text},
    {"B25002_003E", Int64.Type}, {"B25002_003M", type text}
  })
in
  #"Changed column type";

// "Transform Sample file (2)" — same logic, applied to the sample file for the
// editor's live preview pane.
shared #"Transform Sample file (2)" = let
  Source = Csv.Document(#"Parameter (2)", [Delimiter = ",", Columns = 8, Encoding = 65001]),
  #"Promoted headers" = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {
    {"GEO_ID", type text}, {"NAME", type text},
    {"B25002_001E", Int64.Type}, {"B25002_001M", type text},
    {"B25002_002E", Int64.Type}, {"B25002_002M", type text},
    {"B25002_003E", Int64.Type}, {"B25002_003M", type text}
  })
in
  #"Changed column type";
