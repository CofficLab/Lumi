import KernelCore
import ProviderContentView
import Testing
@testable import PluginCADDesigner

@MainActor
@Suite("PluginCADDesigner")
struct CADDesignerSuperPluginTests {
    @Test("publishes the CAD workspace into the V2 content provider")
    func publishesWorkspace() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
        try CADDesignerSuperPlugin().onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ContentViewProviding).self) != nil)
    }
}
