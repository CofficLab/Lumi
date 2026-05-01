import Foundation
import CodeEditSourceEditor
import LanguageServerProtocol

@MainActor
enum EditorQuickOpenQueryScope: Equatable {
    case files
    case documentSymbols
    case workspaceSymbols
    case line
    case commands
}

@MainActor
struct EditorQuickOpenQuery: Equatable {
    let rawText: String
    let scope: EditorQuickOpenQueryScope
    let searchText: String
    let line: Int?
    let column: Int?
    let hasExplicitScope: Bool
}

@MainActor
struct EditorQuickOpenFileContext: Equatable {
    let projectRootPath: String?
    let currentFileURL: URL?
}

@MainActor
struct EditorQuickOpenController {
    /// 文件搜索闭包。默认返回空数组（内核不提供默认实现）。
    /// 插件可通过注入实现来提供搜索能力。
    private let fileSearch: @MainActor (_ query: String, _ projectPath: String, _ limit: Int) -> [FileResult]

    init(
        fileSearch: @escaping @MainActor (_ query: String, _ projectPath: String, _ limit: Int) -> [FileResult] = { _, _, _ in [] }
    ) {
        self.fileSearch = fileSearch
    }

    func parse(_ rawQuery: String) -> EditorQuickOpenQuery {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prefix = trimmed.first else {
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .files,
                searchText: "",
                line: nil,
                column: nil,
                hasExplicitScope: false
            )
        }

        let remainder = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        switch prefix {
        case "@":
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .documentSymbols,
                searchText: remainder,
                line: nil,
                column: nil,
                hasExplicitScope: true
            )
        case "#":
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .workspaceSymbols,
                searchText: remainder,
                line: nil,
                column: nil,
                hasExplicitScope: true
            )
        case ":":
            let parts = remainder.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let line = parts.first.flatMap { Int($0) }
            let column = parts.count > 1 ? Int(parts[1]) : nil
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .line,
                searchText: remainder,
                line: line,
                column: column,
                hasExplicitScope: true
            )
        case ">":
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .commands,
                searchText: remainder,
                line: nil,
                column: nil,
                hasExplicitScope: true
            )
        default:
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .files,
                searchText: trimmed,
                line: nil,
                column: nil,
                hasExplicitScope: false
            )
        }
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

        var candidatesByPath: [String: QuickOpenFileCandidate] = [:]

        for (index, item) in recentOpenEditors.enumerated() {
            guard let fileURL = item.fileURL else { continue }
            let relativePath = relativePath(for: fileURL, projectRootPath: context.projectRootPath)
            guard normalizedSearch.isEmpty || matchesFileQuery(normalizedSearch, title: item.title, relativePath: relativePath) else {
                continue
            }
            mergeFileCandidate(
                QuickOpenFileCandidate(
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
                    QuickOpenFileCandidate(
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

        let duplicateTitles = Dictionary(grouping: candidatesByPath.values, by: \.title)
            .filter { $0.value.count > 1 }
            .reduce(into: Set<String>()) { result, entry in
                result.insert(entry.key)
            }

        let ordered = candidatesByPath.values.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.recentRank != rhs.recentRank { return lhs.recentRank < rhs.recentRank }
            if lhs.title != rhs.title {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.subtitle.localizedCaseInsensitiveCompare(rhs.subtitle) == .orderedAscending
        }

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
        let flattenedSymbols = flatten(symbols: symbols)
        let normalizedSearch = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredSymbols = flattenedSymbols.filter { item in
            guard !normalizedSearch.isEmpty else { return true }
            return item.name.lowercased().contains(normalizedSearch)
                || item.id.lowercased().contains(normalizedSearch)
                || (item.detail?.lowercased().contains(normalizedSearch) ?? false)
        }

        return filteredSymbols.prefix(24).enumerated().map { index, item in
            EditorQuickOpenItemSuggestion(
                id: "document-symbol:\(item.id)",
                sectionTitle: "Document Symbols",
                title: item.name,
                subtitle: "L\(item.line)" + (item.detail.map { " · \($0)" } ?? ""),
                systemImage: item.iconSymbol,
                badge: item.kind.shortDisplayName,
                order: index,
                isEnabled: true,
                metadata: .init(priority: 120 - index, dedupeKey: item.id),
                action: {
                    onOpenSymbol(item)
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

    private func flatten(symbols: [EditorDocumentSymbolItem]) -> [EditorDocumentSymbolItem] {
        symbols.flatMap { symbol in
            [symbol] + flatten(symbols: symbol.children)
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
        if let projectRootPath, fileURL.path.hasPrefix(projectRootPath + "/") {
            return String(fileURL.path.dropFirst(projectRootPath.count + 1))
        }
        return fileURL.lastPathComponent
    }

    private func parentLabel(for relativePath: String) -> String? {
        let parentPath = (relativePath as NSString).deletingLastPathComponent
        guard !parentPath.isEmpty, parentPath != "." else { return nil }
        return URL(fileURLWithPath: parentPath).lastPathComponent
    }

    private func matchesFileQuery(_ query: String, title: String, relativePath: String) -> Bool {
        let lowercasedTitle = title.lowercased()
        let lowercasedPath = relativePath.lowercased()
        return lowercasedTitle.contains(query)
            || lowercasedPath.contains(query)
            || Self.fuzzyMatch(lowercasedTitle, query: query)
            || Self.fuzzyMatch(lowercasedPath, query: query)
    }

    /// 模糊匹配算法：检查 text 是否按顺序包含 query 的所有字符
    private static func fuzzyMatch(_ text: String, query: String) -> Bool {
        var queryIndex = query.startIndex
        for char in text {
            if char == query[queryIndex] {
                queryIndex = query.index(after: queryIndex)
                if queryIndex == query.endIndex {
                    return true
                }
            }
        }
        return false
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
        _ candidate: QuickOpenFileCandidate,
        into candidatesByPath: inout [String: QuickOpenFileCandidate]
    ) {
        let key = candidate.fileURL.standardizedFileURL.path
        if let existing = candidatesByPath[key] {
            candidatesByPath[key] = existing.merging(candidate)
        } else {
            candidatesByPath[key] = candidate
        }
    }

    private func engineeringFilePriorityBonus(for fileURL: URL) -> Int {
        switch fileURL.lastPathComponent.lowercased() {
        case "package.swift":
            return 20
        case "project.pbxproj":
            return 16
        default:
            break
        }

        switch fileURL.pathExtension.lowercased() {
        case "xcconfig":
            return 18
        case "plist":
            return 12
        case "entitlements":
            return 12
        case "pbxproj":
            return 16
        default:
            return 0
        }
    }

    private func systemImage(for fileURL: URL) -> String {
        switch fileURL.lastPathComponent.lowercased() {
        case "package.swift":
            return "shippingbox"
        case "project.pbxproj":
            return "hammer"
        default:
            break
        }

        switch fileURL.pathExtension.lowercased() {
        case "xcconfig":
            return "slider.horizontal.3"
        case "plist", "entitlements":
            return "list.bullet.rectangle"
        case "pbxproj":
            return "hammer"
        default:
            return "doc"
        }
    }
}

private struct QuickOpenFileCandidate {
    let fileURL: URL
    let title: String
    let subtitle: String
    let parentLabel: String?
    let score: Int
    let recentRank: Int

    func merging(_ other: QuickOpenFileCandidate) -> QuickOpenFileCandidate {
        QuickOpenFileCandidate(
            fileURL: fileURL,
            title: title,
            subtitle: subtitle.count >= other.subtitle.count ? subtitle : other.subtitle,
            parentLabel: parentLabel ?? other.parentLabel,
            score: max(score, other.score),
            recentRank: min(recentRank, other.recentRank)
        )
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
