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
            }
        }
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
