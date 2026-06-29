import Foundation
import EditorSource
import LanguageServerProtocol

@MainActor
struct EditorQuickOpenFileContext: Equatable {
    let projectRootPath: String?
    let currentFileURL: URL?
}

@MainActor
struct EditorQuickOpenController {
    /// 文件搜索闭包。默认返回空数组（内核不提供默认实现）。
    /// 插件可通过注入实现来提供搜索能力。
    private let fileSearch: @MainActor (String, String, Int) -> [FileResult]

    init(
        fileSearch: @MainActor @escaping (String, String, Int) -> [FileResult] = { _, _, _ in [] }
    ) {
        self.fileSearch = fileSearch
    }

    func parse(_ rawQuery: String) -> EditorQuickOpenQuery {
        EditorQuickOpenQueryParser.parse(rawQuery)
    }

    func fileSuggestions(
        for query: EditorQuickOpenQuery,
        context: EditorQuickOpenFileContext,
        openEditors: [EditorOpenEditorItem],
        onOpenFile: @escaping (URL, CursorPosition?, Bool) -> Void
    ) -> [EditorQuickOpenItemSuggestion] {
        let normalizedSearch = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let recentOpenEditors = openEditors
            .filter { $0.fileURL != nil }
            .sorted(by: sortRecentEditors)

        var candidatesByPath: [String: EditorQuickOpenFileCandidate] = [:]

        for (index, item) in recentOpenEditors.enumerated() {
            guard let fileURL = item.fileURL else { continue }
            let relativePath = relativePath(for: fileURL, projectRootPath: context.projectRootPath)
            guard normalizedSearch.isEmpty || matchesFileQuery(normalizedSearch, title: item.title, relativePath: relativePath) else {
                continue
            }
            mergeFileCandidate(
                EditorQuickOpenFileCandidate(
                    fileURL: fileURL,
                    title: item.title,
                    subtitle: relativePath,
                    parentLabel: parentLabel(for: relativePath),
                    score: 240 - index * 10 + (item.isActive ? 20 : 0) + (item.isPinned ? 10 : 0)
                        + engineeringFilePriorityBonus(for: fileURL),
                    recentRank: item.recentActivationRank ?? .max
                ),
                into: &candidatesByPath
            )
        }

        if let projectPath = resolvedProjectPath(context: context), !normalizedSearch.isEmpty {
            let fileResults = fileSearch(normalizedSearch, projectPath, 40)
            for (index, result) in fileResults.enumerated() where !result.isDirectory {
                mergeFileCandidate(
                EditorQuickOpenFileCandidate(
                        fileURL: result.url,
                        title: result.name,
                        subtitle: result.relativePath,
                        parentLabel: parentLabel(for: result.relativePath),
                        score: max(result.score, 1) * 2 - index
                            + engineeringFilePriorityBonus(for: result.url),
                        recentRank: candidatesByPath[result.url.standardizedFileURL.path]?.recentRank ?? .max
                    ),
                    into: &candidatesByPath
                )
            }
        }

        let duplicateTitles = EditorQuickOpenFilePolicy.duplicateTitles(in: candidatesByPath.values)
        let ordered = EditorQuickOpenFilePolicy.orderedCandidates(candidatesByPath.values)

        let sectionTitle = normalizedSearch.isEmpty ? "Recent Files" : "Files"
        return ordered.prefix(normalizedSearch.isEmpty ? 12 : 24).enumerated().map { index, candidate in
            let badge = duplicateTitles.contains(candidate.title) ? candidate.parentLabel : nil
            return EditorQuickOpenItemSuggestion(
                id: "file:\(candidate.fileURL.standardizedFileURL.path)",
                sectionTitle: sectionTitle,
                title: candidate.title,
                subtitle: candidate.subtitle,
                systemImage: systemImage(for: candidate.fileURL),
                badge: badge,
                order: index,
                isEnabled: true,
                metadata: .init(priority: candidate.score, dedupeKey: candidate.fileURL.standardizedFileURL.path),
                action: {
                    onOpenFile(candidate.fileURL, nil, false)
                }
            )
        }
    }

    func documentSymbolSuggestions(
        for query: EditorQuickOpenQuery,
        symbols: [EditorDocumentSymbolItem],
        onOpenSymbol: @escaping (EditorDocumentSymbolItem) -> Void
    ) -> [EditorQuickOpenItemSuggestion] {
        let normalizedSymbols = flattenNormalized(symbols: symbols)
        let normalizedSearch = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredSymbols = normalizedSymbols.filter { item in
            guard !normalizedSearch.isEmpty else { return true }
            return item.normalizedName.contains(normalizedSearch)
                || item.normalizedId.contains(normalizedSearch)
                || (item.normalizedDetail?.contains(normalizedSearch) ?? false)
        }

        return filteredSymbols.prefix(24).enumerated().map { index, item in
            EditorQuickOpenItemSuggestion(
                id: "document-symbol:\(item.original.id)",
                sectionTitle: "Document Symbols",
                title: item.original.name,
                subtitle: "L\(item.original.line)" + (item.original.detail.map { " · \($0)" } ?? ""),
                systemImage: item.original.iconSymbol,
                badge: item.original.kind.shortDisplayName,
                order: index,
                isEnabled: true,
                metadata: .init(priority: 120 - index, dedupeKey: item.original.id),
                action: {
                    onOpenSymbol(item.original)
                }
            )
        }
    }

    func lineSuggestions(
        for query: EditorQuickOpenQuery,
        currentFileURL: URL?,
        fileName: String,
        relativeFilePath: String,
        onOpenFile: @escaping (URL, CursorPosition?, Bool) -> Void
    ) -> [EditorQuickOpenItemSuggestion] {
        guard let currentFileURL, let line = query.line, line > 0 else { return [] }
        let column = max(query.column ?? 1, 1)
        return [
            EditorQuickOpenItemSuggestion(
                id: "line:\(currentFileURL.standardizedFileURL.path):\(line):\(column)",
                sectionTitle: "Go to Line",
                title: "Line \(line), Column \(column)",
                subtitle: fileName.isEmpty ? relativeFilePath : fileName,
                systemImage: "text.line.first.and.arrowtriangle.forward",
                badge: relativeFilePath.isEmpty ? nil : relativeFilePath,
                order: 0,
                isEnabled: true,
                metadata: .init(priority: 200, dedupeKey: "\(currentFileURL.standardizedFileURL.path):\(line):\(column)"),
                action: {
                    onOpenFile(
                        currentFileURL,
                        CursorPosition(
                            start: .init(line: line, column: column),
                            end: nil
                        ),
                        true
                    )
                }
            )
        ]
    }

    private func flattenNormalized(symbols: [EditorDocumentSymbolItem]) -> [NormalizedEditorDocumentSymbolItem] {
        symbols.flatMap { symbol -> [NormalizedEditorDocumentSymbolItem] in
            let normalized = NormalizedEditorDocumentSymbolItem(original: symbol)
            return [normalized] + flattenNormalized(symbols: symbol.children)
        }
    }

    private func resolvedProjectPath(context: EditorQuickOpenFileContext) -> String? {
        if let projectRootPath = context.projectRootPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !projectRootPath.isEmpty {
            return projectRootPath
        }
        return context.currentFileURL?.deletingLastPathComponent().path
    }

    private func relativePath(for fileURL: URL, projectRootPath: String?) -> String {
        EditorQuickOpenFilePolicy.relativePath(for: fileURL, projectRootPath: projectRootPath)
    }

    private func parentLabel(for relativePath: String) -> String? {
        EditorQuickOpenFilePolicy.parentLabel(for: relativePath)
    }

    private func matchesFileQuery(_ query: String, title: String, relativePath: String) -> Bool {
        EditorQuickOpenFilePolicy.matchesFileQuery(query, title: title, relativePath: relativePath)
    }

    /// 模糊匹配算法：检查 text 是否按顺序包含 query 的所有字符
    private static func fuzzyMatch(_ text: String, query: String) -> Bool {
        EditorQuickOpenFilePolicy.fuzzyMatch(text, query: query)
    }

    private func sortRecentEditors(_ lhs: EditorOpenEditorItem, _ rhs: EditorOpenEditorItem) -> Bool {
        if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
        if lhs.recentActivationRank != rhs.recentActivationRank {
            return (lhs.recentActivationRank ?? .max) < (rhs.recentActivationRank ?? .max)
        }
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func mergeFileCandidate(
        _ candidate: EditorQuickOpenFileCandidate,
        into candidatesByPath: inout [String: EditorQuickOpenFileCandidate]
    ) {
        EditorQuickOpenFilePolicy.mergeCandidate(candidate, into: &candidatesByPath)
    }

    private func engineeringFilePriorityBonus(for fileURL: URL) -> Int {
        EditorQuickOpenFilePolicy.engineeringFilePriorityBonus(for: fileURL)
    }

    private func systemImage(for fileURL: URL) -> String {
        EditorQuickOpenFilePolicy.systemImage(for: fileURL)
    }
}

private extension SymbolKind {
    var shortDisplayName: String {
        switch self {
        case .class: return "Class"
        case .struct: return "Struct"
        case .interface: return "Interface"
        case .enum: return "Enum"
        case .enumMember: return "Member"
        case .function: return "Function"
        case .method: return "Method"
        case .property: return "Property"
        case .field: return "Field"
        case .variable: return "Variable"
        case .constant: return "Constant"
        case .namespace: return "Namespace"
        case .module: return "Module"
        case .constructor: return "Init"
        default: return "Symbol"
        }
    }
}

/// 预归一化的符号项，避免每次按键重复调用 lowercased()
private struct NormalizedEditorDocumentSymbolItem {
    let original: EditorDocumentSymbolItem
    let normalizedName: String
    let normalizedId: String
    let normalizedDetail: String?

    init(original: EditorDocumentSymbolItem) {
        self.original = original
        self.normalizedName = original.name.lowercased()
        self.normalizedId = original.id.lowercased()
        self.normalizedDetail = original.detail?.lowercased()
    }
}
