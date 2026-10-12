import Foundation
import LanguageServerProtocol
import EditorLanguageRuntime

/// Pure LSP action policies shared by host apps.
public enum EditorLSPActionPolicy {
    public enum StatusMessageKey {
        case findingDefinition
        case findingDeclaration
        case findingTypeDefinition
        case findingImplementation
    }

    /// Built-in LSP language id mapping (file extension -> LSP language id).
    ///
    /// Used as a fallback when the global `LanguageRegistry` has not (yet)
    /// registered a given extension, keeping the policy self-contained and
    /// testable without external language plugins. Lookups are case-insensitive.
    private static let builtInLanguageIds: [String: String] = [
        "swift": "swift",
        "ts": "typescript",
        "tsx": "typescript",
        "js": "javascript",
        "jsx": "javascript",
        "mjs": "javascript",
        "cjs": "javascript",
        "py": "python",
        "rb": "ruby",
        "go": "go",
        "rs": "rust",
        "kt": "kotlin",
        "java": "java",
        "c": "c",
        "cpp": "cpp",
        "cc": "cpp",
        "h": "c",
        "hpp": "cpp",
        "m": "objectivec",
        "mm": "objectivecpp",
        "cs": "csharp",
        "php": "php",
        "html": "html",
        "htm": "html",
        "css": "css",
        "scss": "scss",
        "less": "less",
        "json": "json",
        "yaml": "yaml",
        "yml": "yaml",
        "toml": "toml",
        "md": "markdown",
        "sh": "shellscript",
        "bash": "shellscript",
        "zsh": "shellscript",
        "sql": "sql",
        "xml": "xml",
        "lua": "lua",
        "dart": "dart",
        "scala": "scala",
        "pl": "perl",
        "r": "r",
        "groovy": "groovy",
    ]

    @MainActor
    public static func languageID(forFileExtension ext: String) -> String? {
        if let id = LanguageRegistry.shared.lspLanguageId(forExtension: ext) {
            return id
        }
        return builtInLanguageIds[ext.lowercased()]
    }

    public static func statusMessageKey(for kind: EditorLSPActionJumpKind) -> StatusMessageKey {
        switch kind {
        case .definition:
            .findingDefinition
        case .declaration:
            .findingDeclaration
        case .typeDefinition:
            .findingTypeDefinition
        case .implementation:
            .findingImplementation
        }
    }

    public static func referenceResults(
        from locations: [Location],
        currentFileURL: URL,
        relativeFilePath: String,
        projectRootPath: String?,
        previewLine: (URL, Int) -> String?
    ) -> [ReferenceResult] {
        let items = locations.compactMap { location -> ReferenceResult? in
            guard let url = WorkspaceEditFileOperations.fileURL(from: location.uri) else { return nil }
            let line = Int(location.range.start.line) + 1
            let column = Int(location.range.start.character) + 1
            return ReferenceResult(
                url: url,
                line: line,
                column: column,
                path: displayPath(
                    for: url,
                    currentFileURL: currentFileURL,
                    relativeFilePath: relativeFilePath,
                    projectRootPath: projectRootPath
                ),
                preview: previewLine(url, line) ?? ""
            )
        }

        return items.sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.line != $1.line { return $0.line < $1.line }
            return $0.column < $1.column
        }
    }

    private static func displayPath(
        for url: URL,
        currentFileURL: URL,
        relativeFilePath: String,
        projectRootPath: String?
    ) -> String {
        if url == currentFileURL {
            return relativeFilePath
        }

        return EditorQuickOpenFilePolicy.relativePath(for: url, projectRootPath: projectRootPath)
    }
}
