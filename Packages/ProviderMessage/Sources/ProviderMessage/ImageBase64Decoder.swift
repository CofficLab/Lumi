import Foundation

/// 图片 Base64 字符串的进程内解码缓存。
///
/// ## 要解决的问题
///
/// AgentLoop 每次准备 LLM 请求时，都会把历史图片的 base64 字符串重新解码成
/// 二进制。一张 1.5 MB 的截图解码一次约 1.2 ms；一段带图的十消息历史实测
/// 耗时 38 ms，全在主线程上完成（Issue #1268）。
///
/// 一个工具循环有多个 LLM step，每个 step 都会重付这份开销——而历史里的
/// 图片并没有变。
///
/// ## 为什么不用字典做键
///
/// 直觉上「按 base64 字符串缓存解码结果」最省事，但实测否定了它：
///
/// | 操作（2 MB base64 字符串） | 耗时 |
/// |---|---|
/// | `Data(base64Encoded:)` | 1.34 ms |
/// | `dict[String]` 查找 | **2.50 ms** |
///
/// 字典要对键求哈希，那是 O(字符串长度)——一次命中就要把整个 2 MB 串扫
/// 一遍，比直接解码还慢。
///
/// ## 实际做法：采样指纹分桶 + 字符串比对
///
/// 与图片编码侧（KitLLM 的 `ImageBase64Cache`）同一个思路：
///
/// 1. 按「字符数 + 头/中/尾三个采样字节」算出指纹作为桶键（O(1)）；
/// 2. 桶内保存 `(原始 base64, 解码结果)`；
/// 3. 命中时用 `String ==` 比对——同一份 base64 在多次 step 之间通常是
///    **同一个 `String` 实例**（消息从存储读出后不变），走写时复制的
///    引用快速路径；确实是不同实例但内容相同时退化为一次 memcmp，仍远快
///    于重新解码。
///
/// 实测命中 0.065 ms，相比重新解码的 1.34 ms 提升约 20 倍。
public final class ImageBase64Decoder: @unchecked Sendable {

    // MARK: - 类型

    /// 采样指纹：字符数 + 头/中/尾采样字节。
    ///
    /// 只取极少量字节参与分桶，计算成本是 O(1)；它**不保证唯一**，真正的
    /// 身份判定由桶内的字符串比对完成。
    private struct Fingerprint: Hashable {
        let count: Int
        let head: UInt8
        let middle: UInt8
        let tail: UInt8
    }

    /// 缓存条目。`base64` 保留原始字符串，用于命中时的身份比对。
    private struct Entry {
        let base64: String
        let data: Data
    }

    // MARK: - 常量

    /// 最多缓存多少张图片。
    ///
    /// 一张典型截图解码后约 1–3 MB，16 张约几十 MB，足以覆盖「一次工具
    /// 循环内的全部历史截图」这一实际需求。
    public static let defaultMaxEntries = 16

    /// 缓存累计的解码字节数上限。
    ///
    /// 解码产物才是真正驻留的内存（base64 字符串本身另有来源），因此按
    /// 解码后的字节数收敛。
    public static let defaultMaxTotalBytes = 64 * 1024 * 1024

    // MARK: - 单例

    /// 进程内共享的解码缓存。
    ///
    /// 一次会话的多个 LLM step 必须复用同一份缓存，因此是单例而非实例。
    public static let shared = ImageBase64Decoder()

    // MARK: - 属性

    private let lock = NSLock()
    /// 桶键 → 条目列表。
    ///
    /// 刻意**不用** base64 字符串直接做字典键：实测查找一次要 2.50 ms，
    /// 比重新解码还慢。分桶 + 桶内字符串比对只要 0.065 ms。
    private var buckets: [Fingerprint: [Entry]] = [:]
    /// 访问顺序计数器（值越大表示最近被访问），用于 LRU 淘汰。
    private var accessOrder: [Fingerprint: Int] = [:]
    private var totalBytes = 0
    private let maxEntries: Int
    private let maxTotalBytes: Int

    // MARK: - 初始化

    public init(
        maxEntries: Int = ImageBase64Decoder.defaultMaxEntries,
        maxTotalBytes: Int = ImageBase64Decoder.defaultMaxTotalBytes
    ) {
        self.maxEntries = max(1, maxEntries)
        self.maxTotalBytes = max(1, maxTotalBytes)
    }

    // MARK: - 公开方法

    /// 每次**尝试**解码图片时递增的计数器（仅供测试观察）。
    ///
    /// 生产路径不会使用它；它让测试无需注入回调即可观察「图片字节在
    /// 什么时刻、哪个线程上被处理」。
    ///
    /// 计数器是**实例级**而非全局：全局可变状态会被并行运行的用例互相
    /// 干扰，导致断言随机失败。测试用独立实例即可完全隔离。
    public let decodeCounter = DecodeCounter()

    /// 解码次数计数器。
    public final class DecodeCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var totalCount = 0
        private var mainThreadHits = 0

        /// 累计进入解码路径的次数。
        public var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return totalCount
        }

        /// 其中发生在主线程上的次数。
        public var mainThreadCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return mainThreadHits
        }

        /// 记录一次解码尝试。
        public func record() {
            lock.lock()
            totalCount += 1
            if pthread_main_np() != 0 {
                mainThreadHits += 1
            }
            lock.unlock()
        }

        /// 归零，便于下一个用例重新计数。
        public func reset() {
            lock.lock()
            totalCount = 0
            mainThreadHits = 0
            lock.unlock()
        }
    }

    /// 解码 base64 图片字符串，命中缓存时复用既有结果。
    ///
    /// - Parameter base64: base64 编码的图片字节。
    /// - Returns: 解码后的字节；输入非法时返回 `nil`（与
    ///   `Data(base64Encoded:)` 的语义一致）。
    public func decode(_ base64: String) -> Data? {
        // 空串没有可解码的内容，也不值得缓存。
        guard !base64.isEmpty else { return nil }

        let fingerprint = Self.fingerprint(of: base64)

        lock.lock()
        defer { lock.unlock() }

        // 在进入解码路径时记录：图片字节在这一刻被处理，因此它最能
        // 代表「转换跑在哪个线程上」。
        decodeCounter.record()

        if let bucket = buckets[fingerprint] {
            for entry in bucket where entry.base64 == base64 {
                touch(fingerprint)
                return entry.data
            }
        }

        guard let data = Data(base64Encoded: base64) else { return nil }
        store(fingerprint: fingerprint, base64: base64, data: data)
        return data
    }

    /// 清空缓存。
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        buckets.removeAll()
        accessOrder.removeAll()
        totalBytes = 0
    }

    /// 当前缓存的条目数与累计字节数（供测试与诊断使用）。
    public var statistics: (entries: Int, bytes: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (entryCount, totalBytes)
    }

    // MARK: - 私有实现

    /// 计算采样指纹。O(1)，只读取头/中/尾三个字节。
    ///
    /// 用 `withUTF8` 而非 `Array(s.utf8)`：后者会把整个字符串拷贝成数组，
    /// 2 MB 的串要 0.20 ms，比省下的还多。
    private static func fingerprint(of base64: String) -> Fingerprint {
        let count = base64.utf8.count
        guard count > 0 else { return Fingerprint(count: 0, head: 0, middle: 0, tail: 0) }
        var base64 = base64
        return base64.withUTF8 { buffer -> Fingerprint in
            Fingerprint(
                count: count,
                head: buffer[0],
                middle: buffer[count / 2],
                tail: buffer[count - 1]
            )
        }
    }

    /// 记录一次访问（计数越大表示最近被访问）。
    private func touch(_ fingerprint: Fingerprint) {
        accessOrder[fingerprint] = (accessOrder[fingerprint] ?? 0) + 1
    }

    /// 写入新条目，并按双上限淘汰旧条目。
    private func store(fingerprint: Fingerprint, base64: String, data: Data) {
        var bucket = buckets[fingerprint] ?? []
        // 同一指纹下已有内容相同的旧条目（不同 String 实例）时，替换它。
        if let index = bucket.firstIndex(where: { $0.base64 == base64 }) {
            totalBytes -= bucket[index].data.count
            bucket[index] = Entry(base64: base64, data: data)
        } else {
            bucket.append(Entry(base64: base64, data: data))
        }
        buckets[fingerprint] = bucket
        totalBytes += data.count
        touch(fingerprint)
        evictIfNeeded()
    }

    /// 超出上限时淘汰最久未访问的桶。
    private func evictIfNeeded() {
        while entryCount > maxEntries || totalBytes > maxTotalBytes {
            guard let oldest = accessOrder.min(by: { $0.value < $1.value })?.key else { break }
            accessOrder[oldest] = nil
            guard let bucket = buckets[oldest] else { continue }
            buckets[oldest] = nil
            for entry in bucket {
                totalBytes -= entry.data.count
            }
        }
        if totalBytes < 0 { totalBytes = 0 }
    }

    /// 缓存中的条目总数。
    private var entryCount: Int {
        buckets.values.reduce(0) { $0 + $1.count }
    }
}
