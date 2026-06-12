import Foundation

@MainActor
public final class FormatOnSaveCoordinator {
    private let runner: ScriptTaskRunner

    public init(runner: ScriptTaskRunner) {
        self.runner = runner
    }

    public func formatIfPossible(fileURL: URL?, projectPath: String?) async -> JSScriptResult? {
        guard let fileURL, let projectPath else { return nil }
        guard PrettierFormatter.isAvailable(projectPath: projectPath) else { return nil }
        return await PrettierFormatter.format(fileURL: fileURL, projectPath: projectPath, runner: runner)
    }
}
