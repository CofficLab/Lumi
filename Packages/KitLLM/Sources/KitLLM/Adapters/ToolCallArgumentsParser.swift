import Foundation

/// 工具调用参数的解析结果缓存。
///
/// ## 要解决的问题
///
/// 每个 LLM step 都会重新解析**全部历史**工具调用的 `arguments`：
///
/// - 协议适配器的 `validateToolCallArguments` 逐条 `JSONSerialization.jsonObject`；
/// - Anthropic 适配器在拼 `tool_use` 块时**再解析一遍**同一批参数。
///
/// 实测（Debug 构建，1 MB 参数 —— 工具把截图塞进参数并不罕见）：
///
/// | 操作 | 耗时 |
/// |---|---|
/// | `JSONSerialization.jsonObject`（1 MB） | 3.57 ms |
/// | `JSONSerialization.jsonObject`（20 KB） | 0.053 ms |
/// | `String ==`（1 MB，不同实例 memcmp） | 0.03 ms |
/// | `String ==`（同一实例，COW 快速路径） | 0.0002 ms |
///
/// 一次工具循环有多个 step，每个 step 都重付这份开销，且历史越��开销越大。
///
/// ## 缓存键为什么不是参数字符串
///
/// `dict[String]` 的查找要对键求哈希，是 O(参数长度)：实测 1 MB 的键要
/// 1.32 ms，**比重新解析还慢**。因此键用工具调用 ID（短字符串，O(1)
/// 哈希），再用参数字符串本身做二次校验（`==` 只需 memcmp，比解析便宜
/// 两个数量级）。
///
/// 代价是同一 ID 的参数被改动后需要重新解析——但这本来就该重新解析。
final class ToolCallArgumentsParser: @unchecked Sendable {

    // MARK: - 类型

    /// 一次参数解析的结果。
    ///
    /// `object` 为 `nil` 表示参数不是合法 JSON 对象。
    ///
    /// 用 `@unchecked Sendable` 包裹 `[String: Any]`：JSON 对象本身不可
    /// `Sendable`（`Any` 无并发保证），但它一旦解析出来就不再被修改，
    /// 跨线程传递是安全的。
    final class ParsedArguments: @unchecked Sendable {
        /// 解析所依据的原始参数字符串，用于缓存命中前的二次校验。
        let source: String
        /// 解析出的 JSON 对象；`nil` 表示参数非法。
        let object: [String: Any]?

        init(source: String, object: [String: Any]?) {
            self.source = source
            self.object = object
        }

        /// 参数是否为合法的 JSON 对象。
        var isValid: Bool { object != nil }
    }

    // MARK: - 常量

    /// 最多缓存多少条工具调用的解析结果。
    ///
    /// 一次会话的历史工具调用数量通常远小于这个量级；超出后按 LRU 淘汰。
    static let defaultMaxEntries = 256

    /// 缓存的参数字符串总长度上限。
    ///
    /// 缓存里保留的是原始参数字符串（用于二次校验），大参数会占用可观
    /// 内存，因此按总长度收敛。
    static let defaultMaxTotalSourceCharacters = 8 * 1024 * 1024

    // MARK: - 属性

    private let lock = NSLock()
    /// 工具调用 ID → 解析结果。
    private var entries: [String: ParsedArguments] = [:]
    /// 访问顺序计数器（值越大表示最近被访问），用于 LRU 淘汰。
    private var accessOrder: [String: Int] = [:]
    private var totalSourceCharacters = 0
    private let maxEntries: Int
    private let maxTotalSourceCharacters: Int

    // MARK: - 初始化

    init(
        maxEntries: Int = ToolCallArgumentsParser.defaultMaxEntries,
        maxTotalSourceCharacters: Int = ToolCallArgumentsParser.defaultMaxTotalSourceCharacters
    ) {
        self.maxEntries = max(1, maxEntries)
        self.maxTotalSourceCharacters = max(1, maxTotalSourceCharacters)
    }

    // MARK: - 公开方法

    /// 解析工具调用参数，命中缓存时复用既有结果。
    ///
    /// - Parameters:
    ///   - id: 工具调用 ID（缓存键）。
    ///   - arguments: 原始参数字符串。
    /// - Returns: 解析结果；`object` 为 `nil` 表示参数不是合法 JSON 对象。
    func parse(id: String, arguments: String) -> ParsedArguments {
        lock.lock()
        defer { lock.unlock() }

        if let cached = entries[id], cached.source == arguments {
            touch(id)
            return cached
        }

        let parsed = ParsedArguments(source: arguments, object: Self.parseObject(arguments))
        store(id: id, parsed: parsed)
        return parsed
    }

    /// 校验工具调用参数，语义与 `LLMToolCall.validateArguments()` 一致。
    func validate(_ toolCall: LLMToolCall) throws {
        let parsed = parse(id: toolCall.id, arguments: toolCall.arguments)
        guard parsed.isValid else {
            throw LLMToolCallValidationError.invalidArguments(
                toolCallID: toolCall.id,
                toolName: toolCall.name
            )
        }
    }

    /// 清空缓存。
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        accessOrder.removeAll()
        totalSourceCharacters = 0
    }

    /// 当前缓存的条目数（供测试与诊断使用）。
    var entryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    // MARK: - 私有方法

    /// 解析 JSON 对象。非法输入返回 `nil`。
    private static func parseObject(_ arguments: String) -> [String: Any]? {
        guard let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is [String: Any] else {
            return nil
        }
        return object as? [String: Any]
    }

    /// 记录一次访问（计数越大表示最近被访问）。
    private func touch(_ id: String) {
        accessOrder[id] = (accessOrder[id] ?? 0) + 1
    }

    /// 写入新条目，并按双上限淘汰旧条目。
    private func store(id: String, parsed: ParsedArguments) {
        if let existing = entries[id] {
            totalSourceCharacters -= existing.source.count
        }
        entries[id] = parsed
        totalSourceCharacters += parsed.source.count
        touch(id)
        evictIfNeeded()
    }

    /// 超出上限时淘汰最久未访问的条目。
    private func evictIfNeeded() {
        while entries.count > maxEntries || totalSourceCharacters > maxTotalSourceCharacters {
            guard let oldest = accessOrder.min(by: { $0.value < $1.value })?.key else { break }
            accessOrder[oldest] = nil
            guard let evicted = entries.removeValue(forKey: oldest) else { continue }
            totalSourceCharacters -= evicted.source.count
        }
        if totalSourceCharacters < 0 { totalSourceCharacters = 0 }
    }
}
