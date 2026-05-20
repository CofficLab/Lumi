import Foundation

enum PrettierFormatter {
    static func isAvailable(projectPath: String) -> Bool {
        localPrettier(projectPath: projectPath) != nil || JSEnvResolver.findCommand("prettier") != nil
    }

    static func format(fileURL: URL, projectPath: String, runner: ScriptTaskRunner) async -> JSScriptResult {
        await runner.runExecutable(
            "prettier",
            arguments: ["--write", fileURL.path],
            projectPath: projectPath
        )
    }

    private static func localPrettier(projectPath: String) -> String? {
        let path = URL(fileURLWithPath: projectPath)
            .appendingPathComponent("node_modules/.bin/prettier")
            .path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }
}
