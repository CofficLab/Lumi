import Foundation

/// 为QualityOfService提供友好的描述字符串
///
/// 这个扩展为系统的QualityOfService枚举提供了易于阅读的描述，
/// 包括emoji图标和可选的名称显示，便于调试和日志输出。
///
/// ## 使用示例:
/// ```swift
/// let qos = Thread.current.qualityOfService
/// print(qos.description()) // 输出如 "🔥 UserInteractive"
/// print(qos.description(withName: false)) // 仅输出emoji: "🔥"
/// ```
extension QualityOfService {
    /// 获取当前QoS级别的友好描述
    ///
    /// - Parameter withName: 是否在返回的描述中包含QoS级别的名称，默认为true
    /// - Returns: 包含emoji和可选名称的描述字符串
    public func description(withName: Bool = true) -> String {
        switch self {
        case .userInteractive: return withName ? "🔥 UserInteractive" : "🔥"
        case .userInitiated: return withName ? "2️⃣ UserInitiated" : "2️⃣"
        case .default: return withName ? "3️⃣ Default" : "3️⃣"
        case .utility: return withName ? "4️⃣ Utility" : "4️⃣"
        case .background: return withName ? "5️⃣ Background" : "5️⃣"
        default: return withName ? "6️⃣ Unknown" : "6️⃣"
        }
    }
}
