import Foundation
import ProviderMessage

/// 工具调用参数展示文本的准备入口（Issue #1186）。
///
/// 历史上「调用参数」弹层在 SwiftUI 计算属性里同步 `formatToolCallArguments`：
/// 整段 payload 的 trim + UTF-8 转换 + `JSONSerialization` 对象图 + 排序美化
/// 序列化全部跑在主 actor 上，且每次 body 求值都重付一遍。大参数（结构化
/// write/edit 请求）会直接卡住弹层呈现与无关滚动。
///
/// 这里把格式化搬到后台，并按「工具调用 id + 参数版本」缓存结果：
/// body 只渲染已经准备好的值，不再解析/序列化任何 payload。
enum ToolCallArgumentsFormatting {

    /// 准备结果。
    enum Outcome {
        /// 可展示的文本；`nil` 表示没有可显示参数（空串 / `{}`）。
        case ready(String?)
        /// await 期间身份已变（切了工具调用或参数已流式更新）：
        /// 调用方必须丢弃，不写任何状态。
        case stale
    }

    /// 缓存注入点：生产用进程级共享缓存，测试用独立实例隔离。
    @TaskLocal static var cache: ToolCallArgumentsFormatCache = .shared

    /// 格式化注入点：默认走既有 helper，测试可计数并断言所在 executor。
    @TaskLocal static var formatter: @Sendable (String) -> String? = {
        MessageViewHelpers.formatToolCallArguments($0)
    }

    /// 准备参数展示文本。
    ///
    /// - Parameter isStillCurrent: 后台格式化结束后、写回缓存前的身份校验
    ///   （捕获身份 → await → 写回前比对）。返回 false 时结果为 `.stale`，
    ///   既不写缓存也不交给调用方。
    @MainActor
    static func prepare(
        id: String,
        arguments: String,
        isStillCurrent: @MainActor @Sendable () -> Bool
    ) async -> Outcome {
        // 命中缓存无需后台格式化，也不存在 await 期间的身份变化。
        if let entry = cache.entry(for: id, arguments: arguments) {
            return .ready(entry.formatted)
        }

        let formatter = Self.formatter
        let formatted = await Task.detached(priority: .userInitiated) {
            formatter(arguments)
        }.value

        guard isStillCurrent() else { return .stale }
        cache.store(formatted, for: id, arguments: arguments)
        return .ready(formatted)
    }
}

/// 参数格式化结果的进程级缓存（锁保护、有界、按参数版本校验）。
///
/// 同一次调用的参数在落库后不变，但流式期间会持续追加：条目保存原始
/// `arguments`，命中时比对版本，避免把旧版本的美化结果当成新参数展示。
final class ToolCallArgumentsFormatCache: @unchecked Sendable {
    static let shared = ToolCallArgumentsFormatCache()

    struct Entry {
        let arguments: String
        let formatted: String?
    }

    private let limit: Int
    private let lock = NSLock()
    private var storage: [String: Entry] = [:]
    private var insertionOrder: [String] = []

    init(limit: Int = 32) {
        self.limit = max(1, limit)
    }

    /// 命中且参数版本一致时返回条目；否则 nil。
    func entry(for id: String, arguments: String) -> Entry? {
        lock.lock()
        let cached = storage[id]
        lock.unlock()

        // 版本比对在锁外：大 payload 的字符串比对不该阻塞并发查询。
        guard let cached, cached.arguments == arguments else { return nil }
        return cached
    }

    func store(_ formatted: String?, for id: String, arguments: String) {
        lock.lock()
        defer { lock.unlock() }
        if storage[id] == nil {
            insertionOrder.append(id)
        }
        storage[id] = Entry(arguments: arguments, formatted: formatted)
        if insertionOrder.count > limit {
            let overflow = insertionOrder.count - limit
            for key in insertionOrder.prefix(overflow) {
                storage.removeValue(forKey: key)
            }
            insertionOrder.removeFirst(overflow)
        }
    }

    /// 清空（测试与诊断用）。
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
        insertionOrder.removeAll()
    }
}