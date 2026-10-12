import Foundation

public struct EditorQuickOpenFileCandidate: Equatable {
    public let fileURL: URL
    public let title: String
    public let subtitle: String
    public let parentLabel: String?
    public let score: Int
    public let recentRank: Int

    public init(
        fileURL: URL,
        title: String,
        subtitle: String,
        parentLabel: String?,
        score: Int,
        recentRank: Int
    ) {
        self.fileURL = fileURL
        self.title = title
        self.subtitle = subtitle
        self.parentLabel = parentLabel
        self.score = score
        self.recentRank = recentRank
    }

    public func merging(_ other: EditorQuickOpenFileCandidate) -> EditorQuickOpenFileCandidate {
        EditorQuickOpenFileCandidate(
            fileURL: fileURL,
            title: title,
            subtitle: subtitle.count >= other.subtitle.count ? subtitle : other.subtitle,
            parentLabel: parentLabel ?? other.parentLabel,
            score: max(score, other.score),
            recentRank: min(recentRank, other.recentRank)
        )
    }
}

public enum EditorQuickOpenFilePolicy {
    public static func relativePath(for fileURL: URL, projectRootPath: String?) -> String {
        let filePath = normalizedPath(fileURL.path)
        guard let projectRootPath else { return fileURL.lastPathComponent }

        let rootPath = normalizedPath(projectRootPath)
        guard !rootPath.isEmpty else { return fileURL.lastPathComponent }

        if filePath == rootPath {
            return fileURL.lastPathComponent
        }

        let rootPrefix = rootPath == "/" ? "/" : rootPath + "/"
        if filePath.hasPrefix(rootPrefix) {
            return String(filePath.dropFirst(rootPrefix.count))
        }
        return fileURL.lastPathComponent
    }

    private static func normalizedPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let normalized = URL(fileURLWithPath: trimmed).standardizedFileURL.path
        return normalized != "/" && normalized.hasSuffix("/") ? String(normalized.dropLast()) : normalized
    }

    public static func parentLabel(for relativePath: String) -> String? {
        let parentPath = (relativePath as NSString).deletingLastPathComponent
        guard !parentPath.isEmpty, parentPath != "." else { return nil }
        return URL(fileURLWithPath: parentPath).lastPathComponent
    }

    public static func matchesFileQuery(_ query: String, title: String, relativePath: String) -> Bool {
        let lowercasedTitle = title.lowercased()
        let lowercasedPath = relativePath.lowercased()
        return lowercasedTitle.contains(query)
            || lowercasedPath.contains(query)
            || fuzzyMatch(lowercasedTitle, query: query)
            || fuzzyMatch(lowercasedPath, query: query)
    }

    public static func fuzzyMatch(_ text: String, query: String) -> Bool {
        guard !query.isEmpty else { return true }

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

    public static func engineeringFilePriorityBonus(for fileURL: URL) -> Int {
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

    public static func systemImage(for fileURL: URL) -> String {
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

    public static func duplicateTitles(in candidates: some Sequence<EditorQuickOpenFileCandidate>) -> Set<String> {
        Dictionary(grouping: Array(candidates), by: \.title)
            .filter { $0.value.count > 1 }
            .reduce(into: Set<String>()) { result, entry in
                result.insert(entry.key)
            }
    }

    public static func orderedCandidates(_ candidates: some Sequence<EditorQuickOpenFileCandidate>) -> [EditorQuickOpenFileCandidate] {
        Array(candidates).sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.recentRank != rhs.recentRank { return lhs.recentRank < rhs.recentRank }
            if lhs.title != rhs.title {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.subtitle.localizedCaseInsensitiveCompare(rhs.subtitle) == .orderedAscending
        }
    }

    public static func mergeCandidate(
        _ candidate: EditorQuickOpenFileCandidate,
        into candidatesByPath: inout [String: EditorQuickOpenFileCandidate]
    ) {
        let key = candidate.fileURL.standardizedFileURL.path
        if let existing = candidatesByPath[key] {
            candidatesByPath[key] = existing.merging(candidate)
        } else {
            candidatesByPath[key] = candidate
        }
    }
}
