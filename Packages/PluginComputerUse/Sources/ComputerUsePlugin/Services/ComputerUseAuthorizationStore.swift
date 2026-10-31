import Foundation

/// ComputerUse 插件的授权白名单存储。
///
/// 这是「允许哪些 App 使用电脑控制」这份数据的**唯一所有者**：设置界面、
/// 原生控制协调器等都通过它读写，避免多处持有独立持久化后端写同一份事实。
///
/// 落盘在插件专属目录下的 Binary Plist（见 `computer_use.json` 迁移说明）。
final class ComputerUseAuthorizationStore: @unchecked Sendable {
    static let shared = ComputerUseAuthorizationStore()

    private let lock = NSLock()
    private let store: PlistBackedStringArrayStore

    private init() {
        store = PlistBackedStringArrayStore(
            dataDirectory: ComputerUseRuntime.settingsDirectory(),
            fileName: "authorization.plist"
        )
    }

    /// 测试用：以临时目录构造隔离实例。
    init(dataDirectory: URL) {
        store = PlistBackedStringArrayStore(
            dataDirectory: dataDirectory,
            fileName: "authorization.plist"
        )
    }

    // MARK: - 显式授权白名单（工具/设置界面使用）

    func allowedBundleIdentifiers() -> Set<String> {
        store.read { Set($0[Self.allowedKey] ?? []) }
    }

    func isAllowed(_ bundleIdentifier: String) -> Bool {
        allowedBundleIdentifiers().contains(bundleIdentifier)
    }

    func setAllowed(_ allowed: Bool, bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty else { return }
        store.update { plist in
            var values = Set(plist[Self.allowedKey] ?? [])
            if allowed {
                values.insert(bundleIdentifier)
            } else {
                values.remove(bundleIdentifier)
            }
            plist[Self.allowedKey] = values.sorted()
            // 取消显式授权时同时撤销原生控制授权，保持两者语义一致。
            if !allowed {
                plist[Self.nativeKey] = (plist[Self.nativeKey] ?? []).filter { $0 != bundleIdentifier }
                // 显式授权被撤销时，一次性授权也必须失效：
                // 否则「撤销」后旧的临时授权仍会让 agent 继续访问该应用。
                Self.removeOneShot(&plist, bundleIdentifier: bundleIdentifier)
            }
        }
    }

    // MARK: - 一次性授权（聊天内授权卡片使用）

    /// 授予一次性的应用访问权。
    ///
    /// 与 `setAllowed(true, ...)` 的区别：一次性授权**不写入显式白名单**，
    /// 只在 `oneShot` 列表里登记一个带过期时间的条目。到期后自动失效。
    ///
    /// - Parameters:
    ///   - bundleIdentifier: 目标应用。
    ///   - ttl: 有效期，默认 5 分钟。授权本次操作后即失效是更严格的选择。
    func grantOneShot(bundleIdentifier: String, ttl: TimeInterval = ComputerUseAuthorizationStore.defaultOneShotTTL) {
        guard !bundleIdentifier.isEmpty else { return }
        let expiry = Date().addingTimeInterval(ttl)
        store.update { plist in
            var entries = Self.oneShotEntries(plist)
            entries[bundleIdentifier] = expiry
            Self.writeOneShotEntries(entries, into: &plist)
        }
    }

    /// 消费一次性授权：存在且未过期时返回 `true`，并立即清除该条目。
    ///
    /// 「允许一次」的语义是**仅本次操作**，因此授权在检查时即被消费，
    /// 下一次操作必须重新申请。
    func consumeOneShot(bundleIdentifier: String) -> Bool {
        guard !bundleIdentifier.isEmpty else { return false }
        var consumed = false
        store.update { plist in
            var entries = Self.oneShotEntries(plist)
            // `oneShotEntries` 读取时已经过滤掉过期项，因此只要条目存在就有效。
            if entries.removeValue(forKey: bundleIdentifier) != nil {
                consumed = true
            }
            // 无论是否命中都回写：过期条目在这一步被一并清掉，不会无限累积。
            Self.writeOneShotEntries(entries, into: &plist)
        }
        return consumed
    }

    /// 查询一次性授权是否仍然有效（不消费）。
    func hasValidOneShot(bundleIdentifier: String) -> Bool {
        guard !bundleIdentifier.isEmpty else { return false }
        return store.read { Self.oneShotEntries($0)[bundleIdentifier] != nil }
    }

    /// 清理全部过期的一次性授权。
    func purgeExpiredOneShots() {
        store.update { plist in
            // `oneShotEntries` 读取时已经过滤掉过期项，直接回写即可完成清理。
            Self.writeOneShotEntries(Self.oneShotEntries(plist), into: &plist)
        }
    }

    /// 从 plist 中移除某个应用的一次性授权。
    private static func removeOneShot(_ plist: inout [String: [String]], bundleIdentifier: String) {
        var entries = oneShotEntries(plist)
        entries.removeValue(forKey: bundleIdentifier)
        writeOneShotEntries(entries, into: &plist)
    }

    /// 读取一次性授权条目。**已过期的条目不会返回。**
    ///
    /// plist 顶层 key 映射到字符串数组，因此这里把每个条目编码成
    /// `bundleIdentifier|过期时间戳` 一行存放。
    private static func oneShotEntries(_ plist: [String: [String]]) -> [String: Date] {
        let now = Date()
        var result: [String: Date] = [:]
        let stored: [String] = plist[oneShotKey] ?? []
        for row in stored {
            let parts = row.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let timestamp = TimeInterval(parts[1]) else { continue }
            let expiry = Date(timeIntervalSince1970: timestamp)
            guard expiry > now else { continue }
            result[parts[0]] = expiry
        }
        return result
    }

    /// 把一次性授权条目写回 plist。
    private static func writeOneShotEntries(
        _ entries: [String: Date],
        into plist: inout [String: [String]]
    ) {
        guard !entries.isEmpty else {
            plist.removeValue(forKey: oneShotKey)
            return
        }
        var rows: [String] = []
        for (key, expiry) in entries {
            rows.append("\(key)|\(expiry.timeIntervalSince1970)")
        }
        plist[oneShotKey] = rows.sorted()
    }

    // MARK: - 原生控制授权白名单（NativeControlCoordinator 使用）

    func isNativeAllowed(_ bundleIdentifier: String) -> Bool {
        store.read { ($0[Self.nativeKey] ?? []).contains(bundleIdentifier) }
    }

    func setNativeAllowed(_ allowed: Bool, bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty else { return }
        store.update { plist in
            var values = Set(plist[Self.nativeKey] ?? [])
            if allowed {
                values.insert(bundleIdentifier)
            } else {
                values.remove(bundleIdentifier)
            }
            plist[Self.nativeKey] = values.sorted()
        }
    }

    func revokeNative(_ bundleIdentifier: String) {
        setNativeAllowed(false, bundleIdentifier: bundleIdentifier)
    }

    // MARK: - Keys

    private static let allowedKey = "ComputerUse.alwaysAllowedBundleIdentifiers"
    private static let nativeKey = "ComputerUse.nativeAllowedBundleIdentifiers"

    /// 一次性授权条目。值为该条目的过期时间戳（Unix 时间，字符串形式）。
    ///
    /// 与显式白名单分开存放：一次性授权不应出现在设置界面的白名单里，
    /// 也不应在应用重启后长期存活。
    private static let oneShotKey = "ComputerUse.oneShotBundleIdentifiers"

    /// 一次性授权的默认有效期。
    ///
    /// 卡片上的「允许一次」语义是「本次操作」，因此真正生效的是
    /// `consumeOneShot` 的消费语义；TTL 只是兜底，防止用户点了卡片但
    /// 工具没有立刻继续执行时，授权长期悬在存储里。
    static let defaultOneShotTTL: TimeInterval = 300
}

// MARK: - Plist Backed Storage

/// 以 Binary Plist 持久化 `[String: [String]]` 结构的最小存储。
///
/// 仅服务于白名单这类小规模字符串集合，串行队列保证 read-modify-write 原子性。
private struct PlistBackedStringArrayStore: @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.coffic.lumi.plugin.computer-use.store", qos: .userInitiated)

    init(dataDirectory: URL, fileName: String) {
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        fileURL = dataDirectory.appendingPathComponent(fileName)
    }

    func read<T>(_ transform: ([String: [String]]) -> T) -> T {
        queue.sync { transform(readDict()) }
    }

    func update(_ transform: (inout [String: [String]]) -> Void) {
        queue.sync {
            var dict = readDict()
            transform(&dict)
            writeDict(dict)
        }
    }

    private func readDict() -> [String: [String]] {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any]
        else {
            return [:]
        }
        return dict.reduce(into: [String: [String]]()) { result, entry in
            if let values = entry.value as? [String] {
                result[entry.key] = values
            }
        }
    }

    private func writeDict(_ dict: [String: [String]]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
