import Foundation
import ShellKit

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
        let semaphore = DispatchSemaphore(value: 0)
        let box = GitSectionLockedStringBox()
        Task {
            let result = try? await Shell.execute(
                executable: "/usr/bin/git",
                arguments: args,
                options: ShellOptions(
                    workingDirectory: directory.path,
                    environment: [
                        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                    ],
                    throwsOnError: false
                )
            )
            box.set(result?.exitCode == 0 ? result?.stdout : nil)
            semaphore.signal()
        }
        semaphore.wait()
        return box.get()
    }
}

private final class GitSectionLockedStringBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    func set(_ value: String?) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    func get() -> String? {
        lock.lock()
        let result = value
        lock.unlock()
        return result
    }
}
