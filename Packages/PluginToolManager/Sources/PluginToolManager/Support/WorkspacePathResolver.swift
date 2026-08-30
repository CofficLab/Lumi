import Foundation

/// 将工具参数中的路径解析到统一的工作区边界。
enum WorkspacePathResolver {
    static func resolve(path: String, workspaceRoot: String?) -> URL {
        let expandedPath = (path as NSString).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return URL(fileURLWithPath: expandedPath)
        }

        if let workspaceRoot,
           !workspaceRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let rootURL = URL(fileURLWithPath: workspaceRoot).standardizedFileURL
            return URL(fileURLWithPath: expandedPath, relativeTo: rootURL).standardizedFileURL
        }

        return URL(fileURLWithPath: expandedPath).standardizedFileURL
    }
}
