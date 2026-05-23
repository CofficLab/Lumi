import Foundation
import MemoryKit

/// 记忆条目（Re-exported from MemoryKit）
public typealias MemoryItem = MemoryKit.MemoryItem

// MARK: - App 层便利扩展

extension MemoryItem {
    /// 是否已过时（使用 App 层配置的阈值）
    public var isStale: Bool {
        ageInDays > MemoryPluginLocalStore.shared.staleThresholdDays
    }

    /// 完整格式化内容（使用 App 层配置的时效阈值）
    public func formattedContent() -> String {
        formattedContent(staleThresholdDays: MemoryPluginLocalStore.shared.staleThresholdDays)
    }
}
