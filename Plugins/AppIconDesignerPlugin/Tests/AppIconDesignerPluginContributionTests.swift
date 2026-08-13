import KernelLumi
@testable import AppIconDesignerPlugin
import XCTest

final class AppIconDesignerPluginContributionTests: XCTestCase {
    @MainActor
    func testPluginRegistersItsHostedAppContainer() {
        let plugin = AppIconDesignerPlugin()

        let containers = plugin.viewContainers(kernel: KernelLumi())

        XCTAssertEqual(containers.map(\.id), [plugin.id])
        XCTAssertNotNil(containers.first?.makeView)
    }
}
