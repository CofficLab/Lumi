import Foundation

/// Xcode Build Settings 解析器
/// 负责解析 `xcodebuild -list -json` 和 `xcodebuild -showBuildSettings -json` 的输出
public enum XcodeBuildSettingsParser {

    /// 解析 `xcodebuild -list -json` 的结果
    public struct ListResult: Sendable {
        public let project: ProjectInfo?
        public let workspace: WorkspaceInfo?

        public init(project: ProjectInfo?, workspace: WorkspaceInfo?) {
            self.project = project
            self.workspace = workspace
        }

        public struct ProjectInfo: Sendable {
            public let name: String
            public let targets: [String]
            public let configurations: [String]
            public let schemes: [String]

            public init(name: String, targets: [String], configurations: [String], schemes: [String]) {
                self.name = name
                self.targets = targets
                self.configurations = configurations
                self.schemes = schemes
            }
        }

        public struct WorkspaceInfo: Sendable {
            public let name: String
            public let schemes: [String]

            public init(name: String, schemes: [String]) {
                self.name = name
                self.schemes = schemes
            }
        }
    }

    /// 解析 `xcodebuild -list -json` 输出
    public static func parseListOutput(_ data: Data) throws -> ListResult {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        var projectInfo: ListResult.ProjectInfo?
        var workspaceInfo: ListResult.WorkspaceInfo?

        if let projectDict = json?["project"] as? [String: Any] {
            projectInfo = ListResult.ProjectInfo(
                name: projectDict["name"] as? String ?? "",
                targets: projectDict["targets"] as? [String] ?? [],
                configurations: projectDict["configurations"] as? [String] ?? [],
                schemes: projectDict["schemes"] as? [String] ?? []
            )
        }

        if let workspaceDict = json?["workspace"] as? [String: Any] {
            workspaceInfo = ListResult.WorkspaceInfo(
                name: workspaceDict["name"] as? String ?? "",
                schemes: workspaceDict["schemes"] as? [String] ?? []
            )
        }

        return ListResult(project: projectInfo, workspace: workspaceInfo)
    }

    /// 解析 `xcodebuild -showBuildSettings -json` 输出
    /// 返回 [String: String] 的 build settings 字典
    public static func parseBuildSettingsOutput(_ data: Data) throws -> [[String: String]] {
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        guard let json else { return [] }

        return json.compactMap { dict -> [String: String]? in
            guard let settings = dict["buildSettings"] as? [String: Any] else { return nil }
            return settings.compactMapValues { "\($0)" }
        }
    }
}
