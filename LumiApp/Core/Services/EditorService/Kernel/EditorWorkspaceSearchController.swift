import Foundation

struct EditorWorkspaceSearchMatch: Identifiable, Equatable {
    let url: URL
    let line: Int
    let column: Int
    let path: String
    let preview: String

    var id: String {
        "\(path):\(line):\(column):\(preview)"
    }
}

struct EditorWorkspaceSearchFileResult: Identifiable, Equatable {
    let url: URL
    let path: String
    let matches: [EditorWorkspaceSearchMatch]

    var id: String { path }
    var matchCount: Int { matches.count }
}

struct EditorWorkspaceSearchSummary: Equatable {
    let query: String
    let totalMatches: Int
    let totalFiles: Int
}

struct EditorWorkspaceSearchResponse: Equatable {
    let summary: EditorWorkspaceSearchSummary
    let fileResults: [EditorWorkspaceSearchFileResult]
}

final class EditorWorkspaceSearchController {
    func search(
        query: String,
        projectRootPath: String,
        limit: Int = 200
    ) async throws -> EditorWorkspaceSearchResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return EditorWorkspaceSearchResponse(
                summary: EditorWorkspaceSearchSummary(query: query, totalMatches: 0, totalFiles: 0),
                fileResults: []
            )
        }

        let output = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let output = try Self.runSearchProcess(query: trimmedQuery, projectRootPath: projectRootPath)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return parse(output: output, query: trimmedQuery, projectRootPath: projectRootPath, limit: limit)
    }

    func parse(
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
            let relativePath = Self.relativePath(for: url, root: rootURL)
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

    func exportSearchEditor(
        summary: EditorWorkspaceSearchSummary,
        fileResults: [EditorWorkspaceSearchFileResult]
    ) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "search-results-\(timestamp).md"
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(filename)

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

        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func runSearchProcess(query: String, projectRootPath: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "rg",
            "--json",
            "--line-number",
            "--column",
            "--smart-case",
            "--color", "never",
            "--hidden",
            "--glob", "!.git",
            "--glob", "!node_modules",
            "--glob", "!.build",
            query,
            projectRootPath
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        if process.terminationStatus == 0 || process.terminationStatus == 1 {
            return output
        }

        throw WorkspaceSearchError.processFailed(error.isEmpty ? "rg exited with \(process.terminationStatus)" : error)
    }

    private static func relativePath(for url: URL, root: URL) -> String {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
        let suffix = path.dropFirst(rootPath.count).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return suffix.isEmpty ? url.lastPathComponent : suffix
    }
}

enum WorkspaceSearchError: LocalizedError {
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .processFailed(let message):
            return message
        }
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
