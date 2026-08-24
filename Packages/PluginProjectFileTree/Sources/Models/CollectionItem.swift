import Foundation

/// 文件树集合视图的统一数据项枚举
///
/// 同时承载文件系统节点和 Swift Package 依赖节点，
/// 使两者共用同一个 NSCollectionViewDiffableDataSource，
/// 消除底部独立的「软件包依赖」区域，将依赖内联到文件树末尾。
public enum CollectionItem: Hashable {
    /// 文件系统节点（文件/目录）
    case file(FileTreeNodeItem)

    /// 软件包依赖「头部」节点（可展开/折叠）
    case packageHeader(PackageHeaderItem)

    /// 单个软件包依赖项
    case packageDependency(PackageDependencyNodeItem)

    public static func == (lhs: CollectionItem, rhs: CollectionItem) -> Bool {
        switch (lhs, rhs) {
        case (.file(let a), .file(let b)):
            return a == b
        case (.packageHeader(let a), .packageHeader(let b)):
            return a == b
        case (.packageDependency(let a), .packageDependency(let b)):
            return a == b
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .file(let item):
            hasher.combine(0)
            hasher.combine(item)
        case .packageHeader(let item):
            hasher.combine(1)
            hasher.combine(item)
        case .packageDependency(let item):
            hasher.combine(2)
            hasher.combine(item)
        }
    }

    /// 若为 `.file` 则返回其节点，否则返回 nil。便于上层对文件节点字段的统一解包访问。
    public var fileItem: FileTreeNodeItem? {
        if case .file(let item) = self { return item }
        return nil
    }
}

// MARK: - PackageHeaderItem

/// 软件包依赖区域的头部节点
///
/// 类似于目录节点，支持展开/折叠状态。
public struct PackageHeaderItem: Hashable {
    /// 固定的唯一标识
    public let id: String = "__package_dependencies_header__"
    /// 是否已展开
    public let isExpanded: Bool
    /// 依赖总数
    public let dependencyCount: Int
    /// 项目根路径（用于持久化展开状态）
    public let projectRootPath: String

    public static func == (lhs: PackageHeaderItem, rhs: PackageHeaderItem) -> Bool {
        lhs.id == rhs.id && lhs.isExpanded == rhs.isExpanded
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(isExpanded)
    }
}

// MARK: - PackageDependencyNodeItem

/// 单个软件包依赖的节点数据
///
/// 从 PackageDependency 派生，适配 CollectionView 渲染所需字段。
public struct PackageDependencyNodeItem: Hashable {
    /// 基于身份的唯一标识
    public let id: String
    /// 包显示名称
    public let displayName: String
    /// 版本/分支/revision 等子标题
    public let subtitle: String
    /// 本地路径（local 类型时有值）
    public let location: String
    /// 是否为本地包
    public let isLocal: Bool

    public init(dependency: PackageDependency) {
        self.id = "dep:\(dependency.identity)"
        self.displayName = dependency.displayName
        self.subtitle = dependency.subtitle
        self.location = dependency.location
        self.isLocal = dependency.kind == .local
    }

    public static func == (lhs: PackageDependencyNodeItem, rhs: PackageDependencyNodeItem) -> Bool {
        lhs.id == rhs.id && lhs.subtitle == rhs.subtitle
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(subtitle)
    }
}
