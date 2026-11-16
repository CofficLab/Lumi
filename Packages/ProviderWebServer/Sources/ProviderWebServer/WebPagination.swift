import Foundation

// MARK: - Pagination

/// 分页参数。
///
/// 从 query string 解析，支持 `offset` + `limit` 两种风格。缺省值保证
/// 「不传参数」永远是一个安全的读取，不会意外拉取全量数据。
public struct WebPagination: Sendable, Equatable, Codable {
    /// 默认每页条数。
    public static let defaultLimit = 50
    /// 单页最大条数。防止调用方用 `limit=1000000` 拖垮服务。
    public static let maxLimit = 500

    /// 跳过的条目数。
    public let offset: Int
    /// 本页最多返回的条目数。
    public let limit: Int

    /// 构造分页参数。
    ///
    /// - Parameters:
    ///   - offset: 跳过的条目数，负值按 0 处理。
    ///   - limit: 每页条数，非法值回退到默认值，超过上限则截断。
    public init(offset: Int = 0, limit: Int = WebPagination.defaultLimit) {
        self.offset = max(0, offset)
        if limit <= 0 {
            self.limit = WebPagination.defaultLimit
        } else {
            self.limit = min(limit, WebPagination.maxLimit)
        }
    }

    /// 从查询参数解析分页。
    ///
    /// 识别 `offset` 与 `limit`（也兼容 `page` + `pageSize`：`page` 从 1 开始）。
    /// 非数字或负值一律回退到默认值，不报错——分页参数拼错不该让整个请求失败。
    ///
    /// - Parameter query: 查询参数。
    public init(query: [String: String]) {
        // 先解析 limit：`page` 风格计算 offset 时要用它作页长，
        // 否则 `page=3&pageSize=20` 会按默认页长算出错误的偏移。
        let limit: Int
        if let raw = query["limit"], let value = Int(raw), value > 0 {
            limit = value
        } else if let raw = query["pageSize"], let value = Int(raw), value > 0 {
            limit = value
        } else {
            limit = WebPagination.defaultLimit
        }

        let offset: Int
        if let raw = query["offset"], let value = Int(raw), value >= 0 {
            offset = value
        } else if let raw = query["page"], let value = Int(raw), value >= 1 {
            // page 可以是任意正 Int，`(value - 1) * limit` 可能溢出 Int；
            // Swift 的 trapping 算术会直接终止整个进程（#1161）。溢出时
            // 视同非法分页，回退到默认偏移，与其他非法参数的行为一致。
            let (product, overflow) = (value - 1).multipliedReportingOverflow(by: limit)
            offset = overflow ? 0 : product
        } else {
            offset = 0
        }

        self.init(offset: offset, limit: limit)
    }

    /// 对序列分页。
    ///
    /// - Parameter items: 完整序列。
    /// - Returns: 当前页的条目。
    public func page<T>(of items: [T]) -> [T] {
        guard offset < items.count else { return [] }
        let end = min(offset + limit, items.count)
        return Array(items[offset..<end])
    }
}

// MARK: - Paginated Response

/// 带分页元信息的响应体。
///
/// `items` 承载数据，`total` 是过滤后的总条数，调用方据此判断是否还有下一页。
public struct WebPageResult<Item: Encodable & Sendable>: Encodable, Sendable {
    /// 当前页数据。
    public let items: [Item]
    /// 过滤后的总条数。
    public let total: Int
    /// 本次请求的偏移量。
    public let offset: Int
    /// 本次请求的每页条数。
    public let limit: Int
    /// 是否还有下一页。
    public let hasMore: Bool

    /// 由完整序列构造分页结果。
    ///
    /// - Parameters:
    ///   - items: 完整（已过滤）的序列。
    ///   - pagination: 分页参数。
    public init(items: [Item], pagination: WebPagination) {
        self.items = pagination.page(of: items)
        self.total = items.count
        self.offset = pagination.offset
        self.limit = pagination.limit
        self.hasMore = pagination.offset + self.items.count < items.count
    }

    /// 由已分页的当前页数据与总数构造分页结果。
    ///
    /// 用于调用方已经在别处（如后台线程）完成切片、只想映射当前页的场景，
    /// 避免把完整序列再交给主线程处理一遍。
    ///
    /// - Parameters:
    ///   - pageItems: 当前页数据（调用方已按 `pagination` 切片）。
    ///   - total: 过滤后的总条数。
    ///   - pagination: 分页参数。
    public init(pageItems: [Item], total: Int, pagination: WebPagination) {
        self.items = pageItems
        self.total = total
        self.offset = pagination.offset
        self.limit = pagination.limit
        self.hasMore = pagination.offset + pageItems.count < total
    }
}

// MARK: - Request Log

/// 一次请求的日志记录。
///
/// 记录的是**元信息**（方法、路径、状态码、耗时），不含请求体与响应体——
/// 请求体可能包含文件内容、凭据等敏感数据。
public struct WebRequestLog: Sendable, Equatable {
    /// 本次请求的追踪 ID。同时会写入响应头 `X-Request-ID`。
    public let requestID: String
    /// HTTP 方法。
    public let method: String
    /// 请求路径（不含 query string）。
    public let path: String
    /// 命中路由的归属插件 ID；未命中任何路由时为 `nil`。
    public let pluginID: String?
    /// 响应状态码。
    public let statusCode: Int
    /// 处理耗时（秒）。
    public let duration: TimeInterval
    /// 触发时刻。
    public let timestamp: Date

    public init(
        requestID: String,
        method: String,
        path: String,
        pluginID: String? = nil,
        statusCode: Int,
        duration: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.requestID = requestID
        self.method = method
        self.path = path
        self.pluginID = pluginID
        self.statusCode = statusCode
        self.duration = duration
        self.timestamp = timestamp
    }
}

// MARK: - Request Log Sink

/// 请求日志的接收端。
///
/// 服务端在每次请求结束后调用它。实现可以是写磁盘、发到统一日志系统，
/// 或在设置页展示最近请求。
public protocol WebRequestLogSink: AnyObject, Sendable {
    /// 记录一次已完成的请求。
    func record(_ log: WebRequestLog)
}

// MARK: - In-Memory Request Log Sink

/// 内存中的请求日志接收端，保留最近 N 条记录。
///
/// 供设置页展示「最近请求」，也便于测试断言。默认容量 200 条。
public final class WebInMemoryRequestLogSink: WebRequestLogSink, @unchecked Sendable {
    /// 保留的最大条数。
    public let capacity: Int

    private let lock = NSLock()
    private var logs: [WebRequestLog] = []

    /// 创建内存日志接收端。
    ///
    /// - Parameter capacity: 保留的最大条数，默认 200。
    public init(capacity: Int = 200) {
        self.capacity = max(1, capacity)
    }

    /// 当前记录的条数。
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return logs.count
    }

    /// 最近的记录（最新在前）。
    public var recentLogs: [WebRequestLog] {
        lock.lock()
        defer { lock.unlock() }
        return logs
    }

    /// 清空记录。
    public func clear() {
        lock.lock()
        logs.removeAll()
        lock.unlock()
    }

    public func record(_ log: WebRequestLog) {
        lock.lock()
        logs.insert(log, at: 0)
        if logs.count > capacity {
            logs.removeLast(logs.count - capacity)
        }
        lock.unlock()
    }
}
