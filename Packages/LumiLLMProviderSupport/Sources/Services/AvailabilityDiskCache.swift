import Foundation
import LumiCoreKit

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
    public init(pluginName: String, cacheInterval: TimeInterval = 300) {
        self.cacheInterval = cacheInterval
        self.queue = DispatchQueue(
            label: "com.cofficlab.lumi.\(pluginName).availability.cache",
            qos: .utility
        )
        self.pluginDirectory = lumiCorePluginDataDirectory(for: pluginName)
            ?? lumiCoreFallbackDataRootDirectory.appendingPathComponent(pluginName, isDirectory: true)
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
