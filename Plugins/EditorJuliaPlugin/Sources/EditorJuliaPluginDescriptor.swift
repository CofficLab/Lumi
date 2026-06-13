import EditorService

enum EditorJuliaPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "julia",
        displayName: "Julia",
        fileExtensions: ["jl"],
        lineComment: "//",
        highlightLanguageId: "julia"
    )
}
