import Testing
import Foundation
@testable import PluginMindMapDesigner

// MARK: - Layout cache (#1191)

/// 回归 #1191：地图不变时（仅视口 scale/offset 变化）必须复用缓存布局，不重算。
@Test @MainActor func layoutCacheReusesResultForUnchangedMap() {
    final class Counter { var value = 0 }
    let counter = Counter()
    let cache = MindMapLayoutCache { map in
        counter.value += 1
        return MindMapLayoutEngine.layout(map)
    }
    let map = MindMap(title: "T", nodes: [MindMapNode(id: "r", parentId: nil, text: "R")])

    let first = cache.layout(for: map)
    let second = cache.layout(for: map)

    #expect(counter.value == 1)
    #expect(first.nodes == second.nodes)
}

/// 回归 #1191：节点文本变化（影响尺寸）必须触发重算。
@Test @MainActor func layoutCacheRecomputesWhenNodeTextChanges() {
    final class Counter { var value = 0 }
    let counter = Counter()
    let cache = MindMapLayoutCache { map in
        counter.value += 1
        return MindMapLayoutEngine.layout(map)
    }
    let root = MindMapNode(id: "r", parentId: nil, text: "R")
    _ = cache.layout(for: MindMap(title: "T", nodes: [root]))

    var changed = root
    changed.text = "A much longer root text"
    _ = cache.layout(for: MindMap(title: "T", nodes: [changed]))

    #expect(counter.value == 2)
}

/// 回归 #1191：结构变化（新增节点）必须触发重算。
@Test @MainActor func layoutCacheRecomputesWhenStructureChanges() {
    final class Counter { var value = 0 }
    let counter = Counter()
    let cache = MindMapLayoutCache { map in
        counter.value += 1
        return MindMapLayoutEngine.layout(map)
    }
    let root = MindMapNode(id: "r", parentId: nil, text: "R")
    _ = cache.layout(for: MindMap(title: "T", nodes: [root]))
    _ = cache.layout(for: MindMap(title: "T", nodes: [root, MindMapNode(id: "c", parentId: "r", text: "C")]))

    #expect(counter.value == 2)
}

/// 回归 #1191：折叠状态变化（影响可见子树）必须触发重算。
@Test @MainActor func layoutCacheRecomputesWhenCollapsedChanges() {
    final class Counter { var value = 0 }
    let counter = Counter()
    let cache = MindMapLayoutCache { map in
        counter.value += 1
        return MindMapLayoutEngine.layout(map)
    }
    let root = MindMapNode(id: "r", parentId: nil, text: "R")
    let child = MindMapNode(id: "c", parentId: "r", text: "C")
    _ = cache.layout(for: MindMap(title: "T", nodes: [root, child]))

    var collapsedRoot = root
    collapsedRoot.collapsed = true
    _ = cache.layout(for: MindMap(title: "T", nodes: [collapsedRoot, child]))

    #expect(counter.value == 2)
}

/// 回归 #1191：布局方向变化必须触发重算。
@Test @MainActor func layoutCacheRecomputesWhenLayoutDirectionChanges() {
    final class Counter { var value = 0 }
    let counter = Counter()
    let cache = MindMapLayoutCache { map in
        counter.value += 1
        return MindMapLayoutEngine.layout(map)
    }
    let nodes = [MindMapNode(id: "r", parentId: nil, text: "R")]
    _ = cache.layout(for: MindMap(title: "T", nodes: nodes, layoutDirection: .right))
    _ = cache.layout(for: MindMap(title: "T", nodes: nodes, layoutDirection: .down))

    #expect(counter.value == 2)
}

// MARK: - Layout engine O(N) lookups (#1191)

/// 回归 #1191：字典化查找后，边收集仍须完整且正确（父→子）。
@Test func layoutCollectsAllVisibleEdges() {
    let nodes = [
        MindMapNode(id: "r", parentId: nil, text: "R"),
        MindMapNode(id: "a", parentId: "r", text: "A"),
        MindMapNode(id: "b", parentId: "r", text: "B"),
        MindMapNode(id: "a1", parentId: "a", text: "A1"),
    ]
    let result = MindMapLayoutEngine.layout(MindMap(title: "T", nodes: nodes, layoutDirection: .right))
    let edges = Set(result.edges.map { "\($0.0)->\($0.1)" })
    #expect(edges == ["r->a", "r->b", "a->a1"])
}

/// 回归 #1191：折叠节点隐藏的子树不得产生边，也不得布局其子节点。
@Test func layoutSkipsCollapsedSubtreeEdges() {
    let nodes = [
        MindMapNode(id: "r", parentId: nil, text: "R"),
        MindMapNode(id: "a", parentId: "r", text: "A", collapsed: true),
        MindMapNode(id: "a1", parentId: "a", text: "A1"),
    ]
    let result = MindMapLayoutEngine.layout(MindMap(title: "T", nodes: nodes, layoutDirection: .right))
    let edges = Set(result.edges.map { "\($0.0)->\($0.1)" })
    #expect(edges == ["r->a"])
    #expect(result.nodes["a1"] == nil)
}

/// 回归 #1191：布局查找必须 O(N)。原先 visibleChildren/collectEdges 对每个节点
/// 全量扫描 nodes（O(N²)），大图手势会卡顿。用 1 万节点宽树断言布局在宽裕时限内
/// 完成且节点/边数正确；退回线性查找会远超时限。
@Test func layoutHandlesLargeMapLinearly() {
    let count = 10_000
    var nodes: [MindMapNode] = [MindMapNode(id: "root", parentId: nil, text: "root")]
    for i in 1..<count {
        nodes.append(MindMapNode(id: "n\(i)", parentId: "root", text: "n\(i)"))
    }
    let map = MindMap(title: "Wide", nodes: nodes, layoutDirection: .right)

    let start = Date()
    let result = MindMapLayoutEngine.layout(map)
    let duration = Date().timeIntervalSince(start)

    #expect(result.nodes.count == count)
    #expect(result.edges.count == count - 1)
    #expect(duration < 3.0, "布局耗时 \(duration)s，疑似退回 O(N²) 查找")
}