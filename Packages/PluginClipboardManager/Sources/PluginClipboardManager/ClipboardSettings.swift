import Foundation

/// 剪贴板插件对外暴露的设置项。
///
/// 设置视图与运行时（监控、历史上限）共用同一组键和默认值，
/// 避免界面显示与实际行为不一致。
enum ClipboardSettings {
    static let monitoringEnabledKey = "ClipboardMonitoringEnabled"
    static let historySizeKey = "ClipboardHistorySize"

    static let defaultHistorySize = 500
    static let unlimitedHistorySize = Int.max
    static let supportedHistorySizes = [100, 500, 1000, Int.max]

    /// 未写过设置时默认开启监控，保持插件既有行为。
    static var isMonitoringEnabled: Bool {
        let store = ClipboardManagerPluginLocalStore.shared
        guard store.object(forKey: monitoringEnabledKey) != nil else { return true }
        return store.bool(forKey: monitoringEnabledKey)
    }

    static func setMonitoringEnabled(_ enabled: Bool) {
        ClipboardManagerPluginLocalStore.shared.set(enabled, forKey: monitoringEnabledKey)
    }

    /// 历史条数上限；0 或未设置时回退到默认值。
    static var historyLimit: Int {
        let value = ClipboardManagerPluginLocalStore.shared.integer(forKey: historySizeKey)
        return value <= 0 ? defaultHistorySize : value
    }

    static func setHistoryLimit(_ limit: Int) {
        ClipboardManagerPluginLocalStore.shared.set(limit, forKey: historySizeKey)
    }
}
