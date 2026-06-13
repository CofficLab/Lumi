import EditorService

enum EditorCSSPluginDescriptor {
    static let css = EditorLanguageDescriptor(
        languageId: "css",
        displayName: "CSS",
        fileExtensions: ["css"],
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "css",
        lspLanguageId: "css"
    )

    static let scss = EditorLanguageDescriptor(
        languageId: "scss",
        displayName: "SCSS",
        fileExtensions: ["scss"],
        lineComment: "//",
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "css",
        lspLanguageId: "scss"
    )

    static let sass = EditorLanguageDescriptor(
        languageId: "sass",
        displayName: "Sass",
        fileExtensions: ["sass"],
        lineComment: "//",
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "css",
        lspLanguageId: "sass"
    )

    static let less = EditorLanguageDescriptor(
        languageId: "less",
        displayName: "Less",
        fileExtensions: ["less"],
        lineComment: "//",
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "css",
        lspLanguageId: "less"
    )
}
