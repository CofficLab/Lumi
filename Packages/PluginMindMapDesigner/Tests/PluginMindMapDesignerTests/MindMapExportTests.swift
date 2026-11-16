import Testing
import Foundation
@testable import PluginMindMapDesigner

// MARK: - Markdown traversal (#1202)

/// 回归 #1202：建立 parent→children 索引后，编码必须保持子节点原序与层级缩进。
@Test func markdownEncodePreservesChildOrderAndDepth() {
    let root = MindMapNode(id: "r", parentId: nil, text: "Root")
    let a = MindMapNode(id: "a", parentId: "r", text: "A")
    let b = MindMapNode(id: "b", parentId: "r", text: "B")
    let a1 = MindMapNode(id: "a1", parentId: "a", text: "A1")
    let map = MindMap(title: "Root", nodes: [root, a, b, a1])

    let markdown = MindMapMarkdownCodec.encode(map)
    #expect(markdown == "# Root\n- A\n  - A1\n- B")
}

/// 回归 #1202：Markdown 遍历必须是 O(N)。原先每个节点都全量扫描 nodes（O(N²)），
/// 大图会冻结 UI。这里用 5 万节点的宽树（根 + 大量叶子，输出本身 O(N)）断言编码
/// 在宽裕时限内完成且行数正确；退回 children(of:) 的二次扫描会远超时限。
@Test func markdownEncodeHandlesLargeMapLinearly() {
    let count = 50_000
    var nodes: [MindMapNode] = [MindMapNode(id: "root", parentId: nil, text: "root")]
    for i in 1..<count {
        nodes.append(MindMapNode(id: "n\(i)", parentId: "root", text: "n\(i)"))
    }
    let map = MindMap(title: "Wide", nodes: nodes)

    let start = Date()
    let markdown = MindMapMarkdownCodec.encode(map)
    let duration = Date().timeIntervalSince(start)

    // "# Wide" + 根文本行 + (count-1) 个叶子列表项。
    let lines = markdown.split(separator: "\n", omittingEmptySubsequences: true)
    #expect(lines.count == count + 1)
    #expect(duration < 2.0, "Markdown 编码耗时 \(duration)s，疑似退回 O(N²) 遍历")
}

// MARK: - Exporter encoding (#1202)

@Test func exporterMarkdownEncodeMatchesCodec() throws {
    let map = MindMap(title: "T", nodes: [
        MindMapNode(id: "r", parentId: nil, text: "T"),
        MindMapNode(id: "c", parentId: "r", text: "Child"),
    ])
    let data = try MindMapFileExporter.encode(map, format: .markdown)
    #expect(String(data: data, encoding: .utf8) == MindMapMarkdownCodec.encode(map))
}

@Test func exporterJSONEncodeRoundTripsNodes() throws {
    let map = MindMap(title: "T", nodes: [
        MindMapNode(id: "r", parentId: nil, text: "T"),
        MindMapNode(id: "c", parentId: "r", text: "Child", note: "n"),
    ])
    let data = try MindMapFileExporter.encode(map, format: .json)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(MindMap.self, from: data)
    #expect(decoded.id == map.id)
    #expect(decoded.title == map.title)
    #expect(decoded.nodes == map.nodes)
}

@Test func exporterFormatFileExtensions() {
    #expect(MindMapFileExporter.Format.markdown.fileExtension == "md")
    #expect(MindMapFileExporter.Format.json.fileExtension == "json")
}

// MARK: - Exporter off-main write (#1202)

/// 回归 #1202：编码 + 原子写入必须能在后台 detached 任务中完成（nonisolated），
/// 不依赖主线程。写回文件后校验 Markdown 字节与 codec 一致。
@Test func exporterWriteRunsOffMainAndWritesMarkdown() async throws {
    let map = MindMap(title: "T", nodes: [
        MindMapNode(id: "r", parentId: nil, text: "T"),
        MindMapNode(id: "c", parentId: "r", text: "Child"),
    ])
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("MindMapExport-\(UUID().uuidString).md")
    defer { try? FileManager.default.removeItem(at: url) }

    try await Task.detached(priority: .userInitiated) {
        try MindMapFileExporter.write(map, format: .markdown, to: url)
    }.value

    let written = try Data(contentsOf: url)
    #expect(String(data: written, encoding: .utf8) == MindMapMarkdownCodec.encode(map))
}

/// 回归 #1202：JSON 导出同样在后台任务中编码并原子写入，读回后节点一致。
@Test func exporterWriteRunsOffMainAndWritesJSON() async throws {
    let map = MindMap(title: "T", nodes: [
        MindMapNode(id: "r", parentId: nil, text: "T"),
        MindMapNode(id: "c", parentId: "r", text: "Child"),
    ])
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("MindMapExport-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }

    try await Task.detached(priority: .userInitiated) {
        try MindMapFileExporter.write(map, format: .json, to: url)
    }.value

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(MindMap.self, from: Data(contentsOf: url))
    #expect(decoded.nodes == map.nodes)
    #expect(decoded.title == map.title)
}