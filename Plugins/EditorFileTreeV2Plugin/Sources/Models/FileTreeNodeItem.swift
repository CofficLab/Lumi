import Foundation
import EditorFileTreePlugin
import SwiftUI
import LumiUI

/// 文件树节点的扁平化数据模型
///
/// 仅存储渲染所需的只读信息，不包含业务逻辑。
/// 用于 NSCollectionView 的 DiffableDataSource。
public struct FileTreeNodeItem: Hashable {
    /// 文件/目录的完整路径
    public let url: URL
    /// 缩进层级（0 = 根目录）
    public let depth: Int
    /// 是否为目录
    public let isDirectory: Bool
    /// 是否已展开（仅目录有效）
    public let isExpanded: Bool
    /// 图标元数据（避免重复计算）
    public let iconMetadata: FileTreeIconMetadata
    /// Git 相对路径
    public let gitRelativePath: String
    /// 文件名（不含路径）
    public let fileName: String
    /// 项目根路径
    public let projectRootPath: String

    public var id: URL { url }

    /// 默认初始化器（生产环境使用）
    public init(
        url: URL,
        depth: Int,
        isDirectory: Bool,
        isExpanded: Bool,
        projectRootPath: String
    ) {
        self.init(
            url: url,
            depth: depth,
            isDirectory: isDirectory,
            isExpanded: isExpanded,
            projectRootPath: projectRootPath,
            fileSystemReader: DefaultFileSystemReader()
        )
    }
    
    /// 可测试的初始化器（允许注入依赖）
    init(
        url: URL,
        depth: Int,
        isDirectory: Bool,
        isExpanded: Bool,
        projectRootPath: String,
        fileSystemReader: FileSystemReading
    ) {
        self.url = url
        self.depth = depth
        self.isDirectory = isDirectory
        self.isExpanded = isExpanded
        self.iconMetadata = FileTreeIconMetadata(
            fileName: url.lastPathComponent,
            fileExtension: url.pathExtension.lowercased(),
            isDirectory: isDirectory,
            isSwiftPackageDirectory: isDirectory && fileSystemReader.fileExists(
                atPath: url.appendingPathComponent("Package.swift").path
            )
        )
        self.gitRelativePath = PathFormatter.gitPath(for: url, projectRootPath: projectRootPath)
        self.fileName = url.lastPathComponent
        self.projectRootPath = projectRootPath
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(depth)
        hasher.combine(isExpanded)
    }

    public static func == (lhs: FileTreeNodeItem, rhs: FileTreeNodeItem) -> Bool {
        lhs.url == rhs.url && lhs.depth == rhs.depth && lhs.isExpanded == rhs.isExpanded
    }
}

/// 文件图标元数据
///
/// 预计算图标所需的文件信息，避免在 Cell 中重复解析。
public struct FileTreeIconMetadata {
    public let fileName: String
    public let fileExtension: String
    public let isDirectory: Bool
    public let isSwiftPackageDirectory: Bool

    public init(
        fileName: String,
        fileExtension: String,
        isDirectory: Bool,
        isSwiftPackageDirectory: Bool
    ) {
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.isDirectory = isDirectory
        self.isSwiftPackageDirectory = isSwiftPackageDirectory
    }
}
