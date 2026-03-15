import Foundation
import MagicKit
import OSLog

/// Returns a short overview of a project: path, type, top-level structure, Git info, key files.
struct ProjectOverviewTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = true

    let name = "project_overview"
    let description = "Get a short overview of a project: path, type, top-level structure, Git info, key files (README, LICENSE, .gitignore). Use when you need to understand the project before diving in."

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Project root path. Omit to use current working directory."
                ]
            ]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel? {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let path = arguments["path"]?.value as? String ?? FileManager.default.currentDirectoryPath
        let root = URL(fileURLWithPath: path).standardizedFileURL

        if Self.verbose {
            os_log("\(Self.t)Project overview: \(root.path)")
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            return "Error: Path does not exist or is not a directory: \(path)"
        }

        var sections: [String] = []

        // Path
        sections.append("## Project Overview\n\n**Path**: \(root.path)")

        // Project type
        let projectType = detectProjectType(at: root)
        sections.append("### Project type\n\(projectType)")

        // Top-level structure
        let topLevel = topLevelItems(at: root)
        sections.append("### Top-level structure\n\(topLevel)")

        // Git
        let gitSection = await gitOverview(at: root)
        sections.append("### Git\n\(gitSection)")

        // Key files
        let keyFiles = keyFilesSection(at: root)
        sections.append("### Key files\n\(keyFiles)")

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Helpers

    private func detectProjectType(at root: URL) -> String {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: root.path) else { return "Unknown" }

        let set = Set(names)
        if set.contains("Package.swift") || (set.contains { $0.hasSuffix(".xcodeproj") }) { return "Swift (Xcode / SPM)" }
        if set.contains("package.json") { return "Node / JavaScript" }
        if set.contains("Cargo.toml") { return "Rust" }
        if set.contains("pyproject.toml") || set.contains("requirements.txt") { return "Python" }
        if set.contains("go.mod") { return "Go" }
        return "Unknown"
    }

    private func topLevelItems(at root: URL) -> String {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return "(Unable to list directory)"
        }
        let sorted = contents.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        var lines: [String] = []
        for url in sorted {
            let name = url.lastPathComponent
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            lines.append(name + (isDir ? "/" : ""))
        }
        return lines.isEmpty ? "(Empty)" : lines.joined(separator: "\n")
    }

    private func gitOverview(at root: URL) -> String {
        let gitDir = root.appendingPathComponent(".git", isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: gitDir.path, isDirectory: &isDir) else {
            return "Not a Git repository."
        }

        let branch = runGit(args: ["branch", "--show-current"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let remote = runGit(args: ["remote", "get-url", "origin"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines: [String] = ["Repository: Yes"]
        if let b = branch, !b.isEmpty { lines.append("Branch: \(b)") }
        if let r = remote, !r.isEmpty { lines.append("Remote: \(r)") }
        return lines.joined(separator: "\n")
    }

    private func runGit(args: [String], in directory: URL) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.currentDirectoryURL = directory
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func keyFilesSection(at root: URL) -> String {
        let fm = FileManager.default
        func exists(_ name: String) -> Bool {
            fm.fileExists(atPath: root.appendingPathComponent(name).path)
        }
        var lines: [String] = []
        if exists("README.md") { lines.append("- README: README.md") }
        else if exists("README") { lines.append("- README: README") }
        else { lines.append("- README: None") }
        lines.append(exists("LICENSE") ? "- LICENSE: LICENSE" : "- LICENSE: None")
        lines.append(exists(".gitignore") ? "- .gitignore: Yes" : "- .gitignore: No")
        return lines.joined(separator: "\n")
    }
}
