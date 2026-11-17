import AppKit

/// 按路径缓存 workspace 图标（#1223）。
///
/// Directory Tree / Large Files / Cache Cleaner 的行视图过去在 SwiftUI `body`
/// 的计算属性里直接调用 `NSWorkspace.shared.icon(forFile:)`，每次 body 重新求值
/// （选中、删除确认、进度刷新等）都会重复同一次同步 workspace 查询。
///
/// 该缓存让每条路径在图标生命周期内至多支付一次查询，并在视图模型发布结果时
/// 预取，把查询移出渲染路径。`NSImage` 只存在于这个 MainActor 缓存里，
/// 不进入 `Sendable` 数据模型。
@MainActor
final class WorkspaceIconCache {
    static let shared = WorkspaceIconCache()

    private let lookup: (String) -> NSImage
    private let limit: Int
    private var storage: [String: NSImage] = [:]
    /// 插入顺序，用于超出上限时按 FIFO 淘汰，避免无界增长。
    private var order: [String] = []

    init(
        limit: Int = 512,
        lookup: @escaping (String) -> NSImage = { NSWorkspace.shared.icon(forFile: $0) }
    ) {
        self.limit = max(1, limit)
        self.lookup = lookup
    }

    /// 返回路径对应的图标；命中缓存时不再触发 workspace 查询。
    func icon(forPath path: String) -> NSImage {
        if let cached = storage[path] {
            return cached
        }
        let image = lookup(path)
        storage[path] = image
        order.append(path)
        if order.count > limit {
            let overflow = order.count - limit
            for key in order.prefix(overflow) {
                storage.removeValue(forKey: key)
            }
            order.removeFirst(overflow)
        }
        return image
    }

    /// 在结果发布时预取图标，使首次查询发生在渲染路径之外。
    func prefetch(paths: [String]) {
        for path in paths {
            _ = icon(forPath: path)
        }
    }

    func removeAll() {
        storage.removeAll()
        order.removeAll()
    }
}