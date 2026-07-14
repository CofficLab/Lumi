import Foundation
import Testing
@testable import LumiLocalizationKit

@Suite("LumiLocalization")
struct LumiLocalizationTests {
    @Test("returns key when bundle has no localization resources")
    func returnsKeyWhenMissingResources() {
        let bundle = Bundle(for: BundleFinder.self)
        #expect(LumiLocalization.string("Missing Key", bundle: bundle) == "Missing Key")
    }

    @Test("returns key for missing xcstrings entry")
    func returnsKeyForMissingCatalogEntry() {
        let bundle = Bundle(for: BundleFinder.self)
        let locale = Locale(identifier: "en")
        #expect(LumiLocalization.string("__nonexistent_key__", bundle: bundle, locale: locale) == "__nonexistent_key__")
    }
}

private final class BundleFinder {}
