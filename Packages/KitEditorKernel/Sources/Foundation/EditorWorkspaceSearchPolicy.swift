import Foundation

public struct EditorWorkspaceSearchMatch: Identifiable, Equatable, Sendable {
    public let url: URL
    public let line: Int
    public let column: Int
    public let path: String
    public let preview: String

    public var id: String {
        "\(path):\(line):\(column):\(preview)"
    }

    public init(url: URL, line: Int, column: Int, path: String, preview: String) {
        self.url = url
        self.line = line
        self.column = column
        self.path = path
        self.preview = preview
    }
}

public struct EditorWorkspaceSearchFileResult: Identifiable, Equatable, Sendable {
    public let url: URL
    public let path: String
    public let matches: [EditorWorkspaceSearchMatch]

    public var id: String { path }
    public var matchCount: Int { matches.count }

    public init(url: URL, path: String, matches: [EditorWorkspaceSearchMatch]) {
        self.url = url
        self.path = path
        self.matches = matches
    }
}

public struct EditorWorkspaceSearchSummary: Equatable, Sendable {
    public let query: String
    public let totalMatches: Int
    public let totalFiles: Int

    public init(query: String, totalMatches: Int, totalFiles: Int) {
        self.query = query
        self.totalMatches = totalMatches
        self.totalFiles = totalFiles
    }
}

public struct EditorWorkspaceSearchResponse: Equatable, Sendable {
    public let summary: EditorWorkspaceSearchSummary
    public let fileResults: [EditorWorkspaceSearchFileResult]

    public init(summary: EditorWorkspaceSearchSummary, fileResults: [EditorWorkspaceSearchFileResult]) {
        self.summary = summary
        self.fileResults = fileResults
    }
}

/// 工作区搜索的解析策略。
///
/// - Important: 不再是 `@MainActor`。
///   ripgrep 的输出可能有成千上万行，解析整段输出是纯计算，
///   放在主线程上会占住 UI（见 issue #1327）。
///   解析本身不碰任何 UI 状态，可以安全地在后台线程执行。
public enum EditorWorkspaceSearchPolicy {
    public static func emptyResponse(query: String) -> EditorWorkspaceSearchResponse {
        EditorWorkspaceSearchResponse(
            summary: EditorWorkspaceSearchSummary(query: query, totalMatches: 0, totalFiles: 0),
            fileResults: []
        )
    }

    public static func parse(
        output: String,
        query: String,
        projectRootPath: String,
        limit: Int = 200
    ) -> EditorWorkspaceSearchResponse {
        let decoder = JSONDecoder()
        let rootURL = URL(fileURLWithPath: projectRootPath, isDirectory: true)
        var groupedMatches: [String: [EditorWorkspaceSearchMatch]] = [:]
        var resultOrder: [String] = []
        var totalMatches = 0

        // - Important: 逐行惰性扫描，而不是 `output.split(separator: "\n")`。
        //   后者会把整段输出切成一个行数组（分配与拷贝都是 O(输出长度)），
        //   即使只需要前 `limit` 条匹配（见 issue #1327）。
        //   这里按字节找出每一行的边界，只把**当前行**转成字符串。
        //
        // `output.utf8` 是 UTF8View，索引访问不产生拷贝；
        // 整段输出因此不必被复制到数组里。
        //
        // - Note: 用 `index(after:)` 迭代而不是 `index(offsetBy:)` ——
        //   后者每次都要从头走，整体退化成 O(n²)。
        let utf8 = output.utf8
        var lineStart = utf8.startIndex
        var cursor = utf8.startIndex

        while cursor < utf8.endIndex {
            guard utf8[cursor] == 0x0A else {
                cursor = utf8.index(after: cursor)
                continue
            }

            let lineEnd = cursor
            cursor = utf8.index(after: cursor)

            guard totalMatches < limit else { break }

            let lineRange = lineStart..<lineEnd
            lineStart = cursor

            guard let match = Self.match(
                from: utf8[lineRange],
                decoder: decoder,
                rootURL: rootURL
            ) else { continue }

            if groupedMatches[match.path] == nil {
                groupedMatches[match.path] = []
                resultOrder.append(match.path)
            }
            groupedMatches[match.path, default: []].append(match)
            totalMatches += 1
        }

        // 末尾没有换行时，最后一行还没被处理。
        if lineStart < utf8.endIndex, totalMatches < limit {
            let lineRange = lineStart..<utf8.endIndex
            if let match = Self.match(
                from: utf8[lineRange],
                decoder: decoder,
                rootURL: rootURL
            ) {
                if groupedMatches[match.path] == nil {
                    groupedMatches[match.path] = []
                    resultOrder.append(match.path)
                }
                groupedMatches[match.path, default: []].append(match)
                totalMatches += 1
            }
        }

        let fileResults: [EditorWorkspaceSearchFileResult] = resultOrder.compactMap { path in
            guard let matches = groupedMatches[path], let first = matches.first else { return nil }
            return EditorWorkspaceSearchFileResult(url: first.url, path: path, matches: matches)
        }

        return EditorWorkspaceSearchResponse(
            summary: EditorWorkspaceSearchSummary(
                query: query,
                totalMatches: fileResults.reduce(0) { $0 + $1.matchCount },
                totalFiles: fileResults.count
            ),
            fileResults: fileResults
        )
    }

    public static func markdownContent(
        summary: EditorWorkspaceSearchSummary,
        fileResults: [EditorWorkspaceSearchFileResult]
    ) -> String {
        var content = "# Search Results\n\n"
        content += "- Query: `\(summary.query)`\n"
        content += "- Matches: \(summary.totalMatches)\n"
        content += "- Files: \(summary.totalFiles)\n\n"

        for file in fileResults {
            content += "## \(file.path)\n\n"
            for match in file.matches {
                content += "- `L\(match.line):C\(match.column)` \(match.preview)\n"
            }
            content += "\n"
        }

        return content
    }

    /// 解析一行 ripgrep 输出。
    ///
    /// - Returns: 命中的匹配项；该行不是 match 事件时返回 nil。
    private static func match(
        from line: Substring.UTF8View,
        decoder: JSONDecoder,
        rootURL: URL
    ) -> EditorWorkspaceSearchMatch? {
        guard let data = String(decoding: line, as: UTF8.self).data(using: .utf8),
              let event = try? decoder.decode(RipgrepEvent.self, from: data),
              event.type == "match",
              let payload = event.data,
              let filePath = payload.path?.text,
              let lineNumber = payload.lineNumber,
              let linePreview = payload.lines?.text else {
            return nil
        }

        let url = URL(fileURLWithPath: filePath)
        return EditorWorkspaceSearchMatch(
            url: url,
            line: lineNumber,
            column: (payload.submatches.first?.start ?? 0) + 1,
            path: relativePath(for: url, root: rootURL),
            preview: linePreview.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func relativePath(for url: URL, root: URL) -> String {
        EditorQuickOpenFilePolicy.relativePath(for: url, projectRootPath: root.path)
    }
}

private struct RipgrepEvent: Decodable {
    let type: String
    let data: RipgrepMatchPayload?
}

private struct RipgrepMatchPayload: Decodable {
    let path: RipgrepTextValue?
    let lines: RipgrepTextValue?
    let lineNumber: Int?
    let submatches: [RipgrepSubmatch]

    enum CodingKeys: String, CodingKey {
        case path
        case lines
        case lineNumber = "line_number"
        case submatches
    }
}

private struct RipgrepTextValue: Decodable {
    let text: String
}

private struct RipgrepSubmatch: Decodable {
    let start: Int
}
