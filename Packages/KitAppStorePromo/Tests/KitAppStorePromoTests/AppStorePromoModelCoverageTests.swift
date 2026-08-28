import Foundation
import Testing
@testable import KitAppStorePromo

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

    @Test("locale normalization edge cases")
    func localeNormalizationEdges() {
        #expect(AppStorePromoLocale.normalize("  en-us  ") == "en-US")
        #expect(AppStorePromoLocale.normalize("es-419") == "es-419")
        #expect(AppStorePromoLocale.normalize("zh-hant-tw") == "zh-Hant-TW")
        #expect(AppStorePromoLocale.normalize("en-GB-Cyrl") == "en-GB-Cyrl")
        #expect(AppStorePromoLocale.normalize("toolonglocale-XX") == nil)
        #expect(AppStorePromoLocale.normalize("e") == nil)
        #expect(AppStorePromoLocale.normalize("en_US") == nil)
    }

    @Test("device family identifiers and localized names")
    func familyIDsAndLocalizedNames() {
        for family in AppStorePromoDeviceFamily.allCases {
            #expect(family.id == family.rawValue)
        }
        let unknown = AppStorePromoLocale(identifier: "zz")
        #expect(unknown.localizedName == "zz")
        #expect(unknown.displayName == "zz · zz")
    }

    @Test("image decoding applies defaults for optional fields")
    func imageDecodingAppliesDefaults() throws {
        let json = """
        {"id":"i","title":"T","order":0,"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let image = try decoder.decode(AppStorePromoImage.self, from: Data(json.utf8))
        #expect(image.htmlFileName == "index.html")
        #expect(image.localeIdentifiers.isEmpty)
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
