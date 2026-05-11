#if canImport(Testing)
import Testing

@Suite("LumiPreviewKit placeholder")
struct LumiPreviewKitPlaceholderTests {
    @Test("package resolves")
    func packageResolves() {
        #expect(Bool(true))
    }
}
#endif
