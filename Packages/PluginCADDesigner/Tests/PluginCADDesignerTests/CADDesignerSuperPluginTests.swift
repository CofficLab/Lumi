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

    @Test("places and updates CAD components through stable V2 tool IDs")
    func placesAndUpdatesComponentsThroughV2Tools() async throws {
        CADDocumentStore.shared.resetForTests()
        _ = CADDocumentStore.shared.createDocument(name: "V2 Components")
        let profileOutput = try await PlaceProfileV2Tool().execute(arguments: [
            "profileId": ToolArgument("profile-40x40-eu"), "length": ToolArgument(750), "x": ToolArgument(120),
        ])
        let connectorOutput = try await PlaceConnectorV2Tool().execute(arguments: ["connectorId": ToolArgument("connector-corner-40")])
        guard let profile = CADDocumentStore.shared.selectedDocument?.components.first else {
            Issue.record("expected a profile"); return
        }
        let updated = try await UpdateProfileV2Tool().execute(arguments: [
            "componentId": ToolArgument(profile.id), "length": ToolArgument(900), "rotationY": ToolArgument(45),
        ])
        #expect(PlaceProfileV2Tool.toolName == "cad_place_profile")
        #expect(PlaceConnectorV2Tool.toolName == "cad_place_connector")
        #expect(UpdateProfileV2Tool.toolName == "cad_update_profile")
        #expect(profileOutput.contains("750"))
        #expect(connectorOutput.contains("connector-corner-40"))
        #expect(updated.contains(profile.id))
        if case .profile(let currentProfile) = CADDocumentStore.shared.selectedDocument?.components.first {
            #expect(currentProfile.length == 900)
            #expect(currentProfile.transform.rotationY == 45)
        } else { Issue.record("expected the updated profile") }
    }

    @Test("generates the CAD bill of materials through the V2 tool")
    func generatesBOMThroughV2Tool() async throws {
        CADDocumentStore.shared.resetForTests()
        _ = CADDocumentStore.shared.createDocument(name: "V2 BOM")
        _ = try await PlaceProfileV2Tool().execute(arguments: ["profileId": ToolArgument("profile-40x40-eu"), "length": ToolArgument(500)])
        let output = try await GenerateBOMV2Tool().execute(arguments: [:])
        #expect(GenerateBOMV2Tool.toolName == "cad_generate_bom")
        #expect(output.contains("500"))
    }

    @Test("connects components and optimizes profile cuts through V2 tools")
    func connectsAndOptimizesThroughV2Tools() async throws {
        CADDocumentStore.shared.resetForTests()
        _ = CADDocumentStore.shared.createDocument(name: "V2 Assembly")
        _ = try await PlaceProfileV2Tool().execute(arguments: ["profileId": ToolArgument("profile-40x40-eu"), "length": ToolArgument(1000)])
        _ = try await PlaceProfileV2Tool().execute(arguments: ["profileId": ToolArgument("profile-40x40-eu"), "length": ToolArgument(500)])
        guard let components = CADDocumentStore.shared.selectedDocument?.components, components.count == 2 else { Issue.record("expected two components"); return }
        let connection = try await ConnectComponentsV2Tool().execute(arguments: ["fromComponentId": ToolArgument(components[0].id), "toComponentId": ToolArgument(components[1].id), "connectionType": ToolArgument("bolt")])
        let cutting = try await OptimizeCuttingV2Tool().execute(arguments: ["stockLength": ToolArgument(1200)])
        #expect(ConnectComponentsV2Tool.toolName == "cad_connect_components")
        #expect(OptimizeCuttingV2Tool.toolName == "cad_optimize_cutting")
        #expect(connection.contains("bolt"))
        #expect(CADDocumentStore.shared.selectedDocument?.connections.count == 1)
        #expect(cutting.contains("1200"))
    }
}
