import Foundation
import os

/// Xcode Build Settings 解析器
/// 负责解析 `xcodebuild -list -json` 和 `xcodebuild -showBuildSettings -json` 的输出
enum XcodeBuildSettingsParser {
    
    /// 解析 `xcodebuild -list -json` 的结果
    struct ListResult {
        let project: ProjectInfo?
        let workspace: WorkspaceInfo?
        
        struct ProjectInfo {
            let name: String
            let targets: [String]
            let configurations: [String]
            let schemes: [String]
        }
        
        struct WorkspaceInfo {
            let name: String
            let schemes: [String]
        }
    }
    
    /// 解析 `xcodebuild -list -json` 输出
    static func parseListOutput(_ data: Data) throws -> ListResult {
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
    static func parseBuildSettingsOutput(_ data: Data) throws -> [[String: String]] {
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        guard let json else { return [] }
        
        return json.compactMap { dict -> [String: String]? in
            guard let settings = dict["buildSettings"] as? [String: Any] else { return nil }
            return settings.compactMapValues { "\($0)" }
        }
    }
}
