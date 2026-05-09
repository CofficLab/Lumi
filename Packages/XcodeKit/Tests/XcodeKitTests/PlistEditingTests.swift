import XCTest
@testable import XcodeKit

final class PlistEditingTests: XCTestCase {

    // MARK: - supports Tests

    func testSupportsPlist() {
        let url = URL(filePath: "/test/Info.plist")
        XCTAssertTrue(PlistEditing.supports(fileURL: url))
    }

    func testSupportsEntitlements() {
        let url = URL(filePath: "/test/app.entitlements")
        XCTAssertTrue(PlistEditing.supports(fileURL: url))
    }

    func testSupportsSwiftFile() {
        let url = URL(filePath: "/test/main.swift")
        XCTAssertFalse(PlistEditing.supports(fileURL: url))
    }

    // MARK: - validatePlist Tests

    func testValidateInvalidPlist() {
        let warnings = PlistEditing.validatePlist("not a plist")
        XCTAssertFalse(warnings.isEmpty)
    }

    func testValidateMissingKeys() {
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        </dict>
        </plist>
        """
        let warnings = PlistEditing.validatePlist(plistContent)
        XCTAssertTrue(warnings.contains("Missing CFBundleIdentifier"))
        XCTAssertTrue(warnings.contains("Missing CFBundleVersion"))
        XCTAssertTrue(warnings.contains("Missing CFBundleShortVersionString"))
    }

    func testValidateValidPlist() {
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.test.app</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
        </dict>
        </plist>
        """
        let warnings = PlistEditing.validatePlist(plistContent)
        XCTAssertTrue(warnings.isEmpty)
    }

    // MARK: - commonKeys Tests

    func testCommonKeysContainsBundleIdentifier() {
        XCTAssertTrue(PlistEditing.commonKeys.keys.contains("CFBundleIdentifier"))
    }

    func testCommonKeysContainsBundleVersion() {
        XCTAssertTrue(PlistEditing.commonKeys.keys.contains("CFBundleVersion"))
    }

    // MARK: - commonEntitlements Tests

    func testCommonEntitlementsContainsAppGroups() {
        XCTAssertTrue(PlistEditing.commonEntitlements.keys.contains("com.apple.security.application-groups"))
    }

    // MARK: - findKeyLocation Tests

    func testFindKeyLocationExistingKey() {
        let content = """
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.test.app</string>
        </dict>
        """
        let range = PlistEditing.findKeyLocation(in: content, key: "CFBundleIdentifier")
        XCTAssertNotNil(range)
    }

    func testFindKeyLocationMissingKey() {
        let content = """
        <dict>
            <key>CFBundleVersion</key>
            <string>1</string>
        </dict>
        """
        let range = PlistEditing.findKeyLocation(in: content, key: "CFBundleIdentifier")
        XCTAssertNil(range)
    }

    // MARK: - keyOccurrences Tests

    func testKeyOccurrences() {
        let content = """
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.test.app</string>
            <key>CFBundleVersion</key>
            <string>1</string>
        </dict>
        """
        let occurrences = PlistEditing.keyOccurrences(in: content)
        XCTAssertEqual(occurrences.count, 2)
        XCTAssertEqual(occurrences[0].key, "CFBundleIdentifier")
        XCTAssertEqual(occurrences[1].key, "CFBundleVersion")
    }

    func testKeyOccurrencesEmpty() {
        let content = "<dict></dict>"
        let occurrences = PlistEditing.keyOccurrences(in: content)
        XCTAssertTrue(occurrences.isEmpty)
    }

    // MARK: - currentKey Tests

    func testCurrentKey() {
        // Test that the method can find a key before a certain position
        let content = """
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.test.app</string>
        </dict>
        """
        // Line 1 (0-indexed), character 50 - should be near the string value
        let key = PlistEditing.currentKey(in: content, line: 2, character: 5)
        // The method looks backward from the given position
        XCTAssertNotNil(key)
    }
    
    func testCurrentKeyMultipleKeys() {
        let content = """
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.test.app</string>
            <key>CFBundleVersion</key>
            <string>1</string>
        </dict>
        """
        
        // Position in CFBundleVersion value should return CFBundleVersion
        let key = PlistEditing.currentKey(in: content, line: 4, character: 5)
        XCTAssertEqual(key, "CFBundleVersion")
    }
    
    func testCurrentKeyFirstLine() {
        let content = """
        <dict>
            <key>CFBundleName</key>
            <string>TestApp</string>
        </dict>
        """
        
        // Position in first key value
        let key = PlistEditing.currentKey(in: content, line: 2, character: 5)
        XCTAssertEqual(key, "CFBundleName")
    }
    
    func testCurrentKeyNoKeyFound() {
        let content = """
        <dict>
            <string>value</string>
        </dict>
        """
        
        // Position without any preceding key
        let key = PlistEditing.currentKey(in: content, line: 1, character: 5)
        XCTAssertNil(key)
    }
    
    // MARK: - hoverMarkdown Tests
    
    func testHoverMarkdownForPlistKey() {
        let fileURL = URL(filePath: "/test/Info.plist")
        let markdown = PlistEditing.hoverMarkdown(for: "CFBundleIdentifier", fileURL: fileURL)
        
        XCTAssertNotNil(markdown)
        XCTAssertTrue(markdown!.contains("CFBundleIdentifier"))
        XCTAssertTrue(markdown!.contains("Bundle ID"))
        XCTAssertTrue(markdown!.contains("Suggested values"))
    }
    
    func testHoverMarkdownForEntitlementsKey() {
        let fileURL = URL(filePath: "/test/app.entitlements")
        let markdown = PlistEditing.hoverMarkdown(for: "com.apple.security.application-groups", fileURL: fileURL)
        
        XCTAssertNotNil(markdown)
        XCTAssertTrue(markdown!.contains("com.apple.security.application-groups"))
        XCTAssertTrue(markdown!.contains("App Groups"))
    }
    
    func testHoverMarkdownForUnsupportedFile() {
        let fileURL = URL(filePath: "/test/file.swift")
        let markdown = PlistEditing.hoverMarkdown(for: "CFBundleIdentifier", fileURL: fileURL)
        
        XCTAssertNil(markdown)
    }
    
    func testHoverMarkdownForUnknownKey() {
        let fileURL = URL(filePath: "/test/Info.plist")
        let markdown = PlistEditing.hoverMarkdown(for: "UnknownKey", fileURL: fileURL)
        
        XCTAssertNil(markdown)
    }
    
    // MARK: - completionSuggestions Tests
    
    func testCompletionSuggestionsForPlist() {
        let fileURL = URL(filePath: "/test/Info.plist")
        let content = """
        <dict>
            <key>CF</key>
        </dict>
        """
        
        let suggestions = PlistEditing.completionSuggestions(
            prefix: "CF",
            line: 1,
            character: 3,
            content: content,
            fileURL: fileURL
        )
        
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.label.hasPrefix("CF") })
    }
    
    func testCompletionSuggestionsForEntitlements() {
        let fileURL = URL(filePath: "/test/app.entitlements")
        let content = """
        <dict>
            <key>com.apple</key>
        </dict>
        """
        
        let suggestions = PlistEditing.completionSuggestions(
            prefix: "com.apple",
            line: 1,
            character: 3,
            content: content,
            fileURL: fileURL
        )
        
        XCTAssertFalse(suggestions.isEmpty)
    }
    
    func testCompletionSuggestionsForUnsupportedFile() {
        let fileURL = URL(filePath: "/test/file.swift")
        let content = ""
        
        let suggestions = PlistEditing.completionSuggestions(
            prefix: "CF",
            line: 0,
            character: 0,
            content: content,
            fileURL: fileURL
        )
        
        XCTAssertTrue(suggestions.isEmpty)
    }
    
    func testCompletionSuggestionsCurrentValue() {
        let fileURL = URL(filePath: "/test/Info.plist")
        let content = """
        <dict>
            <key>CFBundleVersion</key>
            <string></string>
        </dict>
        """
        
        let suggestions = PlistEditing.completionSuggestions(
            prefix: "",
            line: 2,
            character: 7,
            content: content,
            fileURL: fileURL
        )
        
        // Should include value suggestions for CFBundleVersion
        let valueSuggestions = suggestions.filter { $0.label == "1" || $0.label == "$(CURRENT_PROJECT_VERSION)" }
        XCTAssertFalse(valueSuggestions.isEmpty)
    }
    
    func testCompletionSuggestionsEmptyPrefix() {
        let fileURL = URL(filePath: "/test/Info.plist")
        let content = """
        <dict>
            <key></key>
        </dict>
        """
        
        let suggestions = PlistEditing.completionSuggestions(
            prefix: "",
            line: 1,
            character: 3,
            content: content,
            fileURL: fileURL
        )
        
        // Should return all common keys
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.count > 10)
    }
    
    // MARK: - PlistCompletionSuggestion Tests
    
    func testPlistCompletionSuggestionInitialization() {
        let suggestion = PlistCompletionSuggestion(
            label: "CFBundleVersion",
            insertText: "CFBundleVersion",
            detail: "Bundle Version",
            priority: 220
        )
        
        XCTAssertEqual(suggestion.label, "CFBundleVersion")
        XCTAssertEqual(suggestion.insertText, "CFBundleVersion")
        XCTAssertEqual(suggestion.detail, "Bundle Version")
        XCTAssertEqual(suggestion.priority, 220)
    }
    
    func testPlistCompletionSuggestionNilDetail() {
        let suggestion = PlistCompletionSuggestion(
            label: "value",
            insertText: "value",
            detail: nil,
            priority: 260
        )
        
        XCTAssertNil(suggestion.detail)
    }
}
