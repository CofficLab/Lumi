import Foundation
import LanguageServerProtocol

@MainActor
public enum EditorPeekMode: Equatable {
    case definition
    case references

    public var title: String {
        switch self {
        case .definition:
            return "Peek Definition"
        case .references:
            return "Peek References"
        }
    }
}

public struct EditorPeekTarget: Equatable, Sendable {
    public let url: URL
    public let line: Int
    public let column: Int
    public let highlightLine: Bool

    public init(url: URL, line: Int, column: Int, highlightLine: Bool) {
        self.url = url
        self.line = line
        self.column = column
        self.highlightLine = highlightLine
    }
}

public struct EditorPeekItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let preview: String
    public let badgeText: String
    public let target: EditorPeekTarget

    public init(
        id: String,
        title: String,
        subtitle: String,
        preview: String,
        badgeText: String,
        target: EditorPeekTarget
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.preview = preview
        self.badgeText = badgeText
        self.target = target
    }
}

public struct EditorPeekPresentation: Equatable {
    public let mode: EditorPeekMode
    public let summary: String
    public let items: [EditorPeekItem]

    public init(mode: EditorPeekMode, summary: String, items: [EditorPeekItem]) {
        self.mode = mode
        self.summary = summary
        self.items = items
    }
}

@MainActor
public struct EditorPeekController {
    public init() {}

    public func buildDefinitionPresentation(
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

    public func buildReferencesPresentation(
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
        let subtitle = displayPath(for: url, projectRootPath: projectRootPath) + ":\(line):\(column)"
        let target = EditorPeekTarget(
            url: url,
            line: line,
            column: column,
            highlightLine: highlightLine
        )

        return EditorPeekItem(
            id: "\(url.standardizedFileURL.path):\(line):\(column):\(badgeText)",
            title: url.lastPathComponent,
            subtitle: subtitle,
            preview: previewContent,
            badgeText: badgeText,
            target: target
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
        EditorQuickOpenFilePolicy.relativePath(for: url, projectRootPath: projectRootPath)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
