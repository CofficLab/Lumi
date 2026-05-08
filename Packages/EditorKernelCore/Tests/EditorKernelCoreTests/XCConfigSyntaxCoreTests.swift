import Testing
import Foundation
@testable import EditorKernelCore

@Suite("XCConfigSyntaxCore")
struct XCConfigSyntaxCoreTests {
    @Test("tokenize captures include and keys")
    func tokenizeContent() {
        let content = """
        #include "Base.xcconfig"
        SWIFT_VERSION = 6.0
        """
        let tokens = XCConfigSyntaxCore.tokenize(content)
        #expect(tokens.contains { $0.type == .include })
        #expect(tokens.contains { $0.type == .key })
        #expect(tokens.contains { $0.type == .value })
    }

    @Test("include directive resolves by cursor location")
    func includeDirectiveAtLocation() {
        let content = #"#include "Config/Debug.xcconfig""#
        let location = (content as NSString).range(of: "Debug").location
        let directive = XCConfigSyntaxCore.includeDirective(at: location, in: content)
        #expect(directive?.path == "Config/Debug.xcconfig")
    }

    @Test("key occurrences reports key and line")
    func keyOccurrences() {
        let content = """
        PRODUCT_NAME = Lumi
        SWIFT_VERSION = 6.0
        """
        let occurrences = XCConfigSyntaxCore.keyOccurrences(in: content)
        #expect(occurrences.count == 2)
        #expect(occurrences[0].key == "PRODUCT_NAME")
        #expect(occurrences[0].line == 1)
        #expect(occurrences[1].key == "SWIFT_VERSION")
        #expect(occurrences[1].line == 2)
    }
}
