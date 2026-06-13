import EditorService

enum EditorHaskellPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "haskell",
        displayName: "Haskell",
        fileExtensions: ["hs", "lhs"],
        lineComment: "//",
        highlightLanguageId: "haskell"
    )
}
