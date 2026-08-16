import AppKit
import Foundation

/// 单个节点在画布上的布局结果（中心坐标 + 尺寸）。
public struct MindMapNodeLayout: Equatable, Sendable {
    public var center: CGPoint
    public var size: CGSize

    public var origin: CGPoint {
        CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
    }

    /// 连线锚点：朝向父节点一侧的边缘中点（水平布局用）。
    public func anchor(towardParentIsLeft parentIsLeft: Bool) -> CGPoint {
        parentIsLeft
            ? CGPoint(x: origin.x, y: center.y)
            : CGPoint(x: origin.x + size.width, y: center.y)
    }
}

/// 布局参数。
public struct MindMapLayoutConfig: Sendable {
    public var fontSize: CGFloat
    public var fontWeight: NSFont.Weight
    public var nodeHeight: CGFloat
    public var horizontalPadding: CGFloat
    public var minNodeWidth: CGFloat
    /// 兄弟节点之间的间距（垂直堆叠方向）。
    public var siblingGap: CGFloat
    /// 父节点边缘到子节点边缘的间距。
    public var levelGap: CGFloat

    public init(
        fontSize: CGFloat = 14,
        fontWeight: NSFont.Weight = .medium,
        nodeHeight: CGFloat = 34,
        horizontalPadding: CGFloat = 16,
        minNodeWidth: CGFloat = 64,
        siblingGap: CGFloat = 12,
        levelGap: CGFloat = 72
    ) {
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.nodeHeight = nodeHeight
        self.horizontalPadding = horizontalPadding
        self.minNodeWidth = minNodeWidth
        self.siblingGap = siblingGap
        self.levelGap = levelGap
    }

    public static let `default` = MindMapLayoutConfig()
}

/// 「分层整洁树」布局引擎。
///
/// 双侧（bilateral）：根居中，直接子节点按索引奇偶分到左右两侧，各自递归布局。
/// 仅向右（right）/ 向下（down）：所有子节点在同一侧/下方展开。
/// 节点宽度按文本动态测量；垂直方向按子树高度堆叠，父节点居中于子节点跨度。
public enum MindMapLayoutEngine {
    public struct Result: Sendable {
        public var nodes: [String: MindMapNodeLayout]
        /// 父子连线：(fromNodeId, toNodeId)。
        public var edges: [(String, String)]
        /// 布后画布的包围盒（含根节点尺寸）。
        public var bounds: CGRect

        public static let empty = Result(nodes: [:], edges: [], bounds: .zero)
    }

    public static func layout(_ map: MindMap, config: MindMapLayoutConfig = .default) -> Result {
        guard let root = map.root else { return .empty }

        let sizes = measureAll(map, config: config)
        let childrenMap = buildChildrenMap(map)

        func visibleChildren(of id: String) -> [String] {
            guard let node = map.node(id: id), !node.collapsed else { return [] }
            return childrenMap[id] ?? []
        }

        var positions: [String: MindMapNodeLayout] = [:]

        switch map.layoutDirection {
        case .bilateral:
            layoutBilateral(rootId: root.id, sizes: sizes, visibleChildren: visibleChildren, config: config, positions: &positions)
        case .right:
            layoutSide(rootId: root.id, sizes: sizes, visibleChildren: visibleChildren, config: config, side: 1, positions: &positions, rootAnchored: true)
        case .down:
            layoutDown(rootId: root.id, sizes: sizes, visibleChildren: visibleChildren, config: config, positions: &positions)
        }

        let bounds = computeBounds(positions: positions)
        let edges = collectEdges(rootId: root.id, map: map, positions: positions)

        return Result(nodes: positions, edges: edges, bounds: bounds)
    }

    // MARK: - Measurement

    public static func measure(_ text: String, config: MindMapLayoutConfig) -> CGSize {
        let clean = text.isEmpty ? " " : text
        let font = NSFont.systemFont(ofSize: config.fontSize, weight: config.fontWeight)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        var size = (clean as NSString).size(withAttributes: attributes)
        size.width = ceil(size.width) + config.horizontalPadding * 2
        size.height = config.nodeHeight
        size.width = max(size.width, config.minNodeWidth)
        return size
    }

    private static func measureAll(_ map: MindMap, config: MindMapLayoutConfig) -> [String: CGSize] {
        var sizes: [String: CGSize] = [:]
        sizes.reserveCapacity(map.nodes.count)
        for node in map.nodes {
            sizes[node.id] = measure(node.text, config: config)
        }
        return sizes
    }

    private static func buildChildrenMap(_ map: MindMap) -> [String: [String]] {
        var map_: [String: [String]] = [:]
        for node in map.nodes {
            guard let parentId = node.parentId else { continue }
            map_[parentId, default: []].append(node.id)
        }
        return map_
    }

    // MARK: - Bilateral

    private static func layoutBilateral(
        rootId: String,
        sizes: [String: CGSize],
        visibleChildren: (String) -> [String],
        config: MindMapLayoutConfig,
        positions: inout [String: MindMapNodeLayout]
    ) {
        let rootSize = sizes[rootId] ?? .zero
        let kids = visibleChildren(rootId)
        var rightKids: [String] = []
        var leftKids: [String] = []
        for (index, kid) in kids.enumerated() {
            if index % 2 == 0 {
                rightKids.append(kid)
            } else {
                leftKids.append(kid)
            }
        }

        let rightHeight = groupHeight(kids: rightKids, visibleChildren: visibleChildren, config: config)
        let leftHeight = groupHeight(kids: leftKids, visibleChildren: visibleChildren, config: config)
        let totalHeight = max(rightHeight, leftHeight)
        let rootCenterY = totalHeight / 2
        let rootCenterX: CGFloat = 0
        positions[rootId] = MindMapNodeLayout(center: CGPoint(x: rootCenterX, y: rootCenterY), size: rootSize)

        // 右侧从上往下排
        var cursor = rootCenterY - rightHeight / 2
        for kid in rightKids {
            let h = layoutSide(
                nodeId: kid,
                parentCenterX: rootCenterX,
                parentHalfWidth: rootSize.width / 2,
                side: 1,
                yTop: cursor,
                sizes: sizes,
                visibleChildren: visibleChildren,
                config: config,
                positions: &positions
            ).height
            cursor += h + config.siblingGap
        }
        // 左侧
        cursor = rootCenterY - leftHeight / 2
        for kid in leftKids {
            let h = layoutSide(
                nodeId: kid,
                parentCenterX: rootCenterX,
                parentHalfWidth: rootSize.width / 2,
                side: -1,
                yTop: cursor,
                sizes: sizes,
                visibleChildren: visibleChildren,
                config: config,
                positions: &positions
            ).height
            cursor += h + config.siblingGap
        }
    }

    // MARK: - One Side (right)

    private static func layoutSide(
        rootId: String,
        sizes: [String: CGSize],
        visibleChildren: (String) -> [String],
        config: MindMapLayoutConfig,
        side: Int,
        positions: inout [String: MindMapNodeLayout],
        rootAnchored: Bool
    ) {
        let rootSize = sizes[rootId] ?? .zero
        let kids = visibleChildren(rootId)
        let totalHeight = groupHeight(kids: kids, visibleChildren: visibleChildren, config: config)
        let rootCenterY = totalHeight / 2
        let rootCenterX: CGFloat = 0
        positions[rootId] = MindMapNodeLayout(center: CGPoint(x: rootCenterX, y: rootCenterY), size: rootSize)

        var cursor = rootCenterY - totalHeight / 2
        for kid in kids {
            let h = layoutSide(
                nodeId: kid,
                parentCenterX: rootCenterX,
                parentHalfWidth: rootSize.width / 2,
                side: side,
                yTop: cursor,
                sizes: sizes,
                visibleChildren: visibleChildren,
                config: config,
                positions: &positions
            ).height
            cursor += h + config.siblingGap
        }
    }

    /// 递归布局单侧子树，返回 (节点 centerY, 子树高度)，并填充 positions。
    private static func layoutSide(
        nodeId: String,
        parentCenterX: CGFloat,
        parentHalfWidth: CGFloat,
        side: Int,
        yTop: CGFloat,
        sizes: [String: CGSize],
        visibleChildren: (String) -> [String],
        config: MindMapLayoutConfig,
        positions: inout [String: MindMapNodeLayout]
    ) -> (centerY: CGFloat, height: CGFloat) {
        let size = sizes[nodeId] ?? .zero
        let kids = visibleChildren(nodeId)
        let halfWidth = size.width / 2
        let centerX = parentCenterX + CGFloat(side) * (parentHalfWidth + config.levelGap + halfWidth)

        if kids.isEmpty {
            let centerY = yTop + config.nodeHeight / 2
            positions[nodeId] = MindMapNodeLayout(center: CGPoint(x: centerX, y: centerY), size: size)
            return (centerY, config.nodeHeight)
        }

        var cursor = yTop
        var firstCenterY: CGFloat?
        var lastCenterY: CGFloat = 0
        for kid in kids {
            let (cy, h) = layoutSide(
                nodeId: kid,
                parentCenterX: centerX,
                parentHalfWidth: halfWidth,
                side: side,
                yTop: cursor,
                sizes: sizes,
                visibleChildren: visibleChildren,
                config: config,
                positions: &positions
            )
            if firstCenterY == nil { firstCenterY = cy }
            lastCenterY = cy
            cursor += h + config.siblingGap
        }
        let totalHeight = cursor - yTop - config.siblingGap
        let parentCenterY = (firstCenterY! + lastCenterY) / 2
        positions[nodeId] = MindMapNodeLayout(center: CGPoint(x: centerX, y: parentCenterY), size: size)
        return (parentCenterY, max(config.nodeHeight, totalHeight))
    }

    // MARK: - Down (org chart)

    private static func layoutDown(
        rootId: String,
        sizes: [String: CGSize],
        visibleChildren: (String) -> [String],
        config: MindMapLayoutConfig,
        positions: inout [String: MindMapNodeLayout]
    ) {
        let rootSize = sizes[rootId] ?? .zero
        let rootCenterY = rootSize.height / 2
        positions[rootId] = MindMapNodeLayout(center: CGPoint(x: 0, y: rootCenterY), size: rootSize)

        let kids = visibleChildren(rootId)
        let totalWidth = groupWidth(kids: kids, visibleChildren: visibleChildren, config: config)
        var cursor = -totalWidth / 2
        for kid in kids {
            let w = layoutDown(
                nodeId: kid,
                parentCenterY: rootCenterY,
                parentHalfHeight: rootSize.height / 2,
                xLeft: cursor,
                sizes: sizes,
                visibleChildren: visibleChildren,
                config: config,
                positions: &positions
            ).width
            cursor += w + config.siblingGap
        }
    }

    private static func layoutDown(
        nodeId: String,
        parentCenterY: CGFloat,
        parentHalfHeight: CGFloat,
        xLeft: CGFloat,
        sizes: [String: CGSize],
        visibleChildren: (String) -> [String],
        config: MindMapLayoutConfig,
        positions: inout [String: MindMapNodeLayout]
    ) -> (centerX: CGFloat, width: CGFloat) {
        let size = sizes[nodeId] ?? .zero
        let halfHeight = size.height / 2
        let centerY = parentCenterY + parentHalfHeight + config.levelGap + halfHeight
        let kids = visibleChildren(nodeId)

        if kids.isEmpty {
            let centerX = xLeft + size.width / 2
            positions[nodeId] = MindMapNodeLayout(center: CGPoint(x: centerX, y: centerY), size: size)
            return (centerX, size.width)
        }

        var cursor = xLeft
        var firstCenterX: CGFloat?
        var lastCenterX: CGFloat = 0
        for kid in kids {
            let (cx, w) = layoutDown(
                nodeId: kid,
                parentCenterY: centerY,
                parentHalfHeight: halfHeight,
                xLeft: cursor,
                sizes: sizes,
                visibleChildren: visibleChildren,
                config: config,
                positions: &positions
            )
            if firstCenterX == nil { firstCenterX = cx }
            lastCenterX = cx
            cursor += w + config.siblingGap
        }
        let totalWidth = cursor - xLeft - config.siblingGap
        let parentCenterX = (firstCenterX! + lastCenterX) / 2
        positions[nodeId] = MindMapNodeLayout(center: CGPoint(x: parentCenterX, y: centerY), size: size)
        return (parentCenterX, max(size.width, totalWidth))
    }

    // MARK: - Subtree sizing

    private static func subtreeHeight(
        nodeId: String,
        visibleChildren: (String) -> [String],
        config: MindMapLayoutConfig
    ) -> CGFloat {
        let kids = visibleChildren(nodeId)
        if kids.isEmpty { return config.nodeHeight }
        let total = kids.reduce(CGFloat(0)) { $0 + subtreeHeight(nodeId: $1, visibleChildren: visibleChildren, config: config) }
            + config.siblingGap * CGFloat(max(kids.count - 1, 0))
        return max(config.nodeHeight, total)
    }

    private static func groupHeight(
        kids: [String],
        visibleChildren: (String) -> [String],
        config: MindMapLayoutConfig
    ) -> CGFloat {
        if kids.isEmpty { return 0 }
        let total = kids.reduce(CGFloat(0)) { $0 + subtreeHeight(nodeId: $1, visibleChildren: visibleChildren, config: config) }
            + config.siblingGap * CGFloat(max(kids.count - 1, 0))
        return total
    }

    private static func subtreeWidth(
        nodeId: String,
        visibleChildren: (String) -> [String],
        config: MindMapLayoutConfig
    ) -> CGFloat {
        // down 布局暂用统一 minNodeWidth 近似宽度，避免重复测量复杂度；
        // 真实宽度由 measure 在布局时已用于 size。
        let kids = visibleChildren(nodeId)
        if kids.isEmpty { return config.minNodeWidth }
        let total = kids.reduce(CGFloat(0)) { $0 + subtreeWidth(nodeId: $1, visibleChildren: visibleChildren, config: config) }
            + config.siblingGap * CGFloat(max(kids.count - 1, 0))
        return max(config.minNodeWidth, total)
    }

    private static func groupWidth(
        kids: [String],
        visibleChildren: (String) -> [String],
        config: MindMapLayoutConfig
    ) -> CGFloat {
        if kids.isEmpty { return 0 }
        let total = kids.reduce(CGFloat(0)) { $0 + subtreeWidth(nodeId: $1, visibleChildren: visibleChildren, config: config) }
            + config.siblingGap * CGFloat(max(kids.count - 1, 0))
        return total
    }

    // MARK: - Bounds & Edges

    private static func computeBounds(positions: [String: MindMapNodeLayout]) -> CGRect {
        guard !positions.isEmpty else { return .zero }
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        for layout in positions.values {
            let origin = layout.origin
            minX = min(minX, origin.x)
            minY = min(minY, origin.y)
            maxX = max(maxX, origin.x + layout.size.width)
            maxY = max(maxY, origin.y + layout.size.height)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// 收集所有可见的父子边（跳过折叠节点隐藏的子树）。
    private static func collectEdges(rootId: String, map: MindMap, positions: [String: MindMapNodeLayout]) -> [(String, String)] {
        var edges: [(String, String)] = []
        var stack: [String] = [rootId]
        while let id = stack.popLast() {
            guard let node = map.node(id: id) else { continue }
            if !node.collapsed {
                for child in map.children(of: id) where positions[child.id] != nil {
                    edges.append((id, child.id))
                    stack.append(child.id)
                }
            }
        }
        return edges
    }
}
