import EditorService

enum EditorScalaPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "scala",
        displayName: "Scala",
        fileExtensions: ["scala", "sbt"],
        lineComment: "//",
        highlightLanguageId: "scala"
    )
}
