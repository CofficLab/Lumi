import Foundation

/// Activity Heatmap 插件的偏好存储。
///
/// `period` 此前存在 UserDefaults.standard；现落盘在插件专属目录
/// （Binary Plist），与插件其余数据保持一致。
public final class ActivityHeatmapPreferences: @unchecked Sendable {
    public static let periodKey = "com.coffic.activity-heatmap.period"

    private let queue = DispatchQueue(label: "com.coffic.lumi.plugin.activity-heatmap.prefs", qos: .userInitiated)
    private let fileURL: URL

    public init(settingsDirectory: URL) {
        try? FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        fileURL = settingsDirectory.appendingPathComponent("settings.plist")
    }

    /// 保存的原始周期值；nil 表示用户尚未修改过（沿用默认 days30）。
    public var storedPeriodRawValue: Int? {
        queue.sync { readDict()[Self.periodKey] as? Int }
    }

    /// 写入周期值；传 nil 表示清除记录。
    public func setStoredPeriodRawValue(_ value: Int?) {
        queue.sync {
            var dict = readDict()
            if let value {
                dict[Self.periodKey] = value
            } else {
                dict.removeValue(forKey: Self.periodKey)
            }
            writeDict(dict)
        }
    }

    // MARK: - 私有辅助

    private func readDict() -> [String: Any] {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any]
        else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) {
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
