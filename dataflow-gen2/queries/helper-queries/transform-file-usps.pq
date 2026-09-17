// Helper query group: "Transform file from USPS Vacancy Rates" (Fabric's own name
// for this group — visible in the Queries pane of Dataflow Gen2/Power Query).
//
// Combine Files generates this trio automatically the first time you point it at a
// folder of files: it picks one real file as an "Example file," builds a reusable
// parsing function out of it, and wires "USPS Data" (01-usps-data.pq) to call that
// function once per file. Nothing here was hand-typed; it's default Combine Files
// output, included for completeness / so the group makes sense on its own.

// "Sample file" — literally reads the first real, non-hidden .csv found and returns
// its raw binary content. This is the "Example file" the two queries below were built from.
shared #"Sample file" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "<WORKSPACE_ID>"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "<LAKEHOUSE_ID>"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Files", ItemKind = "Folder"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Name = "USPS Vacancy Rates"]}[Content],
  #"Expanded Content" = Table.ExpandTableColumn(#"Navigation 3", "Content",
    {"Content", "Name", "Extension", "Date accessed", "Date modified", "Date created", "Attributes", "Folder Path"},
    {"Content.1", "Name.1", "Extension.1", "Date accessed.1", "Date modified.1", "Date created.1", "Attributes.1", "Folder Path.1"}),
  #"Removed other columns" = Table.SelectColumns(#"Expanded Content",
    {"Content.1", "Name.1", "Extension.1", "Date accessed.1", "Date modified.1", "Date created.1", "Attributes.1", "Folder Path.1"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed other columns",
    {{"Content.1", "Content"}, {"Name.1", "Name"}, {"Extension.1", "Extension"}, {"Date accessed.1", "Date accessed"},
     {"Date modified.1", "Date modified"}, {"Date created.1", "Date created"}, {"Attributes.1", "Attributes"}, {"Folder Path.1", "Folder Path"}}),
  #"Filtered rows" = Table.SelectRows(#"Renamed columns", each [Extension] = ".csv"),
  #"Filtered hidden files" = Table.SelectRows(#"Filtered rows", each [Attributes]?[Hidden]? <> true),
  #"Navigation 4" = #"Filtered hidden files"{0}[Content]
in
  #"Navigation 4";

// "Parameter" — wraps the sample file's binary as a query parameter, so Power Query's
// UI can offer "Edit" on the parsing logic without re-reading from the Lakehouse.
shared Parameter = let
  Parameter = #"Sample file" meta [IsParameterQuery = true, IsParameterQueryRequired = false, Type = type binary, BinaryIdentifier = #"Sample file"]
in
  Parameter;

// "Transform file" — the actual per-file parsing logic: parse as CSV (comma-delimited,
// UTF-8, 61 columns, no quoting) and promote the first row to headers. This function is
// invoked once per USPS file back in 01-usps-data.pq.
[FunctionQueryBinding = "{""exemplarFormulaName"":""Transform Sample file""}"]
shared #"Transform file" = (Parameter as binary) => let
  Source = Csv.Document(Parameter, [Delimiter = ",", Columns = 61, Encoding = 65001, QuoteStyle = QuoteStyle.None]),
  #"Promoted headers" = Table.PromoteHeaders(Source, [PromoteAllScalars = true])
in
  #"Promoted headers";

// "Transform Sample file" — the same logic applied specifically to the sample file,
// which is what the Power Query editor's preview pane actually displays while you work.
shared #"Transform Sample file" = let
  Source = Csv.Document(Parameter, [Delimiter = ",", Columns = 61, Encoding = 65001, QuoteStyle = QuoteStyle.None]),
  #"Promoted headers" = Table.PromoteHeaders(Source, [PromoteAllScalars = true])
in
  #"Promoted headers";
