import Foundation
import LanguageServerProtocol

/// Pure LSP action policies shared by host apps.
public enum EditorLSPActionPolicy {
    public enum StatusMessageKey {
        case findingDefinition
        case findingDeclaration
        case findingTypeDefinition
        case findingImplementation
    }

    public static func languageID(forFileExtension ext: String) -> String? {
        let mapping: [String: String] = [
            "swift": "swift",
            "py": "python",
            "js": "javascript",
            "ts": "typescript",
            "jsx": "javascript",
            "tsx": "typescript",
            "astro": "typescript",
            "vue": "typescript",
            "svelte": "typescript",
            "rs": "rust",
            "go": "go",
            "c": "c",
            "cpp": "cpp",
            "h": "c",
            "hpp": "cpp",
            "m": "objective-c",
            "mm": "objective-cpp",
            "rb": "ruby",
            "java": "java",
            "kt": "kotlin",
            "php": "php",
            "sh": "bash",
            "json": "json",
            "yaml": "yaml",
            "yml": "yaml",
            "xml": "xml",
            "html": "html",
            "css": "css",
            "scss": "scss",
            "sass": "sass",
            "less": "less",
            "md": "markdown",
            "sql": "sql"
        ]
        return mapping[ext.lowercased()]
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
