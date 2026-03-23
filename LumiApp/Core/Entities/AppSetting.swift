import Foundation

/// 应用级通用设置：用于在多次启动之间恢复 UI 行为。
public struct AppSetting: Codable, Equatable {
    public var mode: AppMode

    public init(mode: AppMode = .agent) {
        self.mode = mode
    }
}

