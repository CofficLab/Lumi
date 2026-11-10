import Testing

@testable import PluginLLMContext

struct ContextTokenFormattingTests {
    @Test("小于 1000 的用量显示真实 token 数而不是 0K")
    func smallSizesKeepActualTokens() {
        #expect(1.formattedContextSize == "1")
        #expect(500.formattedContextSize == "500")
        #expect(999.formattedContextSize == "999")
    }

    @Test("千级与百万级仍使用 K/M 简写")
    func largeSizesUseShortUnits() {
        #expect(1_000.formattedContextSize == "1K")
        #expect(128_000.formattedContextSize == "128K")
        #expect(1_000_000.formattedContextSize == "1M")
        #expect(1_500_000.formattedContextSize == "1.5M")
    }

    @Test("零值不再显示为 0K")
    func zeroHasNoUnit() {
        #expect(0.formattedContextSize == "0")
    }
}
