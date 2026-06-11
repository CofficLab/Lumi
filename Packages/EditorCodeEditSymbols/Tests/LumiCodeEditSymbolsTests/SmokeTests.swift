import XCTest
import SwiftUI
@testable import CodeEditSymbols

final class SmokeTests: XCTestCase {
    func testCanConstructImages() {
        _ = Image(symbol: "vault")
        _ = Image.vault
    }
}

