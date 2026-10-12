import AppKit
import Foundation
import SceneKit

/// 场景控制器：管理 SCNScene 的相机、灯光、网格、坐标轴、装配根节点，并同步组件节点。
@MainActor
public final class CADSceneController: ObservableObject {
    public static let assemblyNodeName = "assembly_root"
    public static let gridNodeName = "grid"
    public static let axisNodeName = "axis"

    public let scene: SCNScene
    public let cameraNode: SCNNode
    public let assemblyNode: SCNNode

    private let renderer = ComponentRenderer()
    private let library: ComponentLibrary

    /// componentId → 节点映射，便于增量更新。
    private var nodeMap: [String: SCNNode] = [:]
    private var selectionOutline: SCNNode?

    @Published public var selectedComponentId: String?

    public init(library: ComponentLibrary = .shared) {
        self.library = library
        self.scene = SCNScene()
        self.cameraNode = SCNNode()
        self.assemblyNode = SCNNode()

        scene.background.contents = NSColor.windowBackgroundColor

        setupCamera()
        setupLighting()
        setupGrid()
        setupAxis()
        scene.rootNode.addChildNode(assemblyNode)
    }

    // MARK: - Setup

    private func setupCamera() {
        let camera = SCNCamera()
        camera.zNear = 1
        camera.zFar = 100000
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(600, 500, 800)
        cameraNode.eulerAngles = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
        lookAtOrigin()
    }

    private func setupLighting() {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(white: 0.6, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let directional = SCNLight()
        directional.type = .directional
        directional.color = NSColor(white: 0.9, alpha: 1)
        directional.castsShadow = true
        directional.shadowSampleCount = 4
        let dirNode = SCNNode()
        dirNode.light = directional
        dirNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        dirNode.position = SCNVector3(400, 800, 400)
        scene.rootNode.addChildNode(dirNode)
    }

    /// 参考网格（XZ 平面）。
    private func setupGrid() {
        let gridNode = makeGridNode(size: 1000, divisions: 20)
        gridNode.name = Self.gridNodeName
        scene.rootNode.addChildNode(gridNode)
    }

    /// XYZ 坐标轴。
    private func setupAxis() {
        let axisNode = makeAxisNode(length: 80)
        axisNode.name = Self.axisNodeName
        scene.rootNode.addChildNode(axisNode)
    }

    // MARK: - Camera

    public func lookAtOrigin() {
        let constraint = SCNLookAtConstraint(target: scene.rootNode)
        cameraNode.constraints = [constraint]
    }

    /// 重置相机到默认视角。
    public func resetCamera() {
        cameraNode.constraints = []
        cameraNode.position = SCNVector3(600, 500, 800)
        cameraNode.eulerAngles = SCNVector3(0, 0, 0)
        lookAtOrigin()
    }

    // MARK: - Component Sync

    /// 全量重建装配节点（基于文档）。
    public func syncComponents(from document: CADDocument) {
        assemblyNode.enumerateChildNodes { node, _ in node.removeFromParentNode() }
        nodeMap.removeAll()
        selectionOutline?.removeFromParentNode()
        selectionOutline = nil

        for component in document.components {
            let node = makeNode(for: component)
            assemblyNode.addChildNode(node)
            nodeMap[component.id] = node
        }
        updateSelectionHighlight()
    }

    private func makeNode(for component: CADComponent) -> SCNNode {
        switch component {
        case .profile(let instance):
            guard let spec = library.profileSpec(id: instance.profileId) else {
                return SCNNode()
            }
            let node = renderer.makeProfileNode(spec: spec, length: instance.length, componentId: instance.id)
            renderer.applyTransform(instance.transform, to: node)
            return node
        case .connector(let instance):
            guard let spec = library.connectorSpec(id: instance.connectorId) else {
                return SCNNode()
            }
            let node = renderer.makeConnectorNode(spec: spec, componentId: instance.id)
            renderer.applyTransform(instance.transform, to: node)
            return node
        }
    }

    // MARK: - Selection

    public func selectComponent(id: String?) {
        selectedComponentId = id
        updateSelectionHighlight()
    }

    private func updateSelectionHighlight() {
        selectionOutline?.removeFromParentNode()
        selectionOutline = nil

        guard let id = selectedComponentId, let node = nodeMap[id] else { return }
        let outline = renderer.makeSelectionOutlineNode(for: node)
        node.addChildNode(outline)
        selectionOutline = outline
    }

    /// 通过点击位置命中测试，返回命中组件 ID。
    public func hitTest(point: CGPoint, in scnView: SCNView) -> String? {
        let results = scnView.hitTest(point, options: [.boundingBoxOnly: false, .ignoreHiddenNodes: true])
        for result in results {
            var node: SCNNode? = result.node
            while let current = node {
                if let name = current.name, nodeMap[name] != nil, name != Self.gridNodeName, name != Self.axisNodeName {
                    return name
                }
                node = current.parent
            }
        }
        return nil
    }

    // MARK: - Grid & Axis Builders

    private func makeGridNode(size: CGFloat, divisions: Int) -> SCNNode {
        let gridGeometry = SCNFloor()
        gridGeometry.reflectivity = 0
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(white: 0.85, alpha: 0.3)
        material.transparency = 0.3
        gridGeometry.materials = [material]
        let floorNode = SCNNode(geometry: gridGeometry)

        // 网格线（用细长立方体）
        let lineNode = SCNNode()
        let step = size / CGFloat(divisions)
        let half = size / 2
        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = NSColor.separatorColor
        lineMaterial.emission.contents = NSColor.separatorColor
        lineMaterial.lightingModel = .constant

        // 平行 X 轴的线
        for i in 0...divisions {
            let z = -half + step * CGFloat(i)
            let line = SCNBox(width: size, height: 0.5, length: 0.5, chamferRadius: 0)
            line.materials = [lineMaterial]
            let n = SCNNode(geometry: line)
            n.position = SCNVector3(0, 0, z)
            lineNode.addChildNode(n)
        }
        // 平行 Z 轴的线
        for i in 0...divisions {
            let x = -half + step * CGFloat(i)
            let line = SCNBox(width: 0.5, height: 0.5, length: size, chamferRadius: 0)
            line.materials = [lineMaterial]
            let n = SCNNode(geometry: line)
            n.position = SCNVector3(x, 0, 0)
            lineNode.addChildNode(n)
        }

        let root = SCNNode()
        root.addChildNode(floorNode)
        root.addChildNode(lineNode)
        return root
    }

    private func makeAxisNode(length: CGFloat) -> SCNNode {
        let root = SCNNode()
        let radius: CGFloat = 1.5

        // X 轴（红）
        let xAxis = SCNCylinder(radius: radius, height: length)
        xAxis.firstMaterial?.diffuse.contents = NSColor.systemRed
        xAxis.firstMaterial?.lightingModel = .constant
        let xNode = SCNNode(geometry: xAxis)
        xNode.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
        xNode.position = SCNVector3(Float(length) / 2, 0, 0)

        // Y 轴（绿）
        let yAxis = SCNCylinder(radius: radius, height: length)
        yAxis.firstMaterial?.diffuse.contents = NSColor.systemGreen
        yAxis.firstMaterial?.lightingModel = .constant
        let yNode = SCNNode(geometry: yAxis)
        yNode.position = SCNVector3(0, Float(length) / 2, 0)

        // Z 轴（蓝）
        let zAxis = SCNCylinder(radius: radius, height: length)
        zAxis.firstMaterial?.diffuse.contents = NSColor.systemBlue
        zAxis.firstMaterial?.lightingModel = .constant
        let zNode = SCNNode(geometry: zAxis)
        zNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        zNode.position = SCNVector3(0, 0, Float(length) / 2)

        root.addChildNode(xNode)
        root.addChildNode(yNode)
        root.addChildNode(zNode)
        return root
    }
}
