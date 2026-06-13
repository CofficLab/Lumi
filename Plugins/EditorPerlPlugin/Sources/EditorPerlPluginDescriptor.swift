import EditorService

enum EditorPerlPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "perl",
        displayName: "Perl",
        fileExtensions: ["pl", "pm"],
        lineComment: "//",
        highlightLanguageId: "perl"
    )
}
