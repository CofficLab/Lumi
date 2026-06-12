import Foundation

/// Background-only Xcode project filesystem queries.
///
/// Keep callers such as UI bridges and SwiftUI view models from doing package
/// discovery or buildServer.json validation on the MainActor.
public enum XcodeProjectBackgroundQuery {
    public struct ProjectInspection: Sendable, Equatable {
        public let projectPath: String
        public let isXcodeProject: Bool
        public let workspaceURL: URL?
        public let validBuildServerConfig: XcodeBuildServerStore.Config?

        public init(
            projectPath: String,
            isXcodeProject: Bool,
            workspaceURL: URL?,
            validBuildServerConfig: XcodeBuildServerStore.Config?
        ) {
            self.projectPath = projectPath
            self.isXcodeProject = isXcodeProject
            self.workspaceURL = workspaceURL
            self.validBuildServerConfig = validBuildServerConfig
        }
    }

    public static func inspectProject(path: String, store: XcodeBuildServerStore? = nil) async -> ProjectInspection {
        await Task.detached(priority: .utility) {
            let projectURL = URL(fileURLWithPath: path)
            let workspaceURL = XcodeProjectResolver.findWorkspace(in: projectURL)
            let config = workspaceURL.flatMap { workspaceURL in
                Self.validateBuildServer(store: store, workspaceURL: workspaceURL)
            }
            return ProjectInspection(
                projectPath: path,
                isXcodeProject: workspaceURL != nil,
                workspaceURL: workspaceURL,
                validBuildServerConfig: config
            )
        }.value
    }

    public static func isXcodeProjectRoot(_ path: String) async -> Bool {
        await Task.detached(priority: .utility) {
            XcodeProjectResolver.isXcodeProjectRoot(URL(fileURLWithPath: path))
        }.value
    }

    public static func findWorkspace(in path: String) async -> URL? {
        await Task.detached(priority: .utility) {
            XcodeProjectResolver.findWorkspace(in: URL(fileURLWithPath: path))
        }.value
    }

    private static func validateBuildServer(store: XcodeBuildServerStore?, workspaceURL: URL) -> XcodeBuildServerStore.Config? {
        guard let store else { return nil }
        for path in workspacePathCandidates(for: workspaceURL) {
            if let config = store.validate(forWorkspace: path) {
                return config
            }
        }
        return nil
    }

    static func workspacePathCandidates(for workspaceURL: URL) -> [String] {
        let rawPath = workspaceURL.path
        let resolvedPath = workspaceURL.resolvingSymlinksInPath().path
        let withoutPrivatePrefix = rawPath.hasPrefix("/private/") ? String(rawPath.dropFirst("/private".count)) : rawPath
        return uniquePreservingOrder([rawPath, resolvedPath, withoutPrivatePrefix])
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
