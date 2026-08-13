import KernelLumi
@testable import CADDesignerPlugin
import XCTest

final class CADDesignerPluginContributionTests: XCTestCase {
    @MainActor
    func testPluginRegistersItsHostedAppContainer() {
        let plugin = CADDesignerPlugin()

        let containers = plugin.viewContainers(kernel: KernelLumi())

        XCTAssertEqual(containers.map(\.id), [plugin.id])
        XCTAssertNotNil(containers.first?.makeView)
    }
}
