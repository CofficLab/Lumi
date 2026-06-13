import EditorLanguageRuntime

extension String {
    fileprivate static let tagFilterGrammarIds: Set<String> = [
        "html",
        "javascript",
        "typescript",
        "jsx",
        "tsx",
    ]

    func shouldProcessTags() -> Bool {
        Self.tagFilterGrammarIds.contains(self)
    }
}
