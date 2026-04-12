import Foundation
import MagicKit

/// 上下文服务，管理 Agent 模式的上下文信息
actor ContextService: Sendable, SuperLog {
    nonisolated static let emoji = "📂"
    nonisolated static let verbose: Bool = false    private struct CachedFilePreview: Sendable {
        let preview: String
        let modifiedAt: Date?
        let fileSize: UInt64
    }

    private struct GitSummary: Sendable {
        let branch: String
        let hasUncommittedChanges: Bool
        let recentCommits: [String]
    }

    private(set) var projectRoot: URL?
    private(set) var openFiles: [URL] = []
    private var filePreviewCache: [String: CachedFilePreview] = [:]

    // Limits
    private let maxContextChars = 20_000
    private let maxTrackedFiles = 20
    private let maxDisplayedFiles = 6
    private let maxPreviewBytes = 12_000
    private let maxPreviewChars = 600
    private let maxGitSectionChars = 1_200
    private let reservedTailChars = 120

    init() {}

    func setProjectRoot(_ url: URL?) {
        if self.projectRoot?.path != url?.path {
            self.openFiles.removeAll(keepingCapacity: false)
            self.filePreviewCache.removeAll(keepingCapacity: false)
            AppLogger.core.info("\(self.t)Project root changed, cleared tracked file context")
        }
        self.projectRoot = url
    }

    func trackOpenFile(_ url: URL) {
        guard url.isFileURL else {
            AppLogger.core.warning("\(self.t)Ignored non-file URL in trackOpenFile")
            return
        }

        self.openFiles.removeAll { $0.path == url.path }
        self.openFiles.insert(url, at: 0)
        if self.openFiles.count > maxTrackedFiles {
            self.openFiles = Array(self.openFiles.prefix(maxTrackedFiles))
        }
    }

    func getContextPrompt() -> String {
        var prompt = "## Current Context\n"
        prompt += "- Date: \(formattedNow())\n"
        prompt += "- OS: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"

        if let root = projectRoot {
            prompt += "- Project Root: \(root.path)\n"
            let gitSection = gitContextSection(root: root)
            prompt += String(gitSection.prefix(maxGitSectionChars))
        } else {
            prompt += "- Project Root: Not set (using current working directory)\n"
        }
        let remaining = max(maxContextChars - prompt.count - reservedTailChars, 0)
        if remaining > 0 {
            prompt += buildRecentFilesSection(maxChars: remaining)
        }

        prompt = trimIfNeeded(prompt)

        return prompt
    }

    private func gitContextSection(root: URL) -> String {
        var section = ""
        guard let summary = buildGitSummary(root: root) else {
            section += "- Git: Not available\n"
            return section
        }

        section += "- Git Branch: \(summary.branch)\n"
        section += "- Git Dirty: \(summary.hasUncommittedChanges ? "Yes" : "No")\n"

        if !summary.recentCommits.isEmpty {
            section += "- Recent Commits:\n"
            for commit in summary.recentCommits {
                section += "  - \(commit)\n"
            }
        }
        return section
    }

    private func buildRecentFilesSection(maxChars: Int) -> String {
        guard maxChars > 0 else { return "" }

        var section = ""
        guard !openFiles.isEmpty else {
            section += "- Recent Files: None\n"
            return String(section.prefix(maxChars))
        }

        section += "- Recent Files:\n"

        let candidates = prioritizedFiles().prefix(maxDisplayedFiles)
        for file in candidates {
            let path = projectRoot.map { relativize(file: file, to: $0) } ?? file.path
            let line = "  - \(path)\n"
            if section.count + line.count > maxChars { break }
            section += line

            if let preview = getFilePreview(for: file), !preview.isEmpty {
                let previewLine = "    Preview: \(preview)\n"
                if section.count + previewLine.count > maxChars { continue }
                section += previewLine
            }
        }

        return section
    }

    private func prioritizedFiles() -> [URL] {
        openFiles.enumerated()
            .sorted { lhs, rhs in
                let l = filePriority(url: lhs.element, index: lhs.offset)
                let r = filePriority(url: rhs.element, index: rhs.offset)
                return l > r
            }
            .map(\.element)
    }

    private func filePriority(url: URL, index: Int) -> Int {
        let recencyWeight = max(0, 100 - index * 5)
        let ext = url.pathExtension.lowercased()
        let typeWeight: Int
        switch ext {
        case "swift", "m", "mm", "h", "hpp": typeWeight = 35
        case "md", "markdown", "txt": typeWeight = 20
        case "json", "yml", "yaml", "toml", "plist": typeWeight = 15
        default: typeWeight = 5
        }
        return recencyWeight + typeWeight
    }

    private func trimIfNeeded(_ prompt: String) -> String {
        if prompt.count <= maxContextChars { return prompt }
        let truncated = String(prompt.prefix(maxContextChars))
        AppLogger.core.warning("\(self.t)Context prompt exceeded budget and was truncated")
        return truncated + "\n- Context truncated to stay within budget.\n"
    }

    private func formattedNow() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: Date())
    }

    private func buildGitSummary(root: URL) -> GitSummary? {
        let branch = runGit(["rev-parse", "--abbrev-ref", "HEAD"], in: root)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !branch.isEmpty else { return nil }

        let status = runGit(["status", "--porcelain"], in: root)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let dirty = !status.isEmpty

        let commitsOutput = runGit(["log", "-n", "3", "--pretty=format:%h %s"], in: root)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let commits = commitsOutput.isEmpty ? [] : commitsOutput.components(separatedBy: .newlines)

        return GitSummary(branch: branch, hasUncommittedChanges: dirty, recentCommits: commits)
    }

    private func runGit(_ args: [String], in root: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = root

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            AppLogger.core.warning("\(self.t)Git command failed to start: \(args.joined(separator: " "))")
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func getFilePreview(for url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }

        let modifiedAt = attributes[.modificationDate] as? Date
        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let cacheKey = url.path

        if let cached = filePreviewCache[cacheKey],
           cached.modifiedAt == modifiedAt,
           cached.fileSize == fileSize {
            return cached.preview
        }

        guard fileSize <= UInt64(maxPreviewBytes * 4) else {
            let preview = "(file too large to preview)"
            filePreviewCache[cacheKey] = CachedFilePreview(preview: preview, modifiedAt: modifiedAt, fileSize: fileSize)
            return preview
        }

        let preview: String
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: maxPreviewBytes) ?? Data()
            if let text = String(data: data, encoding: .utf8) {
                let compact = text
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\t", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                preview = String(compact.prefix(maxPreviewChars))
            } else {
                preview = "(binary or unsupported encoding)"
            }
        } catch {
            preview = "(preview unavailable)"
        }

        filePreviewCache[cacheKey] = CachedFilePreview(preview: preview, modifiedAt: modifiedAt, fileSize: fileSize)
        return preview
    }

    private func relativize(file: URL, to root: URL) -> String {
        let filePath = file.path
        let rootPath = root.path
        if filePath.hasPrefix(rootPath + "/") {
            return String(filePath.dropFirst(rootPath.count + 1))
        }
        return file.lastPathComponent
    }
}
