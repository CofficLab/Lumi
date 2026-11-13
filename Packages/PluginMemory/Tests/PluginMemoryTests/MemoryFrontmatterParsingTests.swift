import Foundation
import Testing
import KitAgentTool

@testable import PluginMemory

/// 回归 #528：记忆 frontmatter 解析曾用 `components(separatedBy: "---")`
/// 按子串切分整份文件，description 等字段值内部合法出现的 `---`
/// （如 `alpha---beta`）被误当作结构分隔符，导致描述被截断、正文混入
/// created/updated 行而无法还原。只有整行恰为 `---` 的行才是 frontmatter
/// 的结构分隔符。
@Suite("MemoryFrontmatterParsing")
@MainActor
struct MemoryFrontmatterParsingTests {
    private func makeTempStorage() -> (MemoryFileStorage, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-frontmatter-\(UUID().uuidString)")
        return (MemoryFileStorage(rootURL: url), url)
    }

    @Test("description 含 --- 时保存读取必须完整还原（回归 #528）")
    func descriptionWithDashesRoundTrips() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try await storage.save(
            id: "demo", type: .project, name: "Demo",
            description: "alpha---beta", content: "BODY",
            scope: .global, projectPath: nil
        )
        let item = try await storage.load(id: "demo", type: .project, scope: .global, projectPath: nil)
        #expect(item?.description == "alpha---beta")
        #expect(item?.content == "BODY")
    }

    @Test("正文包含整行 --- 时保存读取保持一致")
    func contentWithHorizontalRuleRoundTrips() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let body = "before\n---\nafter"
        _ = try await storage.save(
            id: "rule", type: .project, name: "Rule",
            description: "d", content: body,
            scope: .global, projectPath: nil
        )
        let item = try await storage.load(id: "rule", type: .project, scope: .global, projectPath: nil)
        #expect(item?.content == body)
        #expect(item?.description == "d")
    }

    @Test("save_memory→recall_memory 往返不得截断含 --- 的描述（回归 #528）")
    func recallToolRestoresDescriptionWithDashes() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let capability = MemoryProjectCapabilityAdapter(project: nil)
        let saveTool = SaveMemoryTool(storage: storage, projectCapability: capability)
        let recallTool = RecallMemoryTool(storage: storage, projectCapability: capability)

        _ = try await saveTool.execute(arguments: [
            "id": ToolArgument("demo"),
            "name": ToolArgument("Demo"),
            "description": ToolArgument("alpha---beta"),
            "content": ToolArgument("BODY"),
        ])
        let output = try await recallTool.execute(arguments: ["id": ToolArgument("demo")])
        #expect(output.contains("alpha---beta"))
        #expect(output.contains("BODY"))
        #expect(output.contains("created:") == false)
        #expect(output.contains("updated:") == false)
    }
}