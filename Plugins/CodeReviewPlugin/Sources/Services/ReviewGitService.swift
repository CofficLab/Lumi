import Foundation

struct ReviewGitDiff: Sendable {
    let content: String
    let stats: ReviewGitDiffStats?
}

struct ReviewGitDiffStats: Sendable {
    let filesChanged: Int
    let insertions: Int
    let deletions: Int
}

struct ReviewGitStatus: Sendable {
    let modified: [String]
    let added: [String]
    let deleted: [String]
    let renamed: [String]
    let staged: [String]
}

final class ReviewGitService: @unchecked Sendable {
    static let shared = ReviewGitService()

    private init() {}

    func isGitRepository(at path: String) -> Bool {
        (try? runGit(path: path, args: ["rev-parse", "--is-inside-work-tree"]))?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    func getDiff(path: String, staged: Bool, file: String?) throws -> ReviewGitDiff {
        var args = ["diff"]
        if staged {
            args.append("--cached")
        }
        if let file, !file.isEmpty {
            args.append(contentsOf: ["--", file])
        }

        var statArgs = ["diff", "--numstat"]
        if staged {
            statArgs.append("--cached")
        }
        if let file, !file.isEmpty {
            statArgs.append(contentsOf: ["--", file])
        }

        let content = try runGit(path: path, args: args)
        let stats = parseNumstat(try? runGit(path: path, args: statArgs))
        return ReviewGitDiff(content: content, stats: stats)
    }

    func getStatus(path: String) throws -> ReviewGitStatus {
        let output = try runGit(path: path, args: ["status", "--porcelain"])
        var modified: [String] = []
        var added: [String] = []
        var deleted: [String] = []
        var renamed: [String] = []
        var staged: [String] = []

        for line in output.split(separator: "\n") {
            guard line.count >= 4 else { continue }
            let indexStatus = line[line.startIndex]
            let worktreeStatus = line[line.index(after: line.startIndex)]
            let pathStart = line.index(line.startIndex, offsetBy: 3)
            let pathValue = String(line[pathStart...])
            let normalizedPath = pathValue.components(separatedBy: " -> ").last ?? pathValue

            if indexStatus != " " && indexStatus != "?" {
                staged.append(normalizedPath)
            }
            switch worktreeStatus {
            case "M": modified.append(normalizedPath)
            case "A", "?": added.append(normalizedPath)
            case "D": deleted.append(normalizedPath)
            case "R": renamed.append(normalizedPath)
            default: break
            }
            switch indexStatus {
            case "M": modified.append(normalizedPath)
            case "A": added.append(normalizedPath)
            case "D": deleted.append(normalizedPath)
            case "R": renamed.append(normalizedPath)
            default: break
            }
        }

        return ReviewGitStatus(
            modified: Array(Set(modified)),
            added: Array(Set(added)),
            deleted: Array(Set(deleted)),
            renamed: Array(Set(renamed)),
            staged: Array(Set(staged))
        )
    }

    func parseNumstat(_ output: String?) -> ReviewGitDiffStats? {
        Self.parseNumstat(output)
    }

    /// Parse `git numstat` output into aggregate diff stats.
    ///
    /// Each line is `<insertions>\t<deletions>\t<filepath>`. Binary files
    /// report `-` for the counts (coerced to 0). Promoted to a static,
    /// testable helper.
    static func parseNumstat(_ output: String?) -> ReviewGitDiffStats? {
        guard let output, !output.isEmpty else { return nil }
        var files = 0
        var insertions = 0
        var deletions = 0

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count >= 3 else { continue }
            files += 1
            insertions += Int(parts[0]) ?? 0
            deletions += Int(parts[1]) ?? 0
        }

        return ReviewGitDiffStats(filesChanged: files, insertions: insertions, deletions: deletions)
    }

    private func runGit(path: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let outputBuffer = LockedProcessOutputBuffer()
        let errorBuffer = LockedProcessOutputBuffer()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            outputBuffer.append(handle.availableData)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            errorBuffer.append(handle.availableData)
        }

        try process.run()
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        outputBuffer.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
        errorBuffer.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

        let output = String(data: outputBuffer.data(), encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            return output
        }

        let error = String(data: errorBuffer.data(), encoding: .utf8) ?? ""
        throw ReviewGitServiceError.gitFailed(error.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private final class LockedProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    func data() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

enum ReviewGitServiceError: LocalizedError {
    case gitFailed(String)

    var errorDescription: String? {
        switch self {
        case .gitFailed(let message):
            return message.isEmpty ? "Git command failed." : message
        }
    }
}
