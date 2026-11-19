import Foundation
import KitAgentTool
import ProviderSkill
import Testing
@testable import PluginSkill

/// 覆盖 list / read 工具对「插件贡献 + 内置」底座技能的可见性。
///
/// ## 为什么要有这组用例
///
/// 插件贡献的技能（如 xcode-build）正文不在项目 `.lumi/skills` 目录里。
/// 如果 list_skills 只扫内置目录、read_skill 只读项目目录，模型就只能
/// 从 system prompt 看到元数据，永远拿不到正文——工具契约承诺了
/// 「built-in and plugin-contributed」，实现必须兑现。
@MainActor
@Suite("Skill Base Skill Tools")
struct BaseSkillToolFallbackTests {

    // MARK: - Stub

    private struct StubContributor: SkillContributing {
        let providerID: String
        let skills: [SkillMetadata]
        var allSkills: [SkillMetadata] { skills }
    }

    private final class StubObserverHandle: SkillProvidingObserverHandle {
        func cancel() {}
    }

    private final class StubSkillProviding: SkillProviding {
        private(set) var contributors: [any SkillContributing] = []

        func addProvider(_ provider: any SkillContributing) {
            contributors.append(provider)
        }

        func removeProvider(providerID: String) {
            contributors.removeAll { $0.providerID == providerID }
        }

        func isProviderRegistered(providerID: String) -> Bool {
            contributors.contains { $0.providerID == providerID }
        }

        func allSkills() -> [SkillMetadata] {
            contributors.flatMap(\.allSkills)
        }

        func skillsGroupedByContributor() -> [(providerID: String, skills: [SkillMetadata])] {
            contributors.map { ($0.providerID, $0.allSkills) }
        }

        func addObserver(_ callback: @escaping (SkillProvidingEvent) -> Void) -> any SkillProvidingObserverHandle {
            StubObserverHandle()
        }
    }

    // MARK: - Helpers

    private let baseSkill = SkillMetadata(
        name: "xcode-build",
        title: "Xcode Build",
        description: "Build guidance for Xcode projects",
        triggers: ["build"],
        content: "# Xcode Build\nUse -project/-scheme/-configuration and a concrete destination."
    )

    private func arguments(_ pairs: [String: Any]) -> [String: ToolArgument] {
        pairs.mapValues { ToolArgument($0) }
    }

    private func decodeSkills(_ output: String) -> [[String: Any]]? {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["skills"] as? [[String: Any]] else {
            return nil
        }
        return items
    }

    private func decodeReadSkill(_ output: String) -> [String: Any]? {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["skill"] as? [String: Any]
    }

    // MARK: - list_skills

    @Test("list_skills 底座包含插件贡献技能及其正文")
    func listIncludesContributedBaseSkillWithContent() async throws {
        let provider = StubSkillProviding()
        provider.addProvider(StubContributor(providerID: "plugin.xcode-build", skills: [baseSkill]))

        let output = try await ListSkillsTool(skillProvider: provider).execute(arguments: arguments([
            "include_content": true,
        ]))

        let items = try #require(decodeSkills(output))
        let matched = try #require(items.first { ($0["name"] as? String) == baseSkill.name })
        #expect(matched["content"] as? String == baseSkill.content)
        #expect(matched["is_project_skill"] as? Bool == false)
    }

    @Test("list_skills 项目层同名技能覆盖底座")
    func listPrefersProjectSkillOverBase() async throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-base-list-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: project) }
        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: baseSkill.name,
            title: "项目覆盖版",
            description: "项目层描述",
            content: "项目层正文"
        )

        let provider = StubSkillProviding()
        provider.addProvider(StubContributor(providerID: "plugin.xcode-build", skills: [baseSkill]))

        let output = try await ListSkillsTool(skillProvider: provider).execute(arguments: arguments([
            "project_path": project.path,
            "include_content": true,
        ]))

        let items = try #require(decodeSkills(output))
        let names = items.compactMap { $0["name"] as? String }
        #expect(names.filter { $0 == baseSkill.name }.count == 1)
        let matched = try #require(items.first { ($0["name"] as? String) == baseSkill.name })
        #expect((matched["content"] as? String)?.contains("项目层正文") == true)
        #expect(matched["is_project_skill"] as? Bool == true)
    }

    @Test("list_skills 未注入 SkillProviding 时回退内置目录")
    func listFallsBackToBuiltinCatalogWithoutProvider() async throws {
        let output = try await ListSkillsTool().execute(arguments: [:])
        // 不校验具体技能集合（随包内置目录会演进），只要求正常返回 JSON 或提示文案。
        #expect(decodeSkills(output) != nil || !output.isEmpty)
    }

    // MARK: - read_skill

    @Test("read_skill 项目层未命中时回退底座技能正文")
    func readFallsBackToBaseSkillBody() async throws {
        let provider = StubSkillProviding()
        provider.addProvider(StubContributor(providerID: "plugin.xcode-build", skills: [baseSkill]))

        let output = try await ReadSkillTool(skillProvider: provider).execute(arguments: arguments([
            "name": baseSkill.name,
        ]))

        let skill = try #require(decodeReadSkill(output))
        #expect(skill["name"] as? String == baseSkill.name)
        #expect(skill["content"] as? String == baseSkill.content)
        #expect(skill["source"] as? String == "base")
    }

    @Test("read_skill 项目层命中时优先项目技能")
    func readPrefersProjectSkillOverBase() async throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-base-read-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: project) }
        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: baseSkill.name,
            title: "项目覆盖版",
            description: "项目层描述",
            content: "项目层正文"
        )

        let provider = StubSkillProviding()
        provider.addProvider(StubContributor(providerID: "plugin.xcode-build", skills: [baseSkill]))

        let output = try await ReadSkillTool(skillProvider: provider).execute(arguments: arguments([
            "project_path": project.path,
            "name": baseSkill.name,
        ]))

        let skill = try #require(decodeReadSkill(output))
        #expect((skill["content"] as? String)?.contains("项目层正文") == true)
        #expect(skill["source"] as? String == "project")
    }

    @Test("read_skill 底座也没有该技能时仍抛 notFound")
    func readThrowsWhenMissingEverywhere() async throws {
        let provider = StubSkillProviding()
        provider.addProvider(StubContributor(providerID: "plugin.xcode-build", skills: [baseSkill]))

        await #expect(throws: SkillCreationError.self) { () -> Void in
            _ = try await ReadSkillTool(skillProvider: provider).execute(arguments: arguments([
                "name": "ghost",
            ]))
        }
    }
}
