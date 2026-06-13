import EditorService

enum EditorJSPluginDescriptor {
    static let javascript = EditorLanguageDescriptor(
        languageId: "javascript",
        displayName: "JavaScript",
        fileExtensions: ["js", "cjs", "mjs"],
        shebangAliases: ["node", "deno"],
        lineComment: "//",
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "javascript",
        lspLanguageId: "javascript"
    )

    static let typescript = EditorLanguageDescriptor(
        languageId: "typescript",
        displayName: "TypeScript",
        fileExtensions: ["ts", "cts", "mts"],
        lineComment: "//",
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "typescript",
        lspLanguageId: "typescript",
        parentHighlightLanguageId: "javascript"
    )

    static let jsx = EditorLanguageDescriptor(
        languageId: "jsx",
        displayName: "JSX",
        fileExtensions: ["jsx"],
        lineComment: "//",
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "jsx",
        lspLanguageId: "javascript",
        parentHighlightLanguageId: "javascript"
    )

    static let tsx = EditorLanguageDescriptor(
        languageId: "tsx",
        displayName: "TSX",
        fileExtensions: ["tsx"],
        lineComment: "//",
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "tsx",
        lspLanguageId: "typescript",
        parentHighlightLanguageId: "jsx"
    )

    static let jsdoc = EditorLanguageDescriptor(
        languageId: "jsdoc",
        displayName: "JSDoc",
        fileExtensions: [],
        rangeCommentOpen: "/**",
        rangeCommentClose: "*/",
        highlightLanguageId: "jsdoc",
        lspLanguageId: nil
    )
}
