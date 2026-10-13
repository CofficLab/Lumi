import Foundation

/// 设置页能力抛出的服务不可用错误。
enum GeneralSettingsCapabilityError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            return message
        }
    }
}