import Foundation
import AppKit
import LanguageServerProtocol

@MainActor
final class EditorLSPActionController {
    enum JumpKind {
        case definition
        case declaration
        case typeDefinition
        case implementation

        var statusMessage: String {
            switch self {
            case .definition:
                return String(localized: "Finding definition...", table: "LumiEditor")
            case .declaration:
                return String(localized: "Finding declaration...", table: "LumiEditor")
            case .typeDefinition:
                return String(localized: "Finding type definition...", table: "LumiEditor")
            case .implementation:
                return String(localized: "Finding implementation...", table: "LumiEditor")
            }
        }
    }

    func languageID(for ext: String) -> String? {
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
            "sql": "sql",
        ]
        return mapping[ext.lowercased()]
    }

    func jumpKindStatusMessage(_ kind: JumpKind) -> String {
        kind.statusMessage
    }

    func referenceResults(
        from locations: [Location],
        currentFileURL: URL,
        relativeFilePath: String,
        projectRootPath: String?,
        previewLine: (URL, Int) -> String?
    ) -> [ReferenceResult] {
        let items = locations.compactMap { location -> ReferenceResult? in
            guard let url = URL(string: location.uri) else { return nil }
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

    func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK", table: "LumiEditor"))
        alert.runModal()
    }

    func previewLine(from url: URL, at lineNumber: Int) -> String? {
        guard lineNumber > 0 else { return nil }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: .newlines)
        guard lineNumber - 1 < lines.count else { return nil }
        return lines[lineNumber - 1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func displayPath(
        for url: URL,
        currentFileURL: URL,
        relativeFilePath: String,
        projectRootPath: String?
    ) -> String {
        if url == currentFileURL {
            return relativeFilePath
        }

        guard let projectRootPath else { return url.lastPathComponent }
        let absolutePath = url.path
        guard absolutePath.hasPrefix(projectRootPath) else { return url.lastPathComponent }
        var relative = String(absolutePath.dropFirst(projectRootPath.count))
        if relative.hasPrefix("/") {
            relative.removeFirst()
        }
        return relative
    }
}
