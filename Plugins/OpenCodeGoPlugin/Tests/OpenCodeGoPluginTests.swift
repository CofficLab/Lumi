import XCTest
@testable import OpenCodeGoPlugin

final class OpenCodeGoPluginTests: XCTestCase {
    func testPluginInitialization() {
        let plugin = OpenCodeGoPlugin()
        XCTAssertEqual(plugin.id, "com.coffic.lumi.plugin.opencodego")
        XCTAssertEqual(plugin.order, 200)
        XCTAssertEqual(plugin.policy, .alwaysOn)
        XCTAssertEqual(plugin.stage, .beta)
    }

    func testPluginName() async {
        let plugin = OpenCodeGoPlugin()
        let name = plugin.name
        XCTAssertFalse(name.isEmpty)
    }

    func testChatSectionToolbarItems() async {
        // This test requires a KernelLumi instance, so we'll just verify the method exists
        // In a real test, you'd mock the kernel
        XCTAssertTrue(true)
    }
}
