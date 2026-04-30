#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class PlistEditingTests: XCTestCase {
    func testHoverMarkdownReturnsKnownPlistKeyDocumentation() {
        let fileURL = URL(fileURLWithPath: "/tmp/Info.plist")

        let markdown = PlistEditing.hoverMarkdown(for: "CFBundleIdentifier", fileURL: fileURL)

        XCTAssertTrue(markdown?.contains("CFBundleIdentifier") == true)
        XCTAssertTrue(markdown?.contains("PRODUCT_BUNDLE_IDENTIFIER") == true)
    }

    func testCompletionSuggestionsIncludeValueSuggestionsForActiveKey() {
        let fileURL = URL(fileURLWithPath: "/tmp/Info.plist")
        let content = """
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string></string>
        </dict>
        </plist>
        """

        let suggestions = PlistEditing.completionSuggestions(
            prefix: "$(",
            line: 3,
            character: 12,
            content: content,
            fileURL: fileURL
        )

        XCTAssertEqual(suggestions.first?.label, "$(PRODUCT_BUNDLE_IDENTIFIER)")
    }

    func testCurrentKeyTracksNearestPrecedingXMLKey() {
        let content = """
        <dict>
            <key>NSCameraUsageDescription</key>
            <string>Needs camera access</string>
        </dict>
        """

        let key = PlistEditing.currentKey(in: content, line: 2, character: 10)

        XCTAssertEqual(key, "NSCameraUsageDescription")
    }

    func testKeyOccurrencesExposePlistKeysAndLineNumbers() {
        let content = """
        <dict>
            <key>CFBundleIdentifier</key>
            <string>demo</string>
            <key>CFBundleVersion</key>
        </dict>
        """

        let occurrences = PlistEditing.keyOccurrences(in: content)

        XCTAssertEqual(occurrences.map(\.key), ["CFBundleIdentifier", "CFBundleVersion"])
        XCTAssertEqual(occurrences.map(\.line), [2, 4])
    }
}
#endif
