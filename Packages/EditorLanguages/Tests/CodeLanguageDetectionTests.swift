import XCTest
@testable import EditorLanguages

final class CodeLanguageDetectionTests: XCTestCase {
    func testDetectsLanguageFromFileExtension() {
        let url = URL(fileURLWithPath: "/tmp/App.swift")

        let language = CodeLanguage.detectLanguageFrom(url: url)

        XCTAssertEqual(language.id, .swift)
        XCTAssertEqual(language.tsName, "swift")
    }

    func testDetectsSpecialFileNameWithoutExtension() {
        let url = URL(fileURLWithPath: "/tmp/Dockerfile")

        let language = CodeLanguage.detectLanguageFrom(url: url)

        XCTAssertEqual(language.id, .dockerfile)
    }

    func testDetectsLanguageFromShebangWhenExtensionIsUnknown() {
        let url = URL(fileURLWithPath: "/tmp/tool")
        let prefix = "#!/usr/bin/env swift\nprint(\"hello\")"

        let language = CodeLanguage.detectLanguageFrom(url: url, prefixBuffer: prefix)

        XCTAssertEqual(language.id, .swift)
    }

    func testDetectsLanguageFromModeline() {
        let url = URL(fileURLWithPath: "/tmp/source")
        let prefix = "// -*- mode: javascript -*-"

        let language = CodeLanguage.detectLanguageFrom(url: url, prefixBuffer: prefix)

        XCTAssertEqual(language.id, .javascript)
    }

    func testFallsBackToPlainTextForUnknownLanguage() {
        let url = URL(fileURLWithPath: "/tmp/file.unknown-extension")

        let language = CodeLanguage.detectLanguageFrom(url: url)

        XCTAssertEqual(language.id, .plainText)
    }
}
