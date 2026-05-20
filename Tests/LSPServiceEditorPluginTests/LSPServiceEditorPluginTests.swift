#if canImport(XCTest)
import XCTest
@testable import Lumi

private actor DebouncerHitBox {
    private var hitCount = 0

    func increment() {
        hitCount += 1
    }

    func value() -> Int {
        hitCount
    }
}

final class LSPServiceEditorPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(LSPServiceEditorPlugin.id, "LSPServiceEditor")
        XCTAssertEqual(LSPServiceEditorPlugin.iconName, "server.rack")
        XCTAssertTrue(LSPServiceEditorPlugin.enable)
        XCTAssertEqual(LSPServiceEditorPlugin.order, 5)
        XCTAssertFalse(LSPServiceEditorPlugin.isConfigurable)
    }

    func testPluginAdvertisesEditorExtensions() {
        let plugin = LSPServiceEditorPlugin()
        XCTAssertTrue(plugin.providesEditorExtensions)
    }

    func testSupportedLanguageIdsContainCoreLanguages() {
        XCTAssertTrue(LSPConfig.supportedLanguageIds.contains("swift"))
        XCTAssertTrue(LSPConfig.supportedLanguageIds.contains("python"))
        XCTAssertTrue(LSPConfig.supportedLanguageIds.contains("typescript"))
    }

    func testDefaultConfigReturnsNilForUnsupportedLanguage() {
        XCTAssertNil(LSPConfig.defaultConfig(for: "kotlin"))
    }

    func testSemanticTokenTypesMapToEditorCaptures() {
        XCTAssertEqual(SemanticTokenMap.captureName(forSemanticTokenType: "class"), .type)
        XCTAssertEqual(SemanticTokenMap.captureName(forSemanticTokenType: "struct"), .type)
        XCTAssertEqual(SemanticTokenMap.captureName(forSemanticTokenType: "enumMember"), .property)
        XCTAssertEqual(SemanticTokenMap.captureName(forSemanticTokenType: "operator"), .keyword)
        XCTAssertEqual(SemanticTokenMap.captureName(forSemanticTokenType: "regexp"), .string)
        XCTAssertEqual(SemanticTokenMap.captureName(forSemanticTokenType: "function"), .function)
    }

    func testDebounceCancelsEarlierRequestForSameKey() async {
        let debouncer = LSPDebouncer()

        async let first: Int? = debouncer.debounce(key: "hover", delay: 50_000_000) {
            1
        }
        async let second: Int? = debouncer.debounce(key: "hover", delay: 10_000_000) {
            2
        }

        let firstResult = await first
        let secondResult = await second

        XCTAssertNil(firstResult)
        XCTAssertEqual(secondResult, 2)
    }

    func testThrottleSuppressesRepeatedCallsInsideWindow() async {
        let debouncer = LSPDebouncer()

        let first = await debouncer.throttle(key: "diagnostics", interval: 1_000_000_000) { 1 }
        let second = await debouncer.throttle(key: "diagnostics", interval: 1_000_000_000) { 2 }

        XCTAssertEqual(first, 1)
        XCTAssertNil(second)
    }

    func testCancelAllPreventsPendingDebouncedOperation() async {
        let debouncer = LSPDebouncer()
        let hits = DebouncerHitBox()

        async let pending: Int? = debouncer.debounce(key: "completion", delay: 100_000_000) {
            await hits.increment()
            return 3
        }

        try? await Task.sleep(for: .milliseconds(10))
        await debouncer.cancelAll()
        let result = await pending
        let hitCountAfterCancel = await hits.value()

        XCTAssertNil(result)
        XCTAssertEqual(hitCountAfterCancel, 0)
    }

    func testCancelAllResetsThrottleWindow() async {
        let debouncer = LSPDebouncer()
        let hits = DebouncerHitBox()

        let first = await debouncer.throttle(key: "hover", interval: 1_000_000_000) {
            await hits.increment()
            return "first"
        }
        let hitCountAfterFirst = await hits.value()
        XCTAssertEqual(first, "first")
        XCTAssertEqual(hitCountAfterFirst, 1)

        let throttled = await debouncer.throttle(key: "hover", interval: 1_000_000_000) {
            await hits.increment()
            return "second"
        }
        let hitCountAfterThrottle = await hits.value()
        XCTAssertNil(throttled)
        XCTAssertEqual(hitCountAfterThrottle, 1)

        await debouncer.cancelAll()

        let afterReset = await debouncer.throttle(key: "hover", interval: 1_000_000_000) {
            await hits.increment()
            return "third"
        }
        let hitCountAfterReset = await hits.value()

        XCTAssertEqual(afterReset, "third")
        XCTAssertEqual(hitCountAfterReset, 2)
    }
}
#endif
