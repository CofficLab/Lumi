import Foundation
import SwiftUI

/// CAD 工作区视图模型：协调 Store、SceneController 与工具状态。
@MainActor
final class CADWorkspaceViewModel: ObservableObject {
    @Published var currentTool: CADToolKind = .select
    @Published var bomReport: BOMReport?
    @Published var cutResult: CutOptimizationResult?
    @Published var stockLength: Double = 6000
    @Published var measurement: MeasurementResult?
    @Published var isExporting = false

    let store: CADDocumentStore
    let sceneController: CADSceneController
    let bomGenerator = BOMGenerator()
    let cutOptimizer = CutOptimizer()
    let saveLoadService = ProjectSaveLoadService()
    let screenshotExporter = ScreenshotExporter()
    let library: ComponentLibrary

    init(
        store: CADDocumentStore = .shared,
        library: ComponentLibrary = .shared
    ) {
        self.store = store
        self.library = library
        self.sceneController = CADSceneController(library: library)

        // 若无文档则自动创建一个空项目，便于直接开始设计。
        if store.selectedDocument == nil {
            store.createDocument(name: nil)
        }
        syncScene()
    }

    var document: CADDocument? { store.selectedDocument }
    var selectedComponent: CADComponent? { store.selectedComponent }

    // MARK: - Component Operations

    /// 从组件库添加型材到场景。
    @discardableResult
    func placeProfile(spec: ProfileSpec, length: Double = 500) -> CADComponent? {
        let instance = ProfileInstance(
            profileId: spec.id,
            length: length,
            transform: nextPlacementTransform()
        )
        do {
            let component = try store.addComponent(.profile(instance))
            syncScene()
            refreshBOM()
            return component
        } catch {
            store.setError(error.localizedDescription)
            return nil
        }
    }

    /// 从组件库添加连接件到场景。
    @discardableResult
    func placeConnector(spec: ConnectorSpec) -> CADComponent? {
        let instance = ConnectorInstance(
            connectorId: spec.id,
            transform: nextPlacementTransform()
        )
        do {
            let component = try store.addComponent(.connector(instance))
            syncScene()
            refreshBOM()
            return component
        } catch {
            store.setError(error.localizedDescription)
            return nil
        }
    }

    /// 批量添加组件（用于 BuildFrame 等批量操作）。
    @discardableResult
    func placeComponents(_ components: [CADComponent]) -> [CADComponent] {
        do {
            let added = try store.addComponents(components)
            syncScene()
            refreshBOM()
            return added
        } catch {
            store.setError(error.localizedDescription)
            return []
        }
    }

    /// 更新选中组件的长度（仅对型材有效）。
    func updateSelectedProfileLength(_ length: Double) {
        guard case .profile(var instance)? = store.selectedComponent else { return }
        instance.length = length
        do {
            try store.updateComponent(id: instance.id) { component in
                if case .profile(var current) = component {
                    current.length = length
                    component = .profile(current)
                }
            }
            syncScene()
            refreshBOM()
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    /// 更新选中组件的变换。
    func updateSelectedComponentTransform(_ transform: Transform3D) {
        guard let componentId = store.selectedComponentId else { return }
        do {
            try store.updateComponent(id: componentId) { component in
                component.transform = transform
            }
            syncScene()
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    /// 删除选中组件。
    func deleteSelectedComponent() {
        guard let id = store.selectedComponentId else { return }
        do {
            try store.deleteComponent(id: id)
            sceneController.selectComponent(id: nil)
            syncScene()
            refreshBOM()
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    func selectComponent(id: String?) {
        store.selectComponent(id: id)
        sceneController.selectComponent(id: id)
    }

    // MARK: - BOM & Cut Optimization

    func refreshBOM() {
        guard let document else {
            bomReport = nil
            return
        }
        bomReport = bomGenerator.generate(from: document, library: library)
    }

    func runCutOptimization() {
        guard let document else {
            cutResult = nil
            return
        }
        let demands = document.components.compactMap { component -> Double? in
            if case .profile(let instance) = component {
                return instance.length
            }
            return nil
        }
        cutResult = cutOptimizer.optimize(demands: demands, stockLength: stockLength)
    }

    // MARK: - Measurement

    /// 计算两选中点之间的距离（基于点击拾取的两个组件）。
    func measure(from fromId: String, to toId: String) {
        guard let document,
              let from = document.component(id: fromId),
              let to = document.component(id: toId) else {
            measurement = nil
            return
        }
        let p1 = from.transform
        let p2 = to.transform
        let dx = p2.positionX - p1.positionX
        let dy = p2.positionY - p1.positionY
        let dz = p2.positionZ - p1.positionZ
        let distance = (dx * dx + dy * dy + dz * dz).squareRoot()
        measurement = MeasurementResult(fromComponentId: fromId, toComponentId: toId, distance: distance)
    }

    // MARK: - Persistence

    func saveProject(to url: URL) {
        guard let document else { return }
        do {
            try saveLoadService.save(document: document, to: url)
            store.setExportURL(url)
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    func loadProject(from url: URL) {
        do {
            let loaded = try saveLoadService.load(from: url)
            _ = store.importDocument(loaded)
            syncScene()
            refreshBOM()
            store.setExportURL(url)
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    // MARK: - Undo / Redo

    func undo() {
        store.undo()
        syncScene()
        refreshBOM()
    }

    func redo() {
        store.redo()
        syncScene()
        refreshBOM()
    }

    // MARK: - Scene Sync

    /// 把当前文档全量同步到场景。
    func syncScene() {
        if let document {
            sceneController.syncComponents(from: document)
            sceneController.selectComponent(id: store.selectedComponentId)
        }
    }

    func resetCamera() {
        sceneController.resetCamera()
    }

    // MARK: - Private

    /// 下一个组件的放置位置：轻微错开，避免堆叠重叠。
    private func nextPlacementTransform() -> Transform3D {
        let count = store.selectedDocument?.components.count ?? 0
        let offset = Double(count % 8) * 80
        return Transform3D(positionX: offset, positionY: 40, positionZ: 0)
    }
}
