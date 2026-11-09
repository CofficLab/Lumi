import Foundation
import UniformTypeIdentifiers
@testable import KitCADDesigner

import XCTest

final class CADDesignerLogicTests: XCTestCase {
    private let library = ComponentLibrary.shared

    // MARK: - Codable Round-Trip

    func testTransform3DCodableRoundTrip() throws {
        let transform = Transform3D(positionX: 100, positionY: 200, positionZ: 300, rotationY: 45)
        let data = try JSONEncoder().encode(transform)
        let decoded = try JSONDecoder().decode(Transform3D.self, from: data)
        XCTAssertEqual(transform, decoded)
    }

    func testPlacementUpdatePreservesOtherTransformComponents() {
        var transform = Transform3D(
            positionX: 1, positionY: 2, positionZ: 3,
            rotationX: 15, rotationY: 30, rotationZ: 90,
            scale: 2
        )

        transform.updatePlacement(positionX: 10, positionY: 20, positionZ: 30, rotationY: 45)

        XCTAssertEqual(transform.positionX, 10)
        XCTAssertEqual(transform.positionY, 20)
        XCTAssertEqual(transform.positionZ, 30)
        XCTAssertEqual(transform.rotationY, 45)
        // 其余分量不得被重置
        XCTAssertEqual(transform.rotationX, 15)
        XCTAssertEqual(transform.rotationZ, 90)
        XCTAssertEqual(transform.scale, 2)
    }

    @MainActor
    func testUndoRestoresComponentValuesWithoutChangingId() {
        let store = CADDocumentStore.shared
        store.resetForTests()
        _ = store.createDocument(name: "Undo Sync")

        let instance = ProfileInstance(profileId: "profile-40x40-eu", length: 500)
        try? store.addComponent(.profile(instance))
        store.selectedComponentId = instance.id

        try? store.updateComponent(id: instance.id) { component in
            if case .profile(var profile) = component {
                profile.length = 1000
                component = .profile(profile)
            }
        }
        if case .profile(let updated) = store.selectedComponent {
            XCTAssertEqual(updated.length, 1000)
        } else {
            XCTFail("Expected a profile component")
        }

        store.undo()

        // Undo 回退内容但保留 ID，因此面板同步必须以组件值为触发条件。
        XCTAssertEqual(store.selectedComponent?.id, instance.id)
        if case .profile(let restored) = store.selectedComponent {
            XCTAssertEqual(restored.length, 500)
        } else {
            XCTFail("Expected a profile component after undo")
        }
    }

    @MainActor
    func testMeasureToolComputesDistanceFromTwoPicks() {
        let store = CADDocumentStore.shared
        store.resetForTests()
        _ = store.createDocument(name: "Measure")

        let viewModel = CADWorkspaceViewModel(store: store, library: library)
        let first = try? store.addComponent(.profile(ProfileInstance(
            profileId: "profile-40x40-eu",
            length: 500,
            transform: Transform3D(positionX: 0, positionY: 0, positionZ: 0)
        )))
        let second = try? store.addComponent(.profile(ProfileInstance(
            profileId: "profile-40x40-eu",
            length: 500,
            transform: Transform3D(positionX: 3, positionY: 4, positionZ: 0)
        )))

        viewModel.currentTool = .measure
        viewModel.handleViewportPick(id: first!.id)
        XCTAssertNil(viewModel.measurement)

        viewModel.handleViewportPick(id: second!.id)
        XCTAssertEqual(viewModel.measurement?.distance ?? -1, 5, accuracy: 0.001)
        XCTAssertEqual(viewModel.measurement?.fromComponentId, first?.id)
        XCTAssertEqual(viewModel.measurement?.toComponentId, second?.id)
    }

    @MainActor
    func testCutResultKeepsStockLengthUsedForOptimization() {
        let store = CADDocumentStore.shared
        store.resetForTests()
        _ = store.createDocument(name: "Cut Length")
        _ = try? store.addComponent(.profile(ProfileInstance(
            profileId: "profile-40x40-eu",
            length: 500
        )))

        let viewModel = CADWorkspaceViewModel(store: store, library: library)
        viewModel.stockLength = 6000
        viewModel.runCutOptimization()
        XCTAssertEqual(viewModel.cutResult?.stockLength, 6000)

        // 修改输入但未重新优化时，旧方案必须仍标记为 6000。
        viewModel.stockLength = 1000
        XCTAssertEqual(viewModel.cutResult?.stockLength, 6000)
    }

    func testCADDocumentCodableRoundTrip() throws {
        let profile = ProfileInstance(profileId: "profile-40x40-eu", length: 1200)
        let connector = ConnectorInstance(connectorId: "connector-corner-40")
        let edge = ConnectionEdge(fromComponentID: profile.id, toComponentID: connector.id)
        let document = CADDocument(
            name: "测试项目",
            components: [.profile(profile), .connector(connector)],
            connections: [edge]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CADDocument.self, from: data)

        XCTAssertEqual(document.id, decoded.id)
        XCTAssertEqual(document.name, decoded.name)
        XCTAssertEqual(document.components.count, decoded.components.count)
        XCTAssertEqual(document.connections.count, decoded.connections.count)
    }

    @MainActor
    func testAddConnectionRejectsUnknownEndpoints() throws {
        let store = CADDocumentStore.shared
        store.resetForTests()
        _ = store.createDocument(name: "Dangling Guard")
        let profile = ProfileInstance(profileId: "profile-40x40-eu", length: 500)
        let connector = ConnectorInstance(connectorId: "connector-corner-40")
        _ = try store.addComponent(.profile(profile))
        _ = try store.addComponent(.connector(connector))

        do {
            _ = try store.addConnection(ConnectionEdge(fromComponentID: "missing-a", toComponentID: "missing-b"))
            XCTFail("expected both-missing endpoints to be rejected")
        } catch let error as CADDocumentStoreError {
            XCTAssertEqual(error, .componentNotFound("missing-a"))
        }
        do {
            _ = try store.addConnection(ConnectionEdge(fromComponentID: profile.id, toComponentID: "missing-b"))
            XCTFail("expected a missing target endpoint to be rejected")
        } catch let error as CADDocumentStoreError {
            XCTAssertEqual(error, .componentNotFound("missing-b"))
        }
        XCTAssertTrue(store.selectedDocument?.connections.isEmpty == true)

        _ = try store.addConnection(ConnectionEdge(fromComponentID: profile.id, toComponentID: connector.id))
        XCTAssertEqual(store.selectedDocument?.connections.count, 1)
    }

    func testCADDocumentDecodeMissingFields() throws {
        // 验证向后兼容：缺失字段时使用默认值
        let json = "{\"id\":\"test-id\",\"name\":\"minimal\"}"
        let document = try JSONDecoder().decode(CADDocument.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(document.id, "test-id")
        XCTAssertEqual(document.name, "minimal")
        XCTAssertTrue(document.components.isEmpty)
        XCTAssertTrue(document.connections.isEmpty)
    }

    // MARK: - BOM Generator

    @MainActor
    func testBOMAggregationGroupsIdenticalProfiles() {
        let store = CADDocumentStore.shared
        store.resetForTests()
        _ = store.createDocument(name: "BOM Test")

        // 放置 3 根相同规格、相同长度的型材
        let instance1 = ProfileInstance(profileId: "profile-40x40-eu", length: 500)
        let instance2 = ProfileInstance(profileId: "profile-40x40-eu", length: 500)
        let instance3 = ProfileInstance(profileId: "profile-40x40-eu", length: 800) // 不同长度
        try? store.addComponent(.profile(instance1))
        try? store.addComponent(.profile(instance2))
        try? store.addComponent(.profile(instance3))

        let report = BOMGenerator().generate(from: store.selectedDocument!, library: library)

        // 应聚合为 2 行：500mm × 2，800mm × 1
        let length500Item = report.items.first { $0.length == 500 }
        let length800Item = report.items.first { $0.length == 800 }
        XCTAssertEqual(length500Item?.quantity, 2)
        XCTAssertEqual(length800Item?.quantity, 1)
        XCTAssertEqual(report.totalComponentCount, 3)
    }

    @MainActor
    func testBOMKeepsDistinctFractionalLengths() {
        let store = CADDocumentStore.shared
        store.resetForTests()
        _ = store.createDocument(name: "Fractional BOM")

        try? store.addComponent(.profile(ProfileInstance(profileId: "profile-40x40-eu", length: 500.25)))
        try? store.addComponent(.profile(ProfileInstance(profileId: "profile-40x40-eu", length: 500.75)))

        let report = BOMGenerator().generate(from: store.selectedDocument!, library: library)
        let profileItems = report.items.filter { $0.length > 0 }

        // 不同小数长度不得被截断合并为同一行。
        XCTAssertEqual(profileItems.count, 2)
        XCTAssertEqual(Set(profileItems.map(\.quantity)), [1])
        XCTAssertEqual(Set(profileItems.map(\.length)), [500.25, 500.75])
        XCTAssertTrue(profileItems.contains { $0.description.contains("500.25mm") })
        XCTAssertTrue(profileItems.contains { $0.description.contains("500.75mm") })
    }

    @MainActor
    func testBOMWeightCalculation() {
        let store = CADDocumentStore.shared
        store.resetForTests()
        _ = store.createDocument(name: "Weight Test")

        let spec = library.profileSpec(id: "profile-40x40-eu")!
        let length: Double = 1000 // 1 米
        let instance = ProfileInstance(profileId: spec.id, length: length)
        try? store.addComponent(.profile(instance))

        let report = BOMGenerator().generate(from: store.selectedDocument!, library: library)
        // 1 米型材重量应等于米重
        XCTAssertEqual(report.totalWeight, spec.weightPerMeter, accuracy: 0.001)
    }

    // MARK: - Cut Optimizer

    func testCutOptimizerFFDPacking() {
        let optimizer = CutOptimizer()
        // 文档第 4.7 节示例：[500, 800, 300, 1200, 600]，原料 6000
        let result = optimizer.optimize(demands: [500, 800, 300, 1200, 600], stockLength: 6000)

        let totalCut = result.stocks.flatMap(\.cuts).reduce(0, +)
        XCTAssertEqual(totalCut, 3400, accuracy: 0.001, "所有切割长度之和应等于需求总和")
        XCTAssertEqual(result.totalRemainder, 6000 - 3400, accuracy: 0.001)
        XCTAssertEqual(result.stockCount, 1, "总需求 3400 < 6000，应只需 1 根原料")
    }

    func testCutOptimizerMultipleStocks() {
        let optimizer = CutOptimizer()
        // 总需求超过单根原料，应开多根。
        // 6000 容量放 4000 后剩 2000，放不下第二个 4000，故每根只能放 1 个 → 3 根。
        let result = optimizer.optimize(demands: [4000, 4000, 4000], stockLength: 6000)
        XCTAssertEqual(result.stockCount, 3, "3 × 4000，每根 6000 原料只能放 1 个，需 3 根")
    }

    func testCutOptimizerFFDMergesSmallDemands() {
        let optimizer = CutOptimizer()
        // FFD 降序后 [3000, 2000, 2000, 1000]：
        // 第 1 根：3000 + 2000 = 5000（剩 1000，放不下第二个 2000，可放 1000）= 6000 满
        // 第 2 根：2000（剩 4000）
        let result = optimizer.optimize(demands: [3000, 2000, 2000, 1000], stockLength: 6000)
        XCTAssertEqual(result.stockCount, 2, "FFD 应将 3000+2000+1000 合并到第 1 根，2000 放第 2 根")
        XCTAssertEqual(result.stocks[0].cuts.sorted(by: >), [3000, 2000, 1000])
    }

    func testCutOptimizerEmptyDemands() {
        let optimizer = CutOptimizer()
        let result = optimizer.optimize(demands: [], stockLength: 6000)
        XCTAssertEqual(result.stockCount, 0)
        XCTAssertEqual(result.totalRemainder, 0)
    }

    func testCutOptimizerReportsOversizedDemand() {
        let optimizer = CutOptimizer()
        // 超过原料长度的需求不参与排料，但必须被显式报告而不是静默丢弃
        let result = optimizer.optimize(demands: [7000, 500], stockLength: 6000)
        XCTAssertEqual(result.stockCount, 1)
        let totalCut = result.stocks.flatMap(\.cuts).reduce(0, +)
        XCTAssertEqual(totalCut, 500, accuracy: 0.001)
        XCTAssertEqual(result.unschedulableDemands, [7000])
    }

    func testCutOptimizerReportsOnlyUnschedulableDemands() {
        // 全部需求都超长时，不能返回一个“无需求”的空结果
        let result = CutOptimizer().optimize(demands: [8000, 7000], stockLength: 6000)
        XCTAssertEqual(result.stockCount, 0)
        XCTAssertEqual(result.unschedulableDemands, [8000, 7000])
    }

    // MARK: - Component Library

    func testComponentLibraryHasStandardProfiles() {
        // 文档第 4.3 节：20/30/40 系列应有代表性规格
        XCTAssertNotNil(library.profileSpec(id: "profile-20x20-eu"))
        XCTAssertNotNil(library.profileSpec(id: "profile-30x30-eu"))
        XCTAssertNotNil(library.profileSpec(id: "profile-40x40-eu"))
        XCTAssertNotNil(library.profileSpec(id: "profile-40x80-eu"))
        XCTAssertNotNil(library.profileSpec(id: "profile-40x160-eu"))
    }

    func testComponentLibraryHasConnectors() {
        // 文档第 4.4 节：角码/螺栓/螺母/端盖/合页
        XCTAssertFalse(library.connectors.filter { $0.kind == .cornerBracket }.isEmpty)
        XCTAssertFalse(library.connectors.filter { $0.kind == .bolt }.isEmpty)
        XCTAssertFalse(library.connectors.filter { $0.kind == .nut }.isEmpty)
        XCTAssertFalse(library.connectors.filter { $0.kind == .endCap }.isEmpty)
    }

    func testProfileWeightByLength() {
        let spec = library.profileSpec(id: "profile-40x40-eu")!
        let instance = ProfileInstance(profileId: spec.id, length: 2000) // 2 米
        XCTAssertEqual(instance.weight(spec: spec), spec.weightPerMeter * 2, accuracy: 0.001)
    }

    // MARK: - Project Save/Load

    func testProjectSaveLoadRoundTrip() throws {
        let service = ProjectSaveLoadService()
        let document = CADDocument(
            name: "SaveLoad Test",
            components: [.profile(ProfileInstance(profileId: "profile-40x40-eu", length: 1000))]
        )

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CADDesignerTest-\(UUID().uuidString).cadproj")
        try service.save(document: document, to: url)
        let loaded = try service.load(from: url)
        try? FileManager.default.removeItem(at: url)

        XCTAssertEqual(document.id, loaded.id)
        XCTAssertEqual(document.name, loaded.name)
        XCTAssertEqual(document.components.count, loaded.components.count)
    }

    func testNativeProjectContentTypeAcceptsCadprojExtension() {
        let type = UTType.cadDesignerProject
        let extensions = type.tags[.filenameExtension] ?? []
        XCTAssertTrue(
            extensions.contains("cadproj") || type.preferredFilenameExtension == "cadproj",
            "Load/Save panels must accept the native .cadproj extension"
        )
        XCTAssertTrue(type.conforms(to: .json))
    }

    // MARK: - File Association Open

    @MainActor
    func testOpenProjectURLFromFileAssociationLoadsSelectedProject() throws {
        let store = CADDocumentStore.shared
        store.resetForTests()
        let document = CADDocument(
            name: "Finder Open",
            components: [.profile(ProfileInstance(profileId: "profile-40x40-eu", length: 700))]
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CADFinderOpen-\(UUID().uuidString).cadproj")
        try ProjectSaveLoadService().save(document: document, to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let viewModel = CADWorkspaceViewModel(store: store, library: library)
        // 工作区启动时会自动创建空项目；系统打开的文件必须替换为选中的项目。
        XCTAssertEqual(store.selectedDocument?.name, "Untitled Project")

        viewModel.openProjectURL(url)

        XCTAssertEqual(store.selectedDocument?.name, "Finder Open")
        XCTAssertEqual(store.selectedDocument?.components.count, 1)
        XCTAssertEqual(store.lastExportURL, url)
        XCTAssertNil(store.lastError)
    }

    @MainActor
    func testOpenProjectURLRejectsUnsupportedExtensionWithoutReplacingWorkspace() throws {
        let store = CADDocumentStore.shared
        store.resetForTests()
        _ = store.createDocument(name: "Keep Me")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notes-\(UUID().uuidString).txt")
        try "not a project".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let viewModel = CADWorkspaceViewModel(store: store, library: library)
        viewModel.openProjectURL(url)

        XCTAssertEqual(store.selectedDocument?.name, "Keep Me")
        XCTAssertEqual(store.documents.count, 1)
        XCTAssertNotNil(store.lastError)
    }

    @MainActor
    func testOpenProjectURLReportsUndecodableFileWithoutReplacingWorkspace() throws {
        let store = CADDocumentStore.shared
        store.resetForTests()
        _ = store.createDocument(name: "Keep Me")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-\(UUID().uuidString).cadproj")
        try "{ not valid json".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let viewModel = CADWorkspaceViewModel(store: store, library: library)
        viewModel.openProjectURL(url)

        XCTAssertEqual(store.selectedDocument?.name, "Keep Me")
        XCTAssertEqual(store.documents.count, 1)
        XCTAssertNotNil(store.lastError, "加载失败必须暴露对应文件的错误，而不是静默保留空项目")
    }
}
