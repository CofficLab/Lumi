import XCTest
import EditorLanguageRuntime

final class LanguageRegistryTests: XCTestCase {
    func testPlainTextDetectionForUnknownExtension() {
        let registry = LanguageRegistry.shared
        registry.reset()
        let context = registry.detectLanguage(url: URL(fileURLWithPath: "/tmp/unknown.zzz"))
        XCTAssertEqual(context.languageId, "plaintext")
    }

    func testRegistersDescriptorAndDetectsExtension() {
        let registry = LanguageRegistry.shared
        registry.reset()
        registry.register(
            EditorLanguageDescriptor(
                languageId: "ruby",
                displayName: "Ruby",
                fileExtensions: ["rb"],
                highlightLanguageId: "ruby",
                lspLanguageId: "ruby"
            )
        )
        let context = registry.detectLanguage(url: URL(fileURLWithPath: "/tmp/test.rb"))
        XCTAssertEqual(context.languageId, "ruby")
        XCTAssertEqual(registry.lspLanguageId(forExtension: "rb"), "ruby")
    }
}
