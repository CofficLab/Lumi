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
            // 工作区根必须按目录解析：不指定 isDirectory 时 URL(fileURLWithPath:)
            // 会 stat 磁盘，根不存在时被当作文件，相对路径落到父目录（#140）。
            let rootURL = URL(fileURLWithPath: workspaceRoot, isDirectory: true).standardizedFileURL
            return URL(fileURLWithPath: expandedPath, relativeTo: rootURL).standardizedFileURL
        }

        return URL(fileURLWithPath: expandedPath).standardizedFileURL
    }
}
