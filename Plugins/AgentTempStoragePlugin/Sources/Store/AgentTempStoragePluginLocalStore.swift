import Foundation
import LumiKernel

/// AgentTempStoragePlugin 本地存储配置
final class AgentTempStoragePluginLocalStore: @unchecked Sendable {
    static let shared = AgentTempStoragePluginLocalStore()

    /// 临时文件保留天数
    var retentionDays: Int {
        get { UserDefaults.standard.integer(forKey: "AgentTempStorage.retentionDays").nonZeroOr(7) }
        set { UserDefaults.standard.set(newValue, forKey: "AgentTempStorage.retentionDays") }
    }

    private init() {}
}

private extension Int {
    func nonZeroOr(_ defaultValue: Int) -> Int {
        self > 0 ? self : defaultValue
    }
}
