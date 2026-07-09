import Foundation
@testable import CADDesignerPlugin

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

    func testCutOptimizerOversizedDemandFiltered() {
        let optimizer = CutOptimizer()
        // 超过原料长度的需求应被过滤
        let result = optimizer.optimize(demands: [7000, 500], stockLength: 6000)
        XCTAssertEqual(result.stockCount, 1)
        let totalCut = result.stocks.flatMap(\.cuts).reduce(0, +)
        XCTAssertEqual(totalCut, 500, accuracy: 0.001)
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
}
