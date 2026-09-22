import XCTest
import SwiftUI
@testable import EditorSource

final class SmokeTests: XCTestCase {
    func testCanConstructImages() {
        _ = Image(symbol: "vault")
        _ = Image.vault
    }
}

