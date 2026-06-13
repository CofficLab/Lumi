import EditorService

enum EditorDockerfilePluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "dockerfile",
        displayName: "Dockerfile",
        fileExtensions: ["Dockerfile"],
        lineComment: "//",
        highlightLanguageId: "dockerfile"
    )
}
