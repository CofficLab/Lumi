import Foundation

public struct ReviewContext: Sendable {
    public let repositoryPath: String
    public let scope: ReviewScope
    public let diffContent: String
    public let diffStats: ReviewDiffStats
    public let changedFiles: [String]
    public let projectContext: String
    public let projectRules: String
    public let truncated: Bool
    public let skippedFiles: [String]

    public var hasChanges: Bool {
        !diffContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct ReviewAnalyzer: Sendable {
    public var maxTotalDiffLines: Int = 1_200
    public var maxPerFileDiffLines: Int = 500

    public func buildContext(repositoryPath: String, scope: ReviewScope, file: String? = nil) async throws -> ReviewContext {
        let root = URL(fileURLWithPath: repositoryPath).standardizedFileURL.path

        guard ReviewGitService.shared.isGitRepository(at: root) else {
            throw ReviewAnalyzerError.notGitRepository(root)
        }

        let diff: ReviewGitDiff
        switch scope {
        case .staged:
            diff = try ReviewGitService.shared.getDiff(path: root, staged: true, file: file)
        case .unstaged:
            diff = try ReviewGitService.shared.getDiff(path: root, staged: false, file: file)
        case .allUncommitted:
            let staged = try ReviewGitService.shared.getDiff(path: root, staged: true, file: file)
            let unstaged = try ReviewGitService.shared.getDiff(path: root, staged: false, file: file)
            let content = [staged.content, unstaged.content]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
            diff = ReviewGitDiff(
                content: content,
                stats: gitStats(lhs: staged.stats, rhs: unstaged.stats)
            )
        }

        let status = try? ReviewGitService.shared.getStatus(path: root)
        let changedFiles = collectChangedFiles(status: status, explicitFile: file)
        let limited = limitDiff(diff.content)

        return ReviewContext(
            repositoryPath: root,
            scope: scope,
            diffContent: limited.content,
            diffStats: reviewStats(from: diff.stats),
            changedFiles: changedFiles,
            projectContext: collectProjectContext(at: root),
            projectRules: collectProjectRules(at: root),
            truncated: limited.truncated,
            skippedFiles: limited.skippedFiles
        )
    }

    private func reviewStats(from stats: ReviewGitDiffStats?) -> ReviewDiffStats {
        guard let stats else { return .empty }
        return ReviewDiffStats(
            filesChanged: stats.filesChanged,
            insertions: stats.insertions,
            deletions: stats.deletions
        )
    }

    private func gitStats(lhs: ReviewGitDiffStats?, rhs: ReviewGitDiffStats?) -> ReviewGitDiffStats {
        let lhs = reviewStats(from: lhs)
        let rhs = reviewStats(from: rhs)
        return ReviewGitDiffStats(
            filesChanged: lhs.filesChanged + rhs.filesChanged,
            insertions: lhs.insertions + rhs.insertions,
            deletions: lhs.deletions + rhs.deletions
        )
    }

    private func collectChangedFiles(status: ReviewGitStatus?, explicitFile: String?) -> [String] {
        if let explicitFile {
            return [explicitFile]
        }
        guard let status else { return [] }
        return Array(Set(status.modified + status.added + status.deleted + status.renamed + status.staged)).sorted()
    }

    private func collectProjectContext(at root: String) -> String {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: root)
        let manifests = [
            "Package.swift",
            "project.yml",
            "Podfile",
            "package.json",
            "pnpm-lock.yaml",
            "yarn.lock",
            "Cargo.toml",
            "go.mod",
            "pyproject.toml",
            "requirements.txt"
        ].filter { fm.fileExists(atPath: rootURL.appendingPathComponent($0).path) }

        var hints: [String] = []
        if manifests.contains("Package.swift") { hints.append("Swift / Swift Package or Xcode project") }
        if manifests.contains("package.json") { hints.append("JavaScript or TypeScript") }
        if manifests.contains("go.mod") { hints.append("Go") }
        if manifests.contains("pyproject.toml") || manifests.contains("requirements.txt") { hints.append("Python") }
        if manifests.contains("Cargo.toml") { hints.append("Rust") }

        return """
        Repository: \(root)
        Detected stack: \(hints.isEmpty ? "Unknown" : hints.joined(separator: ", "))
        Manifest files: \(manifests.isEmpty ? "None detected" : manifests.joined(separator: ", "))
        """
    }

    private func collectProjectRules(at root: String) -> String {
        let ruleDirs = [".agent/rules", ".agents/rules"]
        var sections: [String] = []

        for dir in ruleDirs {
            let url = URL(fileURLWithPath: root).appendingPathComponent(dir)
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for file in files where file.pathExtension == "md" {
                guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
                sections.append("## \(dir)/\(file.lastPathComponent)\n\(content)")
            }
        }

        return sections.isEmpty ? "No project review rules found." : sections.joined(separator: "\n\n")
    }

    private func limitDiff(_ diff: String) -> (content: String, truncated: Bool, skippedFiles: [String]) {
        let lines = diff.components(separatedBy: .newlines)
        guard lines.count > maxTotalDiffLines else {
            return (diff, false, [])
        }

        let kept = lines.prefix(maxTotalDiffLines).joined(separator: "\n")
        let summary = "\n\n[Diff truncated: kept first \(maxTotalDiffLines) of \(lines.count) lines.]"
        return (kept + summary, true, [])
    }
}

public enum ReviewAnalyzerError: LocalizedError {
    case notGitRepository(String)

    public var errorDescription: String? {
        switch self {
        case .notGitRepository(let path):
            return "Not a Git repository: \(path)"
        }
    }
}
