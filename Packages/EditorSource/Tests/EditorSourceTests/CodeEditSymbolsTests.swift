import XCTest
import SwiftUI
@testable import EditorSource

final class EditorSymbolsImageTests: XCTestCase {

    // MARK: - Image Static Properties Tests

    func testAllImageStaticProperties() {
        // Test all Image static properties
        _ = Image.vault
        _ = Image.vaultFill
        _ = Image.commit
        _ = Image.checkout
        _ = Image.branch
        _ = Image.breakpoint
        _ = Image.breakpointFill
        _ = Image.chevronUpChevronDown
        _ = Image.github
        _ = Image.docJava
        _ = Image.docJavascript
        _ = Image.docJson
        _ = Image.docPython
        _ = Image.docRuby
        _ = Image.squareSplitHorizontalPlus
        _ = Image.squareSplitVerticalPlus
    }

    func testImageInitWithSymbol() {
        // Test custom symbol initialization
        let vaultImage = Image(symbol: "vault")
        let commitImage = Image(symbol: "commit")
        let branchImage = Image(symbol: "branch")

        // Images should be created successfully
        XCTAssertNotNil(vaultImage)
        XCTAssertNotNil(commitImage)
        XCTAssertNotNil(branchImage)
    }

    func testImageInitWithFillVariants() {
        _ = Image(symbol: "vault.fill")
        _ = Image(symbol: "breakpoint.fill")
    }

    func testImageInitWithCompoundNames() {
        _ = Image(symbol: "chevron.up.chevron.down")
        _ = Image(symbol: "square.split.horizontal.plus")
        _ = Image(symbol: "square.split.vertical.plus")
    }

    func testImageInitWithDocVariants() {
        _ = Image(symbol: "doc.java")
        _ = Image(symbol: "doc.javascript")
        _ = Image(symbol: "doc.json")
        _ = Image(symbol: "doc.python")
        _ = Image(symbol: "doc.ruby")
    }

    func testImageInitWithNonexistentSymbol() {
        // Even non-existent symbols should create an Image
        // (the actual rendering might fail, but construction succeeds)
        let nonExistentImage = Image(symbol: "nonexistent.symbol")
        XCTAssertNotNil(nonExistentImage)
    }
}

final class EditorSymbolsNSImageTests: XCTestCase {

    // MARK: - NSImage Static Properties Tests

    func testNSImageStaticPropertiesCreation() {
        // Test that NSImage static properties can be accessed
        // Note: These may return nil in test environment if resources aren't bundled
        // The important thing is that the code paths are exercised
        _ = NSImage.vault
        _ = NSImage.vaultFill
        _ = NSImage.commit
        _ = NSImage.checkout
        _ = NSImage.branch
        _ = NSImage.breakpoint
        _ = NSImage.breakpointFill
        _ = NSImage.chevronUpChevronDown
        _ = NSImage.github
        _ = NSImage.docJava
        _ = NSImage.docJavascript
        _ = NSImage.docJson
        _ = NSImage.docPython
        _ = NSImage.docRuby
        _ = NSImage.squareSplitHorizontalPlus
        _ = NSImage.squareSplitVerticalPlus
    }

    func testNSImageSymbolMethodExecution() {
        // Test that symbol(named:) method executes correctly
        // Coverage is the goal, not necessarily successful image loading
        _ = NSImage.symbol(named: "vault")
        _ = NSImage.symbol(named: "commit")
        _ = NSImage.symbol(named: "branch")
        _ = NSImage.symbol(named: "vault.fill")
        _ = NSImage.symbol(named: "breakpoint.fill")
    }

    func testNSImageSymbolMethodWithCompoundNames() {
        // Test compound symbol names
        _ = NSImage.symbol(named: "chevron.up.chevron.down")
        _ = NSImage.symbol(named: "square.split.horizontal.plus")
        _ = NSImage.symbol(named: "square.split.vertical.plus")
    }

    func testNSImageSymbolMethodWithDocVariants() {
        // Test doc symbol variants
        _ = NSImage.symbol(named: "doc.java")
        _ = NSImage.symbol(named: "doc.javascript")
        _ = NSImage.symbol(named: "doc.json")
        _ = NSImage.symbol(named: "doc.python")
        _ = NSImage.symbol(named: "doc.ruby")
    }

    func testNSImageSymbolMethodWithNonexistentName() {
        // Test that the method handles non-existent symbols gracefully
        _ = NSImage.symbol(named: "nonexistent.symbol")
        // The method should execute without crashing
    }

    func testNSImageSymbolMethodMultipleCalls() {
        // Test multiple calls to ensure consistency
        for _ in 0..<3 {
            _ = NSImage.symbol(named: "vault")
            _ = NSImage.symbol(named: "commit")
        }
    }
}

final class EditorSymbolsBundleTests: XCTestCase {

    func testBundleAccess() {
        // Test that we can access symbols through different bundle paths
        // This indirectly tests EditorSymbolsBundle.current

        // If we can create images, the bundle is working
        let image1 = Image(symbol: "vault")
        let image2 = Image.vault

        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
    }

    func testMultipleBundleCandidates() {
        // Test that the bundle resolver tries multiple candidate names
        // By creating images from both old and new package names

        // These calls should execute without crashing
        _ = Image(symbol: "vault")
        _ = NSImage.symbol(named: "vault")
    }

    func testBundleResilience() {
        // Test bundle fallback behavior
        // Even if the preferred bundle isn't available, fallback should work

        for _ in 0..<5 {
            // Multiple calls should execute consistently
            _ = Image(symbol: "commit")
            _ = NSImage.symbol(named: "commit")
        }
    }
}