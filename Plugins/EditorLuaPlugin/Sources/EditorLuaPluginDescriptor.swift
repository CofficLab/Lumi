import EditorService

enum EditorLuaPluginDescriptor {
    static let descriptor = EditorLanguageDescriptor(
        languageId: "lua",
        displayName: "Lua",
        fileExtensions: ["lua"],
        lineComment: "//",
        highlightLanguageId: "lua"
    )
}
