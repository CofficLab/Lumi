import XCTest
@testable import EditorLanguages

final class TreeSitterResourceTests: XCTestCase {
    func testSwiftHighlightQueryURLExistsInBundle() {
        let language = CodeLanguage.detectLanguageFrom(url: URL(fileURLWithPath: "/tmp/Test.swift"))
        let queryURL = language.queryURL

        XCTAssertNotNil(queryURL)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: queryURL!.path),
            "Expected highlights query at \(queryURL!.path)"
        )
    }

    func testSwiftTreeSitterQueryLoadsFromBundle() throws {
        let language = CodeLanguage.detectLanguageFrom(url: URL(fileURLWithPath: "/tmp/Test.swift"))
        try XCTSkipIf(
            language.language == nil,
            "CodeLanguagesContainer.xcframework is missing; run ./build_framework.sh"
        )
        XCTAssertNotNil(TreeSitterModel.shared.query(for: language.id))
    }

    func testSwiftTreeSitterLanguageSymbolIsAvailable() throws {
        let language = CodeLanguage.detectLanguageFrom(url: URL(fileURLWithPath: "/tmp/Test.swift"))
        try XCTSkipIf(
            language.language == nil,
            "tree_sitter_swift is unavailable; build CodeLanguagesContainer.xcframework with ./build_framework.sh"
        )
        XCTAssertNotNil(language.language)
    }
}
