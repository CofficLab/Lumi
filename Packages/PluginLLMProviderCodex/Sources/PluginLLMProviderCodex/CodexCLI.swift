import Foundation

struct CodexCLI: Sendable {
    let executablePath: String

    init(executablePath: String = CodexCLI.defaultExecutablePath()) {
        self.executablePath = executablePath
    }

    var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: executablePath)
    }

    func arguments(prompt: String, model: String) -> [String] {
        [
            "-a", "never",
            "exec",
            "--json",
            "-m", model,
            "-s", "workspace-write",
            "--skip-git-repo-check",
            prompt
        ]
    }

    static func defaultExecutablePath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        let candidates = pathCandidates(environment: environment)
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/codex"
    }

    static func pathCandidates(environment: [String: String]) -> [String] {
        var candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex",
        ]

        let pathEntries = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }

        for entry in pathEntries {
            candidates.append((entry as NSString).appendingPathComponent("codex"))
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }
}
