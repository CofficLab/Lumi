import Foundation
import CodeEditSourceEditor

@MainActor
final class XcodeProjectQuickOpenContributor: EditorQuickOpenContributor {
    let id = "builtin.xcode.quick-open"

    func provideQuickOpenItems(
        query: String,
        state: EditorState
    ) async -> [EditorQuickOpenItemSuggestion] {
        guard let projectRootPath = state.projectRootPath, !projectRootPath.isEmpty else { return [] }
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return [] }

        return collectSuggestions(
            query: normalizedQuery,
            projectRootPath: projectRootPath,
            state: state
        )
    }

    private func collectSuggestions(
        query normalizedQuery: String,
        projectRootPath: String,
        state: EditorState
    ) -> [EditorQuickOpenItemSuggestion] {
        let projectRootURL = URL(fileURLWithPath: projectRootPath)
        guard let enumerator = FileManager.default.enumerator(
            at: projectRootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var suggestions: [EditorQuickOpenItemSuggestion] = []
        for case let fileURL as URL in enumerator {
            guard suggestions.count < 24 else { break }
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "xcconfig" || ext == "plist" || ext == "entitlements" else { continue }
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let matches: [(key: String, line: Int)] = if ext == "xcconfig" {
                XCConfigSyntax.keyOccurrences(in: content)
                    .filter { $0.key.lowercased().contains(normalizedQuery) }
                    .map { ($0.key, $0.line) }
            } else {
                PlistEditing.keyOccurrences(in: content)
                    .filter { $0.key.lowercased().contains(normalizedQuery) }
                    .map { ($0.key, $0.line) }
            }

            for (index, match) in matches.prefix(max(0, 24 - suggestions.count)).enumerated() {
                let relativePath = fileURL.path.hasPrefix(projectRootPath + "/")
                    ? String(fileURL.path.dropFirst(projectRootPath.count + 1))
                    : fileURL.lastPathComponent
                let target = CursorPosition(start: .init(line: match.line, column: 1), end: nil)
                suggestions.append(
                    EditorQuickOpenItemSuggestion(
                        id: "xcode-key:\(fileURL.path):\(match.line):\(match.key)",
                        sectionTitle: "Project Keys",
                        title: match.key,
                        subtitle: "\(relativePath):\(match.line)",
                        systemImage: ext == "xcconfig" ? "slider.horizontal.3" : "list.bullet.rectangle",
                        badge: ext == "xcconfig" ? "xcconfig" : fileURL.pathExtension.lowercased(),
                        order: suggestions.count + index,
                        isEnabled: true,
                        metadata: .init(
                            priority: ext == "xcconfig" ? 180 : 170,
                            dedupeKey: "\(fileURL.path):\(match.key):\(match.line)"
                        ),
                        action: {
                            state.performNavigation(.definition(fileURL, target, highlightLine: true))
                        }
                    )
                )
            }
        }

        return suggestions
    }
}
