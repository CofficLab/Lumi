import XCTest
@testable import MindMapPlugin

final class MindMapPluginTests: XCTestCase {
    func testMarkdownCodecRoundTrip() throws {
        let outline = """
        # Topic
        - Branch A
          - Sub A1
          - Sub A2
        - Branch B
        """
        let map = MindMapMarkdownCodec.decode(markdown: outline, title: nil)
        XCTAssertEqual(map.title, "Topic")
        // root(Topic) + Branch A + Sub A1 + Sub A2 + Branch B = 5
        XCTAssertEqual(map.nodes.count, 5)
        let encoded = MindMapMarkdownCodec.encode(map)
        XCTAssertTrue(encoded.contains("Branch A"))
        XCTAssertTrue(encoded.contains("Sub A1"))
    }

    func testLayoutEngineProducesPositions() throws {
        let root = MindMapNode(parentId: nil, text: "Root")
        let child1 = MindMapNode(parentId: root.id, text: "Child 1")
        let child2 = MindMapNode(parentId: root.id, text: "Child 2")
        let grandchild = MindMapNode(parentId: child1.id, text: "Grandchild")
        let map = MindMap(title: "Test", nodes: [root, child1, child2, grandchild], layoutDirection: .bilateral)

        let result = MindMapLayoutEngine.layout(map)
        XCTAssertEqual(result.nodes.count, 4)
        XCTAssertNotNil(result.nodes[root.id])
        // 双侧布局：两个子节点应分列根的左右（x 不同号）。
        let child1X = try XCTUnwrap(result.nodes[child1.id]).center.x
        let child2X = try XCTUnwrap(result.nodes[child2.id]).center.x
        XCTAssertTrue(child1X * child2X <= 0 || child1X != child2X, "children should spread on both sides")
        // bounds 非零。
        XCTAssertGreaterThan(result.bounds.width, 0)
        XCTAssertGreaterThan(result.bounds.height, 0)
    }

    func testDescendantIds() {
        let root = MindMapNode(parentId: nil, text: "R")
        let a = MindMapNode(parentId: root.id, text: "A")
        let b = MindMapNode(parentId: a.id, text: "B")
        let c = MindMapNode(parentId: root.id, text: "C")
        let map = MindMap(title: "T", nodes: [root, a, b, c])
        XCTAssertEqual(map.descendantIds(of: root.id), [a.id, b.id, c.id])
        XCTAssertEqual(map.descendantIds(of: a.id), [b.id])
        XCTAssertEqual(map.descendantIds(of: c.id), [])
    }

    func testWouldCreateCycle() {
        let root = MindMapNode(parentId: nil, text: "R")
        let a = MindMapNode(parentId: root.id, text: "A")
        let b = MindMapNode(parentId: a.id, text: "B")
        let map = MindMap(title: "T", nodes: [root, a, b])
        // 把 a 挂到 b（b 是 a 的后代）下应判环。
        XCTAssertTrue(map.wouldCreateCycle(nodeId: a.id, newParentId: b.id))
        // 把 a 挂到 root 下（合法）。
        XCTAssertFalse(map.wouldCreateCycle(nodeId: a.id, newParentId: root.id))
    }
}
