import Foundation

/// 模型展示配置：把接口返回的 `model_name` 映射为详情面板的展示文案。
///
/// 均为本地化 key，实际字符串由 ``TokenPlanStatusLocalization`` 所在层的
/// `pluginLocalization` 解析，避免模型层持有语言相关字面量。
enum TokenPlanModelDisplayConfig {

    case general
    case video
    case unknown

    var displayNameKey: String {
        switch self {
        case .general: return "General Model"
        case .video: return "Video Model"
        case .unknown: return "Unknown Model"
        }
    }

    var intervalTitleKey: String {
        switch self {
        case .general, .video: return "5-Hour Window"
        case .unknown: return "Current Interval"
        }
    }

    var intervalDescriptionKey: String {
        switch self {
        case .general: return "General model 5-hour call limit"
        case .video: return "Video model 5-hour call limit"
        case .unknown: return "Unknown Model"
        }
    }

    static func from(_ modelName: String) -> TokenPlanModelDisplayConfig {
        switch modelName.lowercased() {
        case "general": return .general
        case "video": return .video
        default: return .unknown
        }
    }
}
