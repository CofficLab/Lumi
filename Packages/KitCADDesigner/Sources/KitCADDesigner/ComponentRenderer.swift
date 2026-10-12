import AppKit
import Foundation
import SceneKit

/// 型材/连接件 SceneKit 渲染（文档第 4.2、5.2 节）。
///
/// 型材通过参数化截面（矩形 + 中央 T 槽）+ `SCNShape` 沿 X 轴拉伸生成。
/// 坐标系：长度沿 X 轴，截面在 YZ 平面（截面中心在原点）。
public struct ComponentRenderer {
    public init() {}

    /// 创建型材包装节点。
    ///
    /// 返回一个**包装节点**（命名 = componentId），其子节点是实际几何体节点（已预对齐轴向）。
    /// 包装节点用于承载 Transform3D（位置/旋转/缩放），子节点负责把 SCNShape 默认 Z 轴拉伸对齐到 X 轴。
    public func makeProfileNode(spec: ProfileSpec, length: Double, componentId: String) -> SCNNode {
        let geometry = createProfileGeometry(spec: spec, length: length)
        let geometryNode = SCNNode(geometry: geometry)
        geometryNode.castsShadow = true
        // SCNShape 沿 Z 轴拉伸 → 绕 Y 轴旋转 90° 对齐到 X 轴
        geometryNode.eulerAngles = SCNVector3(0, CGFloat.pi / 2, 0)
        // 让型材沿 X 轴居中（默认从 0 拉伸到 +length，中心需偏移 -length/2）
        geometryNode.position = SCNVector3(-length / 2, 0, 0)

        let wrapper = SCNNode()
        wrapper.name = componentId
        wrapper.addChildNode(geometryNode)
        return wrapper
    }

    /// 创建连接件节点（简化为小型立方体/圆柱体表示）。
    public func makeConnectorNode(spec: ConnectorSpec, componentId: String) -> SCNNode {
        let geometry = createConnectorGeometry(spec: spec)
        let node = SCNNode(geometry: geometry)
        node.name = componentId
        node.castsShadow = true
        return node
    }

    /// 创建选中高亮框节点。
    public func makeSelectionOutlineNode(for target: SCNNode) -> SCNNode {
        let (min, max) = target.boundingBox
        let size = SCNVector3(max.x - min.x, max.y - min.y, max.z - min.z)
        let center = SCNVector3((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
        let box = SCNBox(width: CGFloat(size.x) * 1.05,
                         height: CGFloat(size.y) * 1.05,
                         length: CGFloat(size.z) * 1.05,
                         chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = NSColor.clear
        box.firstMaterial?.emission.contents = NSColor.systemOrange
        box.firstMaterial?.isDoubleSided = true
        box.firstMaterial?.lightingModel = .constant
        let outline = SCNNode(geometry: box)
        outline.position = center
        outline.name = "selection_outline"
        return outline
    }

    // MARK: - Profile Geometry

    /// 参数化截面轮廓（矩形 + 4 面 T 槽凹槽）→ NSBezierPath。
    ///
    /// 截面中心位于原点，宽高由 spec 决定，每面中央开一个 T 槽凹口。
    private func sectionPath(spec: ProfileSpec) -> NSBezierPath {
        let halfW = spec.width / 2
        let halfH = spec.height / 2
        let slotW = spec.slotWidth / 2
        let slotD = spec.slotDepth

        let path = NSBezierPath()

        // 简化的矩形截面带 4 面 T 槽凹口（顺时针描点，含凹槽）
        // 起点：左上角
        path.move(to: NSPoint(x: -halfW, y: halfH))
        // 顶边：左上 → 顶槽左 → 凹入 → 顶槽右 → 右上
        path.line(to: NSPoint(x: -slotW, y: halfH))
        path.line(to: NSPoint(x: -slotW, y: halfH - slotD))
        path.line(to: NSPoint(x: slotW, y: halfH - slotD))
        path.line(to: NSPoint(x: slotW, y: halfH))
        path.line(to: NSPoint(x: halfW, y: halfH))

        // 右边：右上 → 右槽上 → 凹入 → 右槽下 → 右下
        path.line(to: NSPoint(x: halfW, y: slotW))
        path.line(to: NSPoint(x: halfW - slotD, y: slotW))
        path.line(to: NSPoint(x: halfW - slotD, y: -slotW))
        path.line(to: NSPoint(x: halfW, y: -slotW))
        path.line(to: NSPoint(x: halfW, y: -halfH))

        // 底边：右下 → 底槽右 → 凹入 → 底槽左 → 左下
        path.line(to: NSPoint(x: slotW, y: -halfH))
        path.line(to: NSPoint(x: slotW, y: -halfH + slotD))
        path.line(to: NSPoint(x: -slotW, y: -halfH + slotD))
        path.line(to: NSPoint(x: -slotW, y: -halfH))
        path.line(to: NSPoint(x: -halfW, y: -halfH))

        // 左边：左下 → 左槽下 → 凹入 → 左槽上 → 左上（闭合）
        path.line(to: NSPoint(x: -halfW, y: -slotW))
        path.line(to: NSPoint(x: -halfW + slotD, y: -slotW))
        path.line(to: NSPoint(x: -halfW + slotD, y: slotW))
        path.line(to: NSPoint(x: -halfW, y: slotW))
        path.close()

        return path
    }

    /// 型材几何体：SCNShape 拉伸截面，长度沿 Z 轴（SCNShape 默认拉伸方向），
    /// 随后旋转使长度方向对齐 X 轴。
    private func createProfileGeometry(spec: ProfileSpec, length: CGFloat) -> SCNGeometry {
        let path = sectionPath(spec: spec)
        let shape = SCNShape(path: path, extrusionDepth: length)

        let material = SCNMaterial()
        material.diffuse.contents = NSColor.systemGray
        material.specular.contents = NSColor.white
        material.shininess = 0.3
        material.lightingModel = .physicallyBased
        shape.materials = [material]
        return shape
    }

    private func createProfileGeometry(spec: ProfileSpec, length: Double) -> SCNGeometry {
        createProfileGeometry(spec: spec, length: CGFloat(length))
    }

    // MARK: - Connector Geometry

    /// 连接件几何体（简化表示）。
    private func createConnectorGeometry(spec: ConnectorSpec) -> SCNGeometry {
        let geometry: SCNGeometry
        switch spec.kind {
        case .cornerBracket:
            // 角码：L 形近似为小立方体
            geometry = SCNBox(width: 20, height: 20, length: 20, chamferRadius: 2)
        case .bolt:
            // 螺栓：圆柱
            geometry = SCNCylinder(radius: 3, height: 24)
        case .nut:
            // 螺母：六角形近似为短圆柱
            geometry = SCNCylinder(radius: 5, height: 6)
        case .endCap:
            // 端盖：薄方块
            geometry = SCNBox(width: 8, height: 8, length: 2, chamferRadius: 1)
        case .hinge:
            // 合页：长方体
            geometry = SCNBox(width: 30, height: 10, length: 12, chamferRadius: 1)
        }

        let material = SCNMaterial()
        material.diffuse.contents = NSColor.systemBlue.withSystemEffect(.disabled)
        material.specular.contents = NSColor.white
        material.lightingModel = .physicallyBased
        geometry.materials = [material]
        return geometry
    }

    // MARK: - Transform

    /// 将 Transform3D 应用到包装节点（位置/旋转/缩放）。
    public func applyTransform(_ transform: Transform3D, to node: SCNNode) {
        node.position = SCNVector3(transform.positionX, transform.positionY, transform.positionZ)
        node.eulerAngles = SCNVector3(
            degreesToRadians(transform.rotationX),
            degreesToRadians(transform.rotationY),
            degreesToRadians(transform.rotationZ)
        )
        node.scale = SCNVector3(transform.scale, transform.scale, transform.scale)
    }

    private func degreesToRadians(_ degrees: Double) -> CGFloat {
        CGFloat(degrees) * .pi / 180
    }
}
