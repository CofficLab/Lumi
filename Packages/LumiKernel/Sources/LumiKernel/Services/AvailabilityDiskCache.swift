import Foundation

/// `AvailabilityDiskCache` 的目录解析器。
///
/// 各 LLM Provider 插件在自己的 `bootstrapFromLumiCoreIfNeeded` 里调
/// `set(pluginName:directory:)` 注入 plugin 专属目录,替代直接读 nonisolated 镜像。
/// AvailabilityDiskCache.init 从这里按 pluginName 取目录;未注入时走 fallback。
///
/// 之所以用 resolver 而非让每个 provider 直接传 URL 给 init:AvailabilityDiskCache
/// 是底层 package,被 18 个 provider 以 `private static let cache = ...` 形式各自实例化
/// (在 nonisolated 上下文 lazy 初始化),无法在 init 时拿到 @MainActor 的路径。
public enum AvailabilityDiskCacheDirectoryResolver {
    /// 锁保护下的 pluginName -> directory 映射。
    private static let lock = NSLock()
    private nonisolated(unsafe) static var directories: [String: URL] = [:]

    /// 由各 plugin 的 bootstrap 调用,注入 plugin 专属目录。
    /// - Parameters:
    ///   - pluginName: 插件目录名(与 AvailabilityDiskCache.init 的 pluginName 一致)。
    ///   - directory: 该插件的专属数据目录。
    public static func set(pluginName: String, directory: URL) {
        lock.lock()
        defer { lock.unlock() }
        directories[pluginName] = directory
    }

    /// AvailabilityDiskCache.init 调用,按 pluginName 取目录。
    /// 未注入时返回 nil(由调用方走 fallback)。
    public static func directory(for pluginName: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return directories[pluginName]
    }
}

/// 通用的模型可用性磁盘缓存
///
/// 为所有 LLM Provider 插件提供可复用的 5 分钟磁盘缓存。
/// 缓存以 JSON 格式存储在插件的专属数据目录中。
///
/// 存储路径: `<LumiCore.dataRootDirectory>/<pluginName>/availability_cache.json`
///
/// 使用示例:
/// ```swift
/// private let cache = AvailabilityDiskCache(pluginName: "LLMProviderZhipu")
///
/// func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
///     // 1. 检查缓存
///     if let cached = cache.read(model: model),
///        Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
///         return cached.result
///     }
///
///     // 2. 执行网络请求
///     let result = await performAvailabilityCheck(model: model)
///
///     // 3. 写入缓存
///     cache.write(model: model, result: result, timestamp: Date())
///     return result
/// }
/// ```
public final class AvailabilityDiskCache: @unchecked Sendable {
    /// 缓存有效期，默认 5 分钟
    public let cacheInterval: TimeInterval

    private let queue: DispatchQueue
    private let pluginDirectory: URL
    private let storeFileURL: URL

    /// 初始化缓存实例
    /// - Parameters:
    ///   - pluginName: 插件目录名，用于确定存储路径
    ///   - cacheInterval: 缓存有效期（秒），默认 300 秒（5 分钟）
    ///
    /// plugin 目录从 `AvailabilityDiskCacheDirectoryResolver` 取(由各 plugin bootstrap 注入);
    /// 未注入时走 fallback `<AppSupport>/<bundleID>/<pluginName>`。
    public init(pluginName: String, cacheInterval: TimeInterval = 300) {
        self.cacheInterval = cacheInterval
        self.queue = DispatchQueue(
            label: "com.cofficlab.lumi.\(pluginName).availability.cache",
            qos: .utility
        )
        // 优先走 resolver(由各 plugin 的 bootstrap 注入);未注入走 fallback。
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        let fallbackRoot = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        self.pluginDirectory = AvailabilityDiskCacheDirectoryResolver.directory(for: pluginName)
            ?? fallbackRoot.appendingPathComponent(pluginName, isDirectory: true)
        self.storeFileURL = pluginDirectory.appendingPathComponent("availability_cache.json")
    }

    /// 读取指定模型的缓存结果
    /// - Parameter model: 模型名称
    /// - Returns: 缓存的结果和时间戳，缓存不存在或已过期时返回 nil
    public func read(model: String) -> (result: LumiModelAvailabilityResult, timestamp: Date)? {
        queue.sync {
            let dict = readCacheDict()
            guard let entryDict = dict[model] as? [String: Any],
                  let timestamp = entryDict["timestamp"] as? TimeInterval,
                  let serializable = entryDict["result"] as? [String: Any],
                  let cachedResult = deserialize(result: serializable)
            else {
                return nil
            }
            return (cachedResult, Date(timeIntervalSince1970: timestamp))
        }
    }

    /// 写入模型可用性检测结果到磁盘
    /// - Parameters:
    ///   - model: 模型名称
    ///   - result: 可用性检测结果
    ///   - timestamp: 检测时间戳
    public func write(model: String, result: LumiModelAvailabilityResult, timestamp: Date) {
        guard let serializable = serialize(result: result) else { return }

        queue.async { [weak self, serializable] in
            guard let self else { return }
            // 确保插件目录存在
            try? FileManager.default.createDirectory(
                at: pluginDirectory,
                withIntermediateDirectories: true
            )
            var dict = readCacheDict()
            dict[model] = [
                "result": serializable,
                "timestamp": timestamp.timeIntervalSince1970,
            ]
            writeCacheDict(dict)
        }
    }

    // MARK: - Serialization

    private func serialize(result: LumiModelAvailabilityResult) -> [String: Any]? {
        switch result {
        case .available:
            return ["type": "available"]
        case .unavailable(let failure):
            return [
                "type": "unavailable",
                "summary": failure.summary,
                "httpStatusCode": failure.httpStatusCode as Any,
                "transportDetails": failure.transportDetails as Any,
                "reason": reasonString(from: failure.reason) as Any,
            ]
        }
    }

    private func reasonString(from reason: LumiLLMFailureReason?) -> String? {
        switch reason {
        case .unsupportedModel: return "unsupportedModel"
        case nil: return nil
        }
    }

    private func deserialize(reasonString: String?) -> LumiLLMFailureReason? {
        switch reasonString {
        case "unsupportedModel": return .unsupportedModel
        default: return nil
        }
    }

    private func deserialize(result dict: [String: Any]) -> LumiModelAvailabilityResult? {
        guard let type = dict["type"] as? String else { return nil }

        if type == "available" {
            return .available
        }

        if type == "unavailable", let summary = dict["summary"] as? String {
            let httpStatusCode = dict["httpStatusCode"] as? Int
            let transportDetails = dict["transportDetails"] as? String
            let reason = deserialize(reasonString: dict["reason"] as? String)
            return .unavailable(
                LumiLLMFailureDetail(
                    summary: summary,
                    httpStatusCode: httpStatusCode,
                    transportDetails: transportDetails,
                    reason: reason
                )
            )
        }

        return nil
    }

    // MARK: - Disk I/O

    private func readCacheDict() -> [String: Any] {
        guard FileManager.default.fileExists(atPath: storeFileURL.path),
              let data = try? Data(contentsOf: storeFileURL),
              let plist = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = plist as? [String: Any]
        else {
            return [:]
        }
        return dict
    }

    private func writeCacheDict(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return
        }

        let tmpURL = pluginDirectory.appendingPathComponent("availability_cache.tmp")

        do {
            try data.write(to: tmpURL, options: .atomic)
            if FileManager.default.fileExists(atPath: storeFileURL.path) {
                _ = try? FileManager.default.replaceItemAt(storeFileURL, withItemAt: tmpURL)
            } else {
                try FileManager.default.moveItem(at: tmpURL, to: storeFileURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }
}
