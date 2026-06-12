import Foundation
import Testing
@testable import LumiCoreKit

@Suite("Lumi plugin localization")
struct LumiPluginLocalizationTests {
    @Test("returns key when bundle has no localization resources")
    func returnsKeyWhenMissingResources() {
        let bundle = Bundle(for: BundleFinder.self)
        #expect(LumiPluginLocalization.string("Missing Key", bundle: bundle) == "Missing Key")
    }
}

private final class BundleFinder {}
