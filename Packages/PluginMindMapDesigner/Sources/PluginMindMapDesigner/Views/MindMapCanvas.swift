import SwiftUI

/// 思维导图画布：渲染连线 + 节点，支持拖拽平移、缩放、单击选中、双击编辑。
struct MindMapCanvas: View {
    let map: MindMap
    let scope: MindMapScope
    @Binding var selectedNodeId: String?
    @Binding var editingNodeId: String?
    @Binding var scale: CGFloat

    @ObservedObject private var store: MindMapStore
    @State private var dragOffset: CGSize = .zero

    private let padding: CGFloat = 48

    init(
        map: MindMap,
        scope: MindMapScope,
        selectedNodeId: Binding<String?>,
        editingNodeId: Binding<String?>,
        scale: Binding<CGFloat>,
        store: MindMapStore
    ) {
        self.map = map
        self.scope = scope
        self._selectedNodeId = selectedNodeId
        self._editingNodeId = editingNodeId
        self._scale = scale
        self.store = store
    }

    var body: some View {
        GeometryReader { _ in
            let result = MindMapLayoutEngine.layout(map)
            let origin = result.bounds.origin
            let contentWidth = max(result.bounds.width, 0) + padding * 2
            let contentHeight = max(result.bounds.height, 0) + padding * 2

            ZStack {
                Color(nsColor: .textBackgroundColor).opacity(0.001)

                // 连线层
                connectionLayer(result: result, origin: origin)

                // 节点层
                ForEach(map.nodes) { node in
                    if let layout = result.nodes[node.id] {
                        let normalized = CGPoint(
                            x: layout.center.x - origin.x + padding,
                            y: layout.center.y - origin.y + padding
                        )
                        MindMapNodeView(
                            node: node,
                            size: layout.size,
                            isRoot: node.parentId == nil,
                            isSelected: selectedNodeId == node.id,
                            isEditing: editingNodeId == node.id,
                            onTap: { selectedNodeId = node.id; editingNodeId = nil },
                            onDoubleTap: {
                                selectedNodeId = node.id
                                editingNodeId = node.id
                            },
                            onCommit: { newText in commitEdit(node: node, text: newText) }
                        )
                        .position(normalized)
                    }
                }
            }
            .frame(width: contentWidth, height: contentHeight)
            .scaleEffect(scale)
            .offset(dragOffset)
            .gesture(magnification)
            .gesture(drag)
            .onTapGesture {
                selectedNodeId = nil
                editingNodeId = nil
            }
        }
        // 切换思维导图时重置视图状态。
        .onChange(of: map.id) { _, _ in
            selectedNodeId = nil
            editingNodeId = nil
            scale = 1.0
            dragOffset = .zero
        }
    }

    // MARK: - Connection Layer

    @ViewBuilder
    private func connectionLayer(result: MindMapLayoutEngine.Result, origin: CGPoint) -> some View {
        Canvas { context, _ in
            for (fromId, toId) in result.edges {
                guard let f = result.nodes[fromId], let t = result.nodes[toId] else { continue }
                let fp = CGPoint(x: f.center.x - origin.x + padding, y: f.center.y - origin.y + padding)
                let tp = CGPoint(x: t.center.x - origin.x + padding, y: t.center.y - origin.y + padding)
                var path = Path()
                appendBezier(&path, from: fp, fromSize: f.size, to: tp, toSize: t.size, direction: map.layoutDirection)
                context.stroke(path, with: .color(.secondary.opacity(0.45)), lineWidth: 1.5)
            }
        }
    }

    /// 在水平（bilateral/right）或垂直（down）方向绘制父→子的平滑贝塞尔。
    private func appendBezier(
        _ path: inout Path,
        from fp: CGPoint, fromSize: CGSize,
        to tp: CGPoint, toSize: CGSize,
        direction: MindMapLayoutDirection
    ) {
        if direction == .down {
            let sx = fp.x
            let sy = fp.y + fromSize.height / 2
            let ex = tp.x
            let ey = tp.y - toSize.height / 2
            let mid = (sy + ey) / 2
            path.move(to: CGPoint(x: sx, y: sy))
            path.addCurve(to: CGPoint(x: ex, y: ey),
                          control1: CGPoint(x: sx, y: mid),
                          control2: CGPoint(x: ex, y: mid))
            return
        }
        // 水平：根据相对 x 决定出发/进入边缘。
        let childIsRight = tp.x >= fp.x
        let sx = childIsRight ? fp.x + fromSize.width / 2 : fp.x - fromSize.width / 2
        let sy = fp.y
        let ex = childIsRight ? tp.x - toSize.width / 2 : tp.x + toSize.width / 2
        let ey = tp.y
        let mid = (sx + ex) / 2
        path.move(to: CGPoint(x: sx, y: sy))
        path.addCurve(to: CGPoint(x: ex, y: ey),
                      control1: CGPoint(x: mid, y: sy),
                      control2: CGPoint(x: mid, y: ey))
    }

    // MARK: - Editing

    private func commitEdit(node: MindMapNode, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            do {
                _ = try store.updateNode(
                    mapId: map.id, nodeId: node.id, scope: scope,
                    text: trimmed, note: nil, color: nil, collapsed: nil
                )
            } catch {
                store.setError(error.localizedDescription)
            }
        }
        editingNodeId = nil
    }

    // MARK: - Gestures

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(0.3, min(3.0, value))
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in dragOffset = value.translation }
            .onEnded { _ in }
    }
}
