import EditorService

enum EditorMarkdownPluginDescriptor {
    static let markdown = EditorLanguageDescriptor(
        languageId: "markdown",
        displayName: "Markdown",
        fileExtensions: ["md", "mkd", "mkdn", "mdwn", "mdown", "markdown"],
        lineComment: "[comment]: #",
        highlightLanguageId: "markdown",
        lspLanguageId: nil
    )

    static let markdownInline = EditorLanguageDescriptor(
        languageId: "markdown-inline",
        displayName: "Markdown Inline",
        fileExtensions: [],
        highlightLanguageId: "markdown-inline",
        lspLanguageId: nil
    )
}
