#if canImport(XCTest)
import Foundation
import LumiKernel
import XCTest
@testable import EditorFileTreePlugin

final class EditorFileTreeLocalizationTests: XCTestCase {
  func testContextMenuStringsAreLocalizedInSimplifiedChinese() {
    let bundle = Bundle.module
    let locale = Locale(identifier: "zh-Hans")
    let keys = [
      "New File",
      "New Folder",
      "Rename",
      "Reveal in Finder",
      "Copy Path",
      "Move to Trash",
      "Cancel",
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
