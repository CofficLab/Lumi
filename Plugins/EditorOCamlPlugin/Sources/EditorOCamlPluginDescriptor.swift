import EditorService

enum EditorOCamlPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "ocaml",
        displayName: "OCaml",
        fileExtensions: ["ml"],
        lineComment: "//",
        highlightLanguageId: "ocaml"
    )
}
