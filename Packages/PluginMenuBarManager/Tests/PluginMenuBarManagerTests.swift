import Testing
import Foundation
@testable import MenuBarManagerPlugin

@MainActor
@Test func packageLoads() async throws {
    #expect(MenuBarManagerPlugin().id == "com.coffic.lumi.plugin.menubar-manager")
}
