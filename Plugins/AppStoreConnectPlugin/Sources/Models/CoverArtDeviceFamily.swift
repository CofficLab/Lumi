import Foundation

enum CoverArtDeviceFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case iphone
    case ipad
    case mac

    var id: String { rawValue }

    var displayTypes: [String] {
        switch self {
        case .iphone:
            return ["APP_IPHONE_67", "APP_IPHONE_65", "APP_IPHONE_61", "APP_IPHONE_58"]
        case .ipad:
            return ["APP_IPAD_PRO_3GEN_129", "APP_IPAD_PRO_3GEN_11"]
        case .mac:
            return ["APP_DESKTOP"]
        }
    }

    var localizedTitle: String {
        switch self {
        case .iphone:
            return AppStoreConnectLocalization.string("iPhone")
        case .ipad:
            return AppStoreConnectLocalization.string("iPad")
        case .mac:
            return AppStoreConnectLocalization.string("Mac")
        }
    }
}

struct CoverArtPreviewSize: Identifiable, Equatable, Sendable {
    let displayType: String
    let width: Int
    let height: Int

    var id: String { "\(width)x\(height)" }

    var label: String {
        ScreenshotDisplayFormatting.label(for: displayType)
    }
}
