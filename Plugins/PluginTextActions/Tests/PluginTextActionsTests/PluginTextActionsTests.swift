import Testing
import ApplicationServices
@testable import PluginTextActions

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@Test func axElementCastRejectsNonAccessibilityObjects() {
    let object = "not an accessibility element" as CFString

    #expect(TextSelectionManager.axElement(from: object) == nil)
}

@Test func axElementCastAcceptsAccessibilityElements() {
    let element = AXUIElementCreateSystemWide()

    #expect(TextSelectionManager.axElement(from: element) != nil)
}
