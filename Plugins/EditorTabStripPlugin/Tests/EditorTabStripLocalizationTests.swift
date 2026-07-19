#if canImport(XCTest)
import Foundation
import LumiKernel
import XCTest
@testable import EditorTabStripPlugin

final class EditorTabStripLocalizationTests: XCTestCase {
  func testContextMenuStringsAreLocalizedInSimplifiedChinese() {
    let bundle = Bundle.module
    let locale = Locale(identifier: "zh-Hans")
    let keys = [
      "Close Tab",
      "Close Others",
      "Close Tabs to the Left",
      "Close Tabs to the Right",
      "Pin Tab",
      "Unpin Tab",
    ]

    for key in keys {
      let localized = LumiPluginLocalization.string(key, bundle: bundle, locale: locale)
      XCTAssertNotEqual(
        localized,
        key,
        "Expected zh-Hans localization for '\(key)', got English fallback"
      )
      XCTAssertTrue(
        localized.unicodeScalars.contains { $0.value > 127 },
        "Expected '\(key)' to resolve to Chinese text, got '\(localized)'"
      )
    }
  }
}
#endif
