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

@MainActor
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

        for line in output.split(separator: "\n") {
            guard totalMatches < limit,
                  let data = line.data(using: .utf8),
                  let event = try? decoder.decode(RipgrepEvent.self, from: data),
                  event.type == "match",
                  let payload = event.data,
                  let filePath = payload.path?.text,
                  let lineNumber = payload.lineNumber,
                  let linePreview = payload.lines?.text else {
                continue
            }

            let url = URL(fileURLWithPath: filePath)
            let relativePath = relativePath(for: url, root: rootURL)
            let column = (payload.submatches.first?.start ?? 0) + 1
            let match = EditorWorkspaceSearchMatch(
                url: url,
                line: lineNumber,
                column: column,
                path: relativePath,
                preview: linePreview.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if groupedMatches[relativePath] == nil {
                groupedMatches[relativePath] = []
                resultOrder.append(relativePath)
            }
            groupedMatches[relativePath, default: []].append(match)
            totalMatches += 1
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
