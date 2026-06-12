import Foundation

public enum ESLintLSPBridge {
    public static func isAvailable(projectPath: String) -> Bool {
        let local = URL(fileURLWithPath: projectPath)
            .appendingPathComponent("node_modules/.bin/eslint")
            .path
        return FileManager.default.isExecutableFile(atPath: local)
            || JSEnvResolver.findCommand("eslint") != nil
    }

    public static func lint(fileURL: URL?, projectPath: String, runner: ScriptTaskRunner) async -> JSScriptResult? {
        guard let fileURL else { return nil }
        return await runner.runExecutable(
            "eslint",
            arguments: ["--format", "stylish", fileURL.path],
            projectPath: projectPath
        )
    }
}
