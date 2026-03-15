import Foundation

enum GitSection {
    static func render(at root: URL) -> String {
        let gitDir = root.appendingPathComponent(".git", isDirectory: true)
        // .git can be a directory (normal repo) or a file (submodule with gitdir pointer)
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            return "Not a Git repository."
        }

        let branch = runGit(args: ["branch", "--show-current"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let remote = runGit(args: ["remote", "get-url", "origin"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusPorcelain = runGit(args: ["status", "--porcelain"], in: root)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isClean = (statusPorcelain ?? "").isEmpty

        var lines: [String] = ["Repository: Yes"]
        if let b = branch, !b.isEmpty { lines.append("Branch: \(b)") }
        if let r = remote, !r.isEmpty { lines.append("Remote: \(r)") }
        lines.append("Status: \(isClean ? "Clean" : "Uncommitted changes")")
        return lines.joined(separator: "\n")
    }

    private static func runGit(args: [String], in directory: URL) -> String? {
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
}
