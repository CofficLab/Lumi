import Foundation
import KitAgentTool
import KernelCore
import ProviderContentView
import ProviderStorage
import Testing
import KitCADDesigner
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
        try CADDesignerPlugin().onBoot(kernel: kernel)
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

    @Test func loadReportsTheImportedProjectID() async throws {
        CADDocumentStore.shared.resetForTests()
        let original = CADDocumentStore.shared.createDocument(name: "Load ID")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CADDesignerV2-\(UUID().uuidString).cadproj")
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try await SaveCADProjectV2Tool().execute(arguments: ["path": ToolArgument(url.path)])
        let loaded = try await LoadCADProjectV2Tool().execute(arguments: ["path": ToolArgument(url.path)])
        let selected = try #require(CADDocumentStore.shared.selectedDocument)

        #expect(selected.id != original.id)
        #expect(loaded.contains(selected.id))
        #expect(!loaded.contains(original.id))
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

    @Test("rejects an explicitly provided unknown profile id")
    func rejectsUnknownExplicitProfileID() async throws {
        CADDocumentStore.shared.resetForTests()
        _ = CADDocumentStore.shared.createDocument(name: "V2 Bad Profile")

        await #expect(throws: ToolExecutionError.self) {
            _ = try await BuildFrameV2Tool().execute(arguments: [
                "width": ToolArgument(800), "depth": ToolArgument(600), "height": ToolArgument(900),
                "series": ToolArgument("40"),
                "profileId": ToolArgument("profile-40x40-typo"),
            ])
        }
        #expect(CADDocumentStore.shared.selectedDocument?.components.isEmpty == true)

        // 未提供 profileId 时仍回退到系列默认方形型材。
        let output = try await BuildFrameV2Tool().execute(arguments: [
            "width": ToolArgument(800), "depth": ToolArgument(600), "height": ToolArgument(900),
            "series": ToolArgument("40"),
        ])
        #expect(output.contains("profile-40x40"))
        #expect(CADDocumentStore.shared.selectedDocument?.components.count == 20)
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

    @Test("rejects connections whose endpoints are missing from the document")
    func rejectsConnectionsWithUnknownEndpoints() async throws {
        CADDocumentStore.shared.resetForTests()
        _ = CADDocumentStore.shared.createDocument(name: "V2 Connect Guard")
        _ = try await PlaceProfileV2Tool().execute(arguments: [
            "profileId": ToolArgument("profile-40x40-eu"), "length": ToolArgument(500),
        ])
        _ = try await PlaceConnectorV2Tool().execute(arguments: ["connectorId": ToolArgument("connector-corner-40")])
        guard let components = CADDocumentStore.shared.selectedDocument?.components, components.count == 2 else {
            Issue.record("expected two components"); return
        }

        await #expect(throws: ToolExecutionError.self) {
            _ = try await ConnectComponentsV2Tool().execute(arguments: [
                "fromComponentId": ToolArgument("missing-a"), "toComponentId": ToolArgument("missing-b"),
            ])
        }
        do {
            _ = try await ConnectComponentsV2Tool().execute(arguments: [
                "fromComponentId": ToolArgument(components[0].id), "toComponentId": ToolArgument("missing-b"),
            ])
            Issue.record("expected a missing endpoint to be rejected")
        } catch let error as ToolExecutionError {
            #expect(error.errorDescription?.contains("missing-b") == true)
        }
        #expect(CADDocumentStore.shared.selectedDocument?.connections.isEmpty == true)

        _ = try await ConnectComponentsV2Tool().execute(arguments: [
            "fromComponentId": ToolArgument(components[0].id), "toComponentId": ToolArgument(components[1].id),
        ])
        #expect(CADDocumentStore.shared.selectedDocument?.connections.count == 1)
    }

    @Test("rejects unrepresentable profile lengths before mutating the document")
    func rejectsUnrepresentableProfileLengthBeforeMutatingDocument() async throws {
        CADDocumentStore.shared.resetForTests()
        _ = CADDocumentStore.shared.createDocument(name: "V2 Length Guard")

        do {
            _ = try await PlaceProfileV2Tool().execute(arguments: [
                "profileId": ToolArgument("profile-40x40-eu"), "length": ToolArgument(1e20),
            ])
            Issue.record("expected an oversized length to be rejected")
        } catch let error as ToolExecutionError {
            #expect(error.errorDescription?.contains("length") == true)
        }
        for length in [Double.infinity, 0, -5] {
            await #expect(throws: ToolExecutionError.self) {
                _ = try await PlaceProfileV2Tool().execute(arguments: [
                    "profileId": ToolArgument("profile-40x40-eu"), "length": ToolArgument(length),
                ])
            }
        }
        #expect(CADDocumentStore.shared.selectedDocument?.components.isEmpty == true)
    }

    @Test("reports save and load I/O failures as tool errors")
    func reportsSaveAndLoadIOFailuresAsToolErrors() async throws {
        CADDocumentStore.shared.resetForTests()
        _ = CADDocumentStore.shared.createDocument(name: "V2 IO Failure")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let unsavable = directory.appendingPathComponent("missing-parent").appendingPathComponent("project.cadproj")

        await #expect(throws: ToolExecutionError.self) {
            _ = try await SaveCADProjectV2Tool().executeResult(arguments: ["path": ToolArgument(unsavable.path)])
        }
        #expect(!FileManager.default.fileExists(atPath: unsavable.path))

        let missingSource = directory.appendingPathComponent("absent.cadproj")
        await #expect(throws: ToolExecutionError.self) {
            _ = try await LoadCADProjectV2Tool().executeResult(arguments: ["path": ToolArgument(missingSource.path)])
        }
        #expect(CADDocumentStore.shared.selectedDocument?.components.isEmpty == true)
    }

    @Test("tool failures throw instead of returning error strings")
    func toolFailuresThrow() async {
        CADDocumentStore.shared.resetForTests()

        await #expect(throws: ToolExecutionError.self) {
            _ = try await BuildFrameV2Tool().execute(arguments: [
                "depth": ToolArgument(600), "height": ToolArgument(900),
            ])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await PlaceProfileV2Tool().execute(arguments: ["profileId": ToolArgument("profile-missing")])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await PlaceConnectorV2Tool().execute(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await ConnectComponentsV2Tool().execute(arguments: ["fromComponentId": ToolArgument("a")])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await GenerateBOMV2Tool().execute(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await OptimizeCuttingV2Tool().execute(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await SaveCADProjectV2Tool().execute(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await LoadCADProjectV2Tool().execute(arguments: [:])
        }
    }
}
