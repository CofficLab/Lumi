import AppKit

/// 分区枚举
enum Section: Int, CaseIterable, Hashable {
    case main
}

/// 文件树 Diffable Data Source 类型别名
typealias FileTreeDiffableDataSource = NSCollectionViewDiffableDataSource<Section, FileTreeNodeItem>
