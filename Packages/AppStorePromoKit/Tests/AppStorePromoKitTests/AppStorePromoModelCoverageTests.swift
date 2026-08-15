import Foundation
import Testing
@testable import AppStorePromoKit

final class AppStorePromoModelCoverageTests {
    @Test("device family display types match presets")
    func familyDisplayTypes() {
        for family in AppStorePromoDeviceFamily.allCases {
            let expected = AppStorePromoDisplaySpec.presets
                .filter { $0.family == family }
                .map(\.displayType)
            #expect(family.displayTypes == expected)
            #expect(!family.displayTypes.isEmpty)
        }
        #expect(AppStorePromoDisplaySpec.presets(for: .mac).count == 1)
    }

    @Test("preset derived properties")
    func presetDerivedProperties() {
        let portrait = AppStorePromoDisplayPreset(displayType: "p", family: .iphone, width: 100, height: 200)
        let landscape = AppStorePromoDisplayPreset(displayType: "l", family: .mac, width: 200, height: 100)
        #expect(portrait.id == "p")
        #expect(portrait.isPortrait)
        #expect(!landscape.isPortrait)
        #expect(landscape.cgSize == CGSize(width: 200, height: 100))
    }

    @Test("locale helpers")
    func localeHelpers() {
        #expect(AppStorePromoLocale.common.count == 17)
        let locale = AppStorePromoLocale(identifier: "en-US")
        #expect(locale.id == "en-US")
        #expect(locale.displayName == "\(locale.localizedName) · en-US")
        #expect(AppStorePromoLocale.normalize("ZH-hans") == "zh-Hans")
        #expect(AppStorePromoLocale.normalize("") == nil)
    }

    @Test("asset error descriptions are non-empty")
    func assetErrorDescriptions() {
        let errors: [AppStorePromoAssetError] = [
            .sourceNotFound("/tmp/missing.png"),
            .unsupportedImage("/tmp/file.txt"),
            .fileTooLarge(60_000_000),
        ]
        for error in errors {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }

    @Test("resolved image exposes assets directory")
    func resolvedImageAssetsDirectory() throws {
        let directory = URL(fileURLWithPath: "/tmp/promo/task/image")
        let image = AppStorePromoImage(
            id: "id",
            title: "Title",
            order: 0,
            htmlFileName: "index.html"
        )
        let task = AppStorePromoTask(
            id: "task",
            title: "Task",
            appName: "App",
            deviceFamily: .iphone,
            images: [image]
        )
        let resolved = AppStorePromoResolvedImage(
            task: task,
            image: image,
            directoryURL: directory,
            html: "<html></html>",
            localeIdentifier: "en-US"
        )
        #expect(resolved.htmlURL == directory.appendingPathComponent("index.html"))
        #expect(resolved.assetsDirectoryURL.path.hasSuffix("assets"))
    }
}
