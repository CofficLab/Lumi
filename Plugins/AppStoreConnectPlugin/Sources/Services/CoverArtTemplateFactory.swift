import Foundation
import AppStorePromoKit

enum CoverArtTemplateFactory {
    static func html(title: String, deviceFamily: CoverArtDeviceFamily) -> String {
        AppStorePromoTemplateFactory.html(
            title: title.isEmpty ? "App Title" : title,
            appName: title.isEmpty ? "Your App" : title,
            family: sharedFamily(deviceFamily)
        )
    }

    private static func sharedFamily(_ family: CoverArtDeviceFamily) -> AppStorePromoDeviceFamily {
        switch family {
        case .iphone: .iphone
        case .ipad: .ipad
        case .mac: .mac
        }
    }
}
