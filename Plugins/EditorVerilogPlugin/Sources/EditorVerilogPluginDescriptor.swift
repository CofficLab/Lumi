import EditorService

enum EditorVerilogPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "verilog",
        displayName: "Verilog",
        fileExtensions: ["v", "vh", "sv"],
        lineComment: "//",
        highlightLanguageId: "verilog"
    )
}
