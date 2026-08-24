import Foundation
import AgentToolKit
import KernelCore
import ProviderContentView
import ProviderStorage
import Testing
import CADDesignerPlugin
@testable import PluginCADDesigner

@MainActor
@Suite("PluginCADDesigner")
struct CADDesignerSuperPluginTests {
    @Test("publishes the CAD workspace into the V2 content provider")
    func publishesWorkspace() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = DefaultStorageProvider(dataRootDirectory: root)
        try kernel.registerProvider((any StorageProviding).self, storage)
        try CADDesignerSuperPlugin().onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ContentViewProviding).self) != nil)
        #expect(CADDesignerRuntimeBridge.configuredPluginSubdirectory == storage.pluginDataDirectory(for: "CADDesignerPlugin"))
    }

    @Test("keeps the legacy create-project tool identifier")
    func createsProjectThroughV2Tool() async throws {
        let output = try await CreateCADProjectV2Tool().execute(arguments: [
            "name": ToolArgument("V2 Frame"),
        ])
        #expect(CreateCADProjectV2Tool.toolName == "cad_create_project")
        #expect(output.contains("V2 Frame"))
    }
}
