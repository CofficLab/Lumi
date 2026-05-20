import Foundation

struct NodeDAPAdapter: Sendable {
    enum LaunchKind: Sendable {
        case node
        case npmScript(String)
    }

    struct LaunchConfiguration: Sendable {
        let kind: LaunchKind
        let projectPath: String
        let program: String?
        let arguments: [String]
        let environment: [String: String]
    }

    static func defaultLaunch(fileURL: URL?, projectPath: String) -> LaunchConfiguration {
        LaunchConfiguration(
            kind: .node,
            projectPath: projectPath,
            program: fileURL?.path,
            arguments: [],
            environment: [:]
        )
    }

    static func commandLine(for config: LaunchConfiguration) -> (executable: String, arguments: [String])? {
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
