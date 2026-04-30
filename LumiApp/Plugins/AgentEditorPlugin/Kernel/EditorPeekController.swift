import Foundation
import CodeEditSourceEditor
import LanguageServerProtocol

@MainActor
enum EditorPeekMode: Equatable {
    case definition
    case references

    var title: String {
        switch self {
        case .definition:
            return "Peek Definition"
        case .references:
            return "Peek References"
        }
    }
}

struct EditorPeekItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let preview: String
    let badgeText: String
    let navigationRequest: EditorNavigationRequest
}

struct EditorPeekPresentation: Equatable {
    let mode: EditorPeekMode
    let summary: String
    let items: [EditorPeekItem]
}

@MainActor
struct EditorPeekController {
    func buildDefinitionPresentation(
        location: Location,
        currentFileURL: URL?,
        projectRootPath: String?,
        currentContent: String?
    ) -> EditorPeekPresentation? {
        guard let item = makeItem(
            from: location,
            currentFileURL: currentFileURL,
            projectRootPath: projectRootPath,
            currentContent: currentContent,
            badgeText: "Definition",
            highlightLine: true
        ) else {
            return nil
        }

        return EditorPeekPresentation(
            mode: .definition,
            summary: item.subtitle,
            items: [item]
        )
    }

    func buildReferencesPresentation(
        locations: [Location],
        currentFileURL: URL?,
        relativeFilePath: String,
        projectRootPath: String?,
        currentContent: String?
    ) -> EditorPeekPresentation {
        let items = locations.compactMap {
            makeItem(
                from: $0,
                currentFileURL: currentFileURL,
                projectRootPath: projectRootPath,
                currentContent: currentContent,
                badgeText: "Reference",
                highlightLine: false
            )
        }

        let summary: String
        if items.isEmpty {
            summary = relativeFilePath
        } else {
            summary = "\(items.count) results"
        }

        return EditorPeekPresentation(
            mode: .references,
            summary: summary,
            items: items
        )
    }

    private func makeItem(
        from location: Location,
        currentFileURL: URL?,
        projectRootPath: String?,
        currentContent: String?,
        badgeText: String,
        highlightLine: Bool
    ) -> EditorPeekItem? {
        guard let url = URL(string: location.uri), url.isFileURL else { return nil }
        let line = Int(location.range.start.line) + 1
        let column = Int(location.range.start.character) + 1
        let previewContent = previewText(
            for: url,
            line: line,
            currentFileURL: currentFileURL,
            currentContent: currentContent
        )
        let target = CursorPosition(
            start: .init(line: line, column: column),
            end: nil
        )
        let subtitle = displayPath(for: url, projectRootPath: projectRootPath) + ":\(line):\(column)"

        return EditorPeekItem(
            id: "\(url.standardizedFileURL.path):\(line):\(column):\(badgeText)",
            title: url.lastPathComponent,
            subtitle: subtitle,
            preview: previewContent,
            badgeText: badgeText,
            navigationRequest: .definition(url, target, highlightLine: highlightLine)
        )
    }

    private func previewText(
        for url: URL,
        line: Int,
        currentFileURL: URL?,
        currentContent: String?
    ) -> String {
        let content: String?
        if currentFileURL?.standardizedFileURL == url.standardizedFileURL {
            content = currentContent
        } else {
            content = try? String(contentsOf: url, encoding: .utf8)
        }

        guard let content else { return "Preview unavailable" }
        let lines = content.components(separatedBy: .newlines)
        let clampedIndex = min(max(line - 1, 0), max(lines.count - 1, 0))
        let rawLine = lines[safe: clampedIndex]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return rawLine.isEmpty ? "Blank line" : rawLine
    }

    private func displayPath(for url: URL, projectRootPath: String?) -> String {
        guard let projectRootPath, !projectRootPath.isEmpty else { return url.lastPathComponent }
        let fullPath = url.standardizedFileURL.path
        if fullPath.hasPrefix(projectRootPath + "/") {
            return String(fullPath.dropFirst(projectRootPath.count + 1))
        }
        return url.lastPathComponent
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
