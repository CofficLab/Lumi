import Foundation

/// Computer Use 的授权存储。
///
/// ## 现在存什么
///
/// 只剩两类数据：
///
/// 1. **会话作用域的访问授权**（`grantKey`）：A2 会话里用户点过「允许」
///    之后，该 App 在**本会话内**不再打扰。键是 `会话ID|bundleID`。
/// 2. **原生控制授权**（`nativeKey`）：原生鼠标键盘独占授权。这不是应用白名单，
///    而是「Lumi 现在要接管你的鼠标键盘」的运行时确认，且用户随时可以在
///    桌面横幅上停止并撤销。
///
/// ## 不再存什么
///
/// **显式应用白名单**（旧 `allowedKey`）已删除。它要求用户逐个 App 手工维护，
/// 与会话的自动化等级重复表达同一件事，却多出一份需要长期同步的持久状态。
/// 现在应用访问权由会话等级决定：
///
/// - A3：完全放行，不打扰；
/// - A2：会话内授权一次即可。
///
/// 旧数据通过 `ComputerUsePlugin.migrateData` 清理（见该文件的迁移说明）。
final class ComputerUseAuthorizationStore: @unchecked Sendable {
    static let shared = ComputerUseAuthorizationStore()

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

    // MARK: - 会话作用域的访问授权（聊天内授权卡片使用）

    /// 授予会话内的应用访问权。
    ///
    /// 与旧版「显式白名单」的区别有两处：
    /// 1. **不写入白名单**——授权只在本次会话内有效，不跨会话、不跨重启。
    /// 2. **按会话隔离**——A 会话里授权过的 App，不会让 B 会话也获得访问权。
    ///
    /// - Note: 授权**不会在检查时被消费**。一条授权要覆盖整个会话里的
    ///   多次访问（观察 → 操作 → 再验证）；如果在第一次检查时就消费掉，
    ///   紧接着的操作会被自己的授权挡下——用户明明点了允许，Agent 却
    ///   立刻收到「该应用未被允许」。授权的边界是**会话**，不是单次操作。
    ///
    /// - Parameters:
    ///   - bundleIdentifier: 目标应用。
    ///   - conversationID: 授权所属会话。
    ///   - ttl: 兜底有效期，默认 4 小时。会话结束才是真正的边界；
    ///     TTL 只是防止会话已删但授权仍悬在存储里。
    func grantSessionAccess(
        bundleIdentifier: String,
        conversationID: UUID,
        ttl: TimeInterval = ComputerUseAuthorizationStore.defaultGrantTTL
    ) {
        guard !bundleIdentifier.isEmpty else { return }
        let expiry = Date().addingTimeInterval(ttl)
        store.update { plist in
            var entries = Self.grantEntries(plist)
            entries[Self.grantKey(for: bundleIdentifier, conversationID: conversationID)] = expiry
            Self.writeGrantEntries(entries, into: &plist)
        }
    }

    /// 查询会话内授权是否有效（不消费）。
    func hasSessionAccess(bundleIdentifier: String, conversationID: UUID) -> Bool {
        guard !bundleIdentifier.isEmpty else { return false }
        return store.read {
            Self.grantEntries($0)[Self.grantKey(for: bundleIdentifier, conversationID: conversationID)] != nil
        }
    }

    /// 清理全部过期的会话授权。
    func purgeExpiredGrants() {
        store.update { plist in
            // `grantEntries` 读取时已经过滤掉过期项，直接回写即可完成清理。
            Self.writeGrantEntries(Self.grantEntries(plist), into: &plist)
        }
    }

    /// 清理指定会话的全部访问授权。
    ///
    /// 会话删除时调用：会话都没了，它的授权不该继续生效。
    func revokeSessionAccess(conversationID: UUID) {
        store.update { plist in
            var entries = Self.grantEntries(plist)
            let prefix = "\(conversationID.uuidString)|"
            entries = entries.filter { !$0.key.hasPrefix(prefix) }
            Self.writeGrantEntries(entries, into: &plist)
        }
    }

    /// 会话授权条目的键。
    ///
    /// 会话 ID 在前，保证 `revokeSessionAccess(conversationID:)` 能按前缀批量清理。
    private static func grantKey(for bundleIdentifier: String, conversationID: UUID) -> String {
        "\(conversationID.uuidString)|\(bundleIdentifier)"
    }

    /// 读取会话授权条目。**已过期的条目不会返回。**
    ///
    /// plist 顶层 key 映射到字符串数组，因此这里把每个条目编码成
    /// `会话ID|bundleID|过期时间戳` 一行存放。
    private static func grantEntries(_ plist: [String: [String]]) -> [String: Date] {
        let now = Date()
        var result: [String: Date] = [:]
        let stored: [String] = plist[grantKey] ?? []
        for row in stored {
            let parts = row.split(separator: "|", maxSplits: 2).map(String.init)
            guard parts.count == 3,
                  let timestamp = TimeInterval(parts[2]) else { continue }
            let expiry = Date(timeIntervalSince1970: timestamp)
            guard expiry > now else { continue }
            result["\(parts[0])|\(parts[1])"] = expiry
        }
        return result
    }

    /// 把会话授权条目写回 plist。
    private static func writeGrantEntries(
        _ entries: [String: Date],
        into plist: inout [String: [String]]
    ) {
        guard !entries.isEmpty else {
            plist.removeValue(forKey: grantKey)
            return
        }
        var rows: [String] = []
        for (key, expiry) in entries {
            rows.append("\(key)|\(expiry.timeIntervalSince1970)")
        }
        plist[grantKey] = rows.sorted()
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

    // MARK: - 迁移

    /// 清除旧版的显式应用白名单。
    ///
    /// 旧白名单不再参与任何判定，留着只会让用户以为自己还能在设置里
    /// 管理一份实际无效的名单。
    func purgeLegacyExplicitAllowlist() {
        store.update { plist in
            plist.removeValue(forKey: Self.legacyAllowedKey)
        }
    }

    // MARK: - Keys

    private static let nativeKey = "ComputerUse.nativeAllowedBundleIdentifiers"

    /// 旧版显式白名单的 plist key。仅用于迁移清理。
    static let legacyAllowedKey = "ComputerUse.alwaysAllowedBundleIdentifiers"

    /// 会话访问授权条目。值为该条目的过期时间戳（Unix 时间，字符串形式）。
    ///
    /// 与原生控制授权分开存放：会话授权不应出现在设置界面里，
    /// 也不应在应用重启后长期存活。
    private static let grantKey = "ComputerUse.sessionGrantBundleIdentifiers"

    /// 会话授权的兜底有效期。
    ///
    /// 真正的授权边界是「会话结束」；TTL 只是防止会话已删但授权仍悬在存储里。
    static let defaultGrantTTL: TimeInterval = 14400
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
