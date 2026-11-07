import Foundation
import Testing
@testable import ProviderPluginManaging

@Suite("PluginManagingError")
struct PluginManagingErrorTests {
    @Test("error descriptions")
    func descriptions() {
        #expect(PluginManagingError.kernelNotAttached.errorDescription == "Kernel is not attached")
        #expect(PluginManagingError.pluginNotFound(id: "x").errorDescription == "Plugin 'x' not found")
        #expect(PluginManagingError.lifecycle("boom").errorDescription == "boom")
    }

    @Test("equality")
    func equality() {
        #expect(PluginManagingError.kernelNotAttached == .kernelNotAttached)
        #expect(PluginManagingError.pluginNotFound(id: "a") == .pluginNotFound(id: "a"))
        #expect(PluginManagingError.pluginNotFound(id: "a") != .pluginNotFound(id: "b"))
    }
}
