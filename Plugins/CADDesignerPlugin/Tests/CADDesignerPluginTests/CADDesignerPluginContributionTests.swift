import LumiKernel
@testable import CADDesignerPlugin
import XCTest

final class CADDesignerPluginContributionTests: XCTestCase {
    @MainActor
    func testPluginRegistersItsHostedAppContainer() {
        let plugin = CADDesignerPlugin()

        let containers = plugin.viewContainers(kernel: LumiKernel())

        XCTAssertEqual(containers.map(\.id), [plugin.id])
        XCTAssertNotNil(containers.first?.makeView)
    }
}
