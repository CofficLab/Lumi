import EditorService

enum EditorHTMLPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "html",
        displayName: "HTML",
        fileExtensions: ["html", "htm", "shtml"],
        rangeCommentOpen: "<!--",
        rangeCommentClose: "-->",
        highlightLanguageId: "html",
        lspLanguageId: "html"
    )
}
