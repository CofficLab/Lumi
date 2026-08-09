import CoreGraphics
import Foundation
import AppStorePromoKit

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
        "APP_IPHONE_67": sharedSize("APP_IPHONE_67"),
        "APP_IPHONE_65": sharedSize("APP_IPHONE_65"),
        "APP_IPHONE_61": sharedSize("APP_IPHONE_61"),
        "APP_IPHONE_58": sharedSize("APP_IPHONE_58"),
        "APP_IPAD_PRO_3GEN_129": sharedSize("APP_IPAD_PRO_3GEN_129"),
        "APP_IPAD_PRO_3GEN_11": sharedSize("APP_IPAD_PRO_3GEN_11"),
        "APP_DESKTOP": sharedSize("APP_DESKTOP"),
        "APP_APPLE_TV": Size(width: 1920, height: 1080)
    ]

    private static func sharedSize(_ displayType: String) -> Size {
        guard let preset = AppStorePromoDisplaySpec.preset(for: displayType) else {
            preconditionFailure("Missing shared App Store promotional display preset: \(displayType)")
        }
        return Size(width: preset.width, height: preset.height)
    }

    static func size(for displayType: String) -> Size? {
        sizesByDisplayType[displayType]
    }

    static func aspectRatio(for displayType: String) -> CGFloat? {
        size(for: displayType)?.aspectRatio
    }

    static func previewSizes(for family: CoverArtDeviceFamily) -> [CoverArtPreviewSize] {
        var seenSizes = Set<String>()
        return family.displayTypes.compactMap { displayType in
            guard let size = size(for: displayType) else { return nil }
            let key = "\(size.width)x\(size.height)"
            guard seenSizes.insert(key).inserted else { return nil }
            return CoverArtPreviewSize(
                displayType: displayType,
                width: size.width,
                height: size.height
            )
        }
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
