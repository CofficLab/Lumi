import Foundation

public struct NodeDAPAdapter: Sendable {
    public enum LaunchKind: Sendable {
        case node
        case npmScript(String)
    }

    public struct LaunchConfiguration: Sendable {
        public let kind: LaunchKind
        public let projectPath: String
        public let program: String?
        public let arguments: [String]
        public let environment: [String: String]
    }

    public static func defaultLaunch(fileURL: URL?, projectPath: String) -> LaunchConfiguration {
        LaunchConfiguration(
            kind: .node,
            projectPath: projectPath,
            program: fileURL?.path,
            arguments: [],
            environment: [:]
        )
    }

    public static func commandLine(for config: LaunchConfiguration) -> (executable: String, arguments: [String])? {
        switch config.kind {
        case .node:
            guard let node = JSEnvResolver.nodePath, let program = config.program else { return nil }
            return (node, [program] + config.arguments)
        case .npmScript(let script):
            let manager = JSEnvResolver.detectPackageManager(projectPath: config.projectPath)
            guard let path = JSEnvResolver.packageManagerPath(manager) else { return nil }
            return (path, ["run", script] + config.arguments)
        }
    }
}
