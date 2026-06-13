import XCTest
import SwiftUI
@testable import EditorSymbols

final class SmokeTests: XCTestCase {
    func testCanConstructImages() {
        _ = Image(symbol: "vault")
        _ = Image.vault
    }
}

