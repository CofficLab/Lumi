import Testing
@testable import StringCatalogKit

struct StringCatalogPlaceholderScannerTests {
    @Test
    func findsObjectAndIntegerPlaceholders() {
        let placeholders = StringCatalogPlaceholderScanner.placeholders(in: "Build %1$@ %2$@ at line %lld")

        #expect(placeholders.map { String($0.value) } == ["%1$@", "%2$@", "%lld"])
    }

    @Test
    func findsFormattedNumericPlaceholders() {
        let placeholders = StringCatalogPlaceholderScanner.placeholders(in: "Progress %03d and %.2f%%")

        #expect(placeholders.map { String($0.value) } == ["%03d", "%.2f"])
    }

    @Test
    func ignoresEscapedPercentAndPlainText() {
        let placeholders = StringCatalogPlaceholderScanner.placeholders(in: "Battery 100%% ready")

        #expect(placeholders.isEmpty)
    }

    @Test
    func reportsStringRanges() {
        let text = "File not found: %@"
        let placeholder = StringCatalogPlaceholderScanner.placeholders(in: text).first

        #expect(placeholder?.range == text.range(of: "%@"))
    }
}
