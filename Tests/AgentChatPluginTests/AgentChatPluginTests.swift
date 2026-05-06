#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class AgentChatPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(AgentChatPlugin.id, "AgentChat")
        XCTAssertEqual(AgentChatPlugin.iconName, "text.bubble.fill")
        XCTAssertTrue(AgentChatPlugin.enable)
        XCTAssertEqual(AgentChatPlugin.order, 82)
    }

    func testSidebarViewIsHiddenForNonEditorIcon() async {
        let view = await AgentChatPlugin.shared.addSidebarView(activeIcon: "not-editor")
        XCTAssertNil(view)
    }
}
#endif
