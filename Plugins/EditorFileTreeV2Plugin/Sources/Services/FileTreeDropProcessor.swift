import Foundation

/// 拖放处理纯函数
///
/// 把 `FileTreeCollectionViewController.handleDropFiles` 中的「判定 + 移动 + 收集副作用」拆出，
/// 仅依赖入参与可注入的 `isTargetDirectory` / `moveItem` 函数引用。这样：
/// - controller 端不重复实现判定与循环逻辑，行为收敛到这一处；
/// - 单元测试可在不构造 NSViewController / NSCollectionView 的前提下覆盖关键路径。
///
/// ## 用法
/// ```swift
/// let result = FileTreeDropProcessor.process(
///     enabled: EditorFileTreeV2Plugin.dragAndDropEnabled,
///     targetURL: targetDir,
///     sourceURLs: draggedURLs,
///     isTargetDirectory: { FileTreeFacade.isDirectory($0) },
///     moveItem: { FileTreeFacade.moveItem(from: $0, to: $1) }
/// )
/// switch result {
/// case .rejected: return
/// case .moved(let pairs, let affectedParents):
///     // 触发回调 / reload / 自动展开
/// }
/// ```
///
/// ## 设计要点
/// - **早返回**：`enabled == false`、target 非目录、sources 为空、或全部 move 失败时
///   返回 `.rejected`，调用方据此决定是否重置高亮/弹 toast。
/// - **去环**：`PathFormatter.topLevelURLs(from:)` 过滤掉嵌套子项，
///   避免把目录拖入自身子目录的死循环。
/// - **失败容错**：单个 source 移动失败（如跨设备、权限不足）不阻断其余 source，
///   汇总在 `movedPairs` 里交给 controller 决定后续处理。
/// - **收集父目录**：把 target 与每个 source 的 parent 加入 `affectedParents`，
///   让数据源做精准 reload 而不是全树 `fullRefresh`。
public enum FileTreeDropProcessor {

    /// 处理结果。
    public enum Result {
        /// 被拒绝：开关关闭 / target 非目录 / sources 为空 / 全部 move 失败。
        case rejected
        /// 处理成功；返回 (oldURL, newURL) 列表与受影响的父目录集合。
        case moved(pairs: [(old: URL, new: URL)], affectedParents: Set<URL>)
    }

    /// 执行拖放处理。
    ///
    /// - Parameters:
    ///   - enabled: 性能开关（通常来自插件常量 `EditorFileTreeV2Plugin.dragAndDropEnabled`）。
    ///   - targetURL: 目标目录的 URL。
    ///   - sourceURLs: 被拖拽文件 / 文件夹的 URL 列表。
    ///   - isTargetDirectory: 判定 URL 是否为目录的函数引用；用于注入以便测试。
    ///   - moveItem: 实际执行移动的函数引用；`FileTreeFacade.moveItem` 即可。
    /// - Returns: `.rejected` 或 `.moved(...)`，调用方据此决定后续动作。
    public static func process(
        enabled: Bool,
        targetURL: URL,
        sourceURLs: [URL],
        isTargetDirectory: (URL) -> Bool,
        moveItem: (_ sourcePath: String, _ destPath: String) -> URL?
    ) -> Result {
        guard enabled else { return .rejected }
        guard isTargetDirectory(targetURL) else { return .rejected }
        guard !sourceURLs.isEmpty else { return .rejected }

        // 用 PathFormatter.topLevelURLs 过滤掉嵌套子项，避免目标被拖入自身子目录的环。
        var pairs: [(old: URL, new: URL)] = []
        for sourceURL in PathFormatter.topLevelURLs(from: sourceURLs) {
            guard let newURL = moveItem(sourceURL.path, targetURL.path),
                  newURL != sourceURL else { continue }
            pairs.append((sourceURL, newURL))
        }

        guard !pairs.isEmpty else { return .rejected }

        // 收集被影响的目录路径
        var affectedParents: Set<URL> = [targetURL.standardizedFileURL]
        for (old, _) in pairs {
            affectedParents.insert(old.deletingLastPathComponent().standardizedFileURL)
        }

        return .moved(pairs: pairs, affectedParents: affectedParents)
    }
}
