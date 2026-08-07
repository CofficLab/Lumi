import Foundation

/// 面包屑路径段数据模型
public struct BreadcrumbItem: Identifiable, Equatable {
    public let index: Int
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public var id: Int { index }

    /// 获取同级的兄弟文件/文件夹列表
    public var siblings: [BreadcrumbSibling] {
        let parentURL = url.deletingLastPathComponent()
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else { return [] }

        return
            contents
            .filter { $0.lastPathComponent != ".DS_Store" && $0.lastPathComponent != ".git" }
            .sorted { a, b in
                let aIsDir =
                    (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let bIsDir =
                    (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if aIsDir != bIsDir { return aIsDir }
                return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent)
                    == .orderedAscending
            }
            .map { url in
                let isDir =
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return BreadcrumbSibling(name: url.lastPathComponent, url: url, isDirectory: isDir)
            }
    }
}

/// 面包屑兄弟节点（用于下拉菜单列表）
public struct BreadcrumbSibling: Identifiable, Equatable {
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public var id: String { url.path }
}
