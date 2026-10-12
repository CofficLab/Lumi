import Foundation

/// 出口合规声明（`usesNonExemptEncryption`）的取值与展示信息。
///
/// 用于选择控件与选项弹层共享同一套图标和文案。
enum ExportComplianceChoice: CaseIterable {
    case noNonExemptEncryption
    case usesNonExemptEncryption

    /// 与 App Store Connect `usesNonExemptEncryption` 字段对应的布尔值
    var value: Bool {
        switch self {
        case .noNonExemptEncryption:
            return false
        case .usesNonExemptEncryption:
            return true
        }
    }

    /// 选项图标：使用非豁免加密时为警示样式
    var systemImage: String {
        switch self {
        case .noNonExemptEncryption:
            return "checkmark.shield"
        case .usesNonExemptEncryption:
            return "exclamationmark.shield"
        }
    }

    /// 选项文案
    var title: String {
        switch self {
        case .noNonExemptEncryption:
            return AppStoreConnectLocalization.string("No non-exempt encryption")
        case .usesNonExemptEncryption:
            return AppStoreConnectLocalization.string("Uses non-exempt encryption")
        }
    }

    /// 未声明（`nil`）时返回 `nil`
    static func choice(for value: Bool?) -> ExportComplianceChoice? {
        guard let value else { return nil }
        return value ? .usesNonExemptEncryption : .noNonExemptEncryption
    }
}
