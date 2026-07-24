import Foundation
import Testing
@testable import LLMProviderManagerPlugin

@Suite struct LLMProviderManagerFormatServiceTests {

    // MARK: - tps

    @Test func tpsFormatsWithUnits() {
        // 整数 / 非整数都带 "tok/s" 后缀
        let result = ModelSelectorFormatService.tps(50)
        #expect(result.hasSuffix("tok/s"))
    }

    @Test func tpsZero() {
        #expect(ModelSelectorFormatService.tps(0).hasSuffix("tok/s"))
    }

    // MARK: - contextSize

    @Test func contextSizeContainsK() {
        #expect(ModelSelectorFormatService.contextSize(1_000_000).hasSuffix("k ctx"))
    }

    @Test func contextSizeZero() {
        #expect(ModelSelectorFormatService.contextSize(0).hasSuffix("k ctx"))
    }

    // MARK: - tokenCount

    @Test func tokenCountReturnsString() {
        #expect(!ModelSelectorFormatService.tokenCount(1_000_000).isEmpty)
    }

    @Test func tokenCountZero() {
        #expect(ModelSelectorFormatService.tokenCount(0) == "0")
    }
}
