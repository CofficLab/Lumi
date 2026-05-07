import Foundation

@MainActor
public final class EditorWorkspaceSearchController {
    public init() {}

    public func search(
        query: String,
        projectRootPath: String,
        limit: Int = 200
    ) async throws -> EditorWorkspaceSearchResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return EditorWorkspaceSearchPolicy.emptyResponse(query: query)
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

    public func parse(
        output: String,
        query: String,
        projectRootPath: String,
        limit: Int = 200
    ) -> EditorWorkspaceSearchResponse {
        EditorWorkspaceSearchPolicy.parse(
            output: output,
            query: query,
            projectRootPath: projectRootPath,
            limit: limit
        )
    }

    public func exportSearchEditor(
        summary: EditorWorkspaceSearchSummary,
        fileResults: [EditorWorkspaceSearchFileResult]
    ) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "search-results-\(timestamp).md"
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(filename)

        try EditorWorkspaceSearchPolicy
            .markdownContent(summary: summary, fileResults: fileResults)
            .write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private nonisolated static func runSearchProcess(query: String, projectRootPath: String) throws -> String {
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
}

public enum WorkspaceSearchError: LocalizedError {
    case processFailed(String)

    public var errorDescription: String? {
        switch self {
        case .processFailed(let message):
            return message
        }
    }
}
