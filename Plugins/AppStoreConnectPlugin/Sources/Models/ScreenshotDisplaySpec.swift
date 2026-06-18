import CoreGraphics
import Foundation

enum ScreenshotDisplaySpec {
    struct Size: Equatable, Sendable {
        let width: Int
        let height: Int

        var cgSize: CGSize {
            CGSize(width: width, height: height)
        }

        var aspectRatio: CGFloat {
            guard height > 0 else { return 1 }
            return CGFloat(width) / CGFloat(height)
        }
    }

    private static let sizesByDisplayType: [String: Size] = [
        "APP_IPHONE_67": Size(width: 1290, height: 2796),
        "APP_IPHONE_65": Size(width: 1284, height: 2778),
        "APP_IPHONE_61": Size(width: 1170, height: 2532),
        "APP_IPHONE_58": Size(width: 1170, height: 2532),
        "APP_IPAD_PRO_3GEN_129": Size(width: 2048, height: 2732),
        "APP_IPAD_PRO_3GEN_11": Size(width: 1668, height: 2388),
        "APP_DESKTOP": Size(width: 1280, height: 800),
        "APP_APPLE_TV": Size(width: 1920, height: 1080)
    ]

    static func size(for displayType: String) -> Size? {
        sizesByDisplayType[displayType]
    }

    static func aspectRatio(for displayType: String) -> CGFloat? {
        size(for: displayType)?.aspectRatio
    }

    static func defaultDisplayTypes(forPlatform platform: String) -> [String] {
        switch platform.uppercased() {
        case "MAC_OS":
            return ["APP_DESKTOP"]
        case "TV_OS":
            return ["APP_APPLE_TV"]
        case "IOS":
            return [
                "APP_IPHONE_67",
                "APP_IPHONE_65",
                "APP_IPHONE_61",
                "APP_IPHONE_58",
                "APP_IPAD_PRO_3GEN_129",
                "APP_IPAD_PRO_3GEN_11"
            ]
        default:
            return [
                "APP_IPHONE_67",
                "APP_IPHONE_65",
                "APP_IPHONE_61",
                "APP_IPHONE_58",
                "APP_IPAD_PRO_3GEN_129",
                "APP_IPAD_PRO_3GEN_11"
            ]
        }
    }
}
