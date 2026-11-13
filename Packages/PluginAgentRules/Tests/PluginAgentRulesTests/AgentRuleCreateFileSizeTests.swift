import Foundation
import Testing

@testable import PluginAgentRules

/// 回归 #779：`createRule` 用 `Int64(finalContent.count)` 构造 `fileSize`，
/// 返回的是 Swift 字符数而非 UTF-8 字节数；`AgentRule.fileSize` 定义为字节，
/// 列表路径读的是真实文件大小，导致同一文件两个工具给出不一致的元数据。
@Suite("createRule 文件大小口径")
struct AgentRuleCreateFileSizeTests {
    private func makeProjectURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentRulesFileSize-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("非 ASCII 规则的 fileSize 必须是 UTF-8 字节数且与列表一致")
    func createRuleFileSizeIsUTF8ByteCount() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        let rule = try await service.createRule(
            projectPath: projectURL.path,
            filename: "unicode",
            title: "规则",
            content: "内容"
        )

        // "# 规则\n\n内容"：8 个字符、16 个 UTF-8 字节，二者必须可区分。
        #expect(rule.content.count == 8)
        let diskBytes = try Data(contentsOf: URL(fileURLWithPath: rule.filePath)).count
        #expect(diskBytes == 16)
        #expect(rule.fileSize == Int64(diskBytes), "创建结果必须返回落盘字节数")

        let listed = try await service.listRules(projectPath: projectURL.path)
        let listedRule = try #require(listed.first(where: { $0.filename == "unicode.md" }))
        #expect(listedRule.fileSize == rule.fileSize, "创建与列表对同一文件必须给出相同字节数")
    }

    @Test("emoji 等多字节字符同样按字节计量")
    func createRuleFileSizeCountsEmojiBytes() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        let rule = try await service.createRule(
            projectPath: projectURL.path,
            filename: "emoji",
            title: "T",
            content: "🎉"
        )

        let diskBytes = try Data(contentsOf: URL(fileURLWithPath: rule.filePath)).count
        #expect(rule.fileSize == Int64(diskBytes))
        #expect(rule.fileSize > Int64(rule.content.count), "🎉 占 4 字节但只算 1 个字符")
    }

    @Test("纯 ASCII 规则的 fileSize 与落盘字节数一致")
    func createRuleFileSizeMatchesDiskForASCII() async throws {
        let projectURL = makeProjectURL()
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        let rule = try await service.createRule(
            projectPath: projectURL.path,
            filename: "ascii",
            title: "Style",
            content: "Keep rules readable."
        )

        let diskBytes = try Data(contentsOf: URL(fileURLWithPath: rule.filePath)).count
        #expect(rule.fileSize == Int64(diskBytes))
    }
}