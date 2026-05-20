import Foundation

enum FrameworkLSPLoader {
    static func initializationOptions(projectPath: String) -> [String: String] {
        guard let workspace = WorkspaceDetector.detect(projectPath: projectPath) else { return [:] }
        var options: [String: String] = [:]
        if let framework = workspace.framework {
            options["lumi.framework"] = framework.rawValue
        }
        if let builder = workspace.builder {
            options["lumi.builder"] = builder.rawValue
        }
        options["lumi.packageManager"] = workspace.manager.rawValue
        return options
    }
}
