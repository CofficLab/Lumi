import Foundation
import AgentToolKit
import KernelCore
import ProviderContentView
import ProviderStorage
import Testing
import CADDesignerPlugin
@testable import PluginCADDesigner

@MainActor
@Suite("PluginCADDesigner", .serialized)
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

    @Test("preserves CAD project save and load behavior")
    func savesAndLoadsProjectThroughV2Tools() async throws {
        CADDocumentStore.shared.resetForTests()
        let document = CADDocumentStore.shared.createDocument(name: "V2 Persistence")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CADDesignerV2-\(UUID().uuidString).cadproj")
        defer { try? FileManager.default.removeItem(at: url) }

        let saved = try await SaveCADProjectV2Tool().execute(arguments: ["path": ToolArgument(url.path)])
        #expect(SaveCADProjectV2Tool.toolName == "cad_save_project")
        #expect(saved.contains(url.path))

        let loaded = try await LoadCADProjectV2Tool().execute(arguments: ["path": ToolArgument(url.path)])
        #expect(LoadCADProjectV2Tool.toolName == "cad_load_project")
        #expect(loaded.contains(document.name))
        #expect(CADDocumentStore.shared.selectedDocument?.name == document.name)
    }

    @Test("builds the legacy frame shape through the V2 tool")
    func buildsFrameThroughV2Tool() async throws {
        CADDocumentStore.shared.resetForTests()
        _ = CADDocumentStore.shared.createDocument(name: "V2 Frame Build")
        let output = try await BuildFrameV2Tool().execute(arguments: [
            "width": ToolArgument(800), "depth": ToolArgument(600), "height": ToolArgument(900),
        ])
        #expect(BuildFrameV2Tool.toolName == "cad_build_frame")
        #expect(CADDocumentStore.shared.selectedDocument?.components.count == 20)
        #expect(output.contains("20"))
    }
}
