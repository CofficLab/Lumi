import XCTest
import ProviderSkill
import Foundation

/// 测试用 Skill 贡献者。
private struct TestContributor: SkillContributing {
    let providerID: String
    let skills: [SkillMetadata]

    var allSkills: [SkillMetadata] { skills }
}

@MainActor
final class ProviderSkillTests: XCTestCase {

    private func makeSkill(name: String, title: String? = nil) -> SkillMetadata {
        SkillMetadata(
            name: name,
            title: title ?? name,
            description: "desc-\(name)",
            triggers: ["trigger-\(name)"]
        )
    }

    // MARK: - 注册 / 撤销

    func testAddProviderRegistersContributor() {
        let provider = DefaultSkillProvider()
        let contributor = TestContributor(providerID: "plugin.a", skills: [makeSkill(name: "alpha")])

        XCTAssertFalse(provider.isProviderRegistered(providerID: "plugin.a"))
        provider.addProvider(contributor)

        XCTAssertTrue(provider.isProviderRegistered(providerID: "plugin.a"))
        XCTAssertEqual(provider.contributors.count, 1)
        XCTAssertEqual(provider.allSkills().map(\.name), ["alpha"])
    }

    func testDuplicateProviderIDKeepsFirst() {
        let provider = DefaultSkillProvider()
        let first = TestContributor(providerID: "plugin.a", skills: [makeSkill(name: "alpha")])
        let second = TestContributor(providerID: "plugin.a", skills: [makeSkill(name: "beta")])

        provider.addProvider(first)
        provider.addProvider(second)

        XCTAssertEqual(provider.contributors.count, 1)
        XCTAssertEqual(provider.allSkills().map(\.name), ["alpha"])
    }

    func testRemoveProviderIsIdempotent() {
        let provider = DefaultSkillProvider()
        provider.addProvider(TestContributor(providerID: "plugin.a", skills: [makeSkill(name: "alpha")]))

        provider.removeProvider(providerID: "plugin.a")
        XCTAssertFalse(provider.isProviderRegistered(providerID: "plugin.a"))
        XCTAssertTrue(provider.allSkills().isEmpty)

        // 重复撤销无副作用。
        provider.removeProvider(providerID: "plugin.a")
        XCTAssertEqual(provider.contributors.count, 0)
    }

    // MARK: - 聚合 / 去重

    func testAllSkillsMergesInRegistrationOrder() {
        let provider = DefaultSkillProvider()
        provider.addProvider(TestContributor(providerID: "plugin.a", skills: [makeSkill(name: "alpha"), makeSkill(name: "beta")]))
        provider.addProvider(TestContributor(providerID: "plugin.b", skills: [makeSkill(name: "gamma")]))

        XCTAssertEqual(provider.allSkills().map(\.name), ["alpha", "beta", "gamma"])
    }

    func testDuplicateSkillNameFirstWins() {
        let provider = DefaultSkillProvider()
        provider.addProvider(TestContributor(providerID: "plugin.a", skills: [makeSkill(name: "shared")]))
        provider.addProvider(TestContributor(providerID: "plugin.b", skills: [makeSkill(name: "shared")]))

        XCTAssertEqual(provider.allSkills().count, 1)
        XCTAssertEqual(provider.allSkills().first?.name, "shared")
    }

    func testEmptyOrWhitespaceSkillNameIsSkipped() {
        let provider = DefaultSkillProvider()
        provider.addProvider(TestContributor(providerID: "plugin.a", skills: [
            makeSkill(name: "valid"),
            makeSkill(name: "   "),
        ]))

        XCTAssertEqual(provider.allSkills().map(\.name), ["valid"])
    }

    // MARK: - 分组

    func testSkillsGroupedByContributor() {
        let provider = DefaultSkillProvider()
        provider.addProvider(TestContributor(providerID: "plugin.a", skills: [makeSkill(name: "alpha")]))
        provider.addProvider(TestContributor(providerID: "plugin.b", skills: [makeSkill(name: "beta"), makeSkill(name: "gamma")]))

        let groups = provider.skillsGroupedByContributor()
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].providerID, "plugin.a")
        XCTAssertEqual(groups[0].skills.map(\.name), ["alpha"])
        XCTAssertEqual(groups[1].providerID, "plugin.b")
        XCTAssertEqual(groups[1].skills.map(\.name), ["beta", "gamma"])
    }

    func testEmptyContributorIsOmittedFromGrouping() {
        let provider = DefaultSkillProvider()
        provider.addProvider(TestContributor(providerID: "plugin.empty", skills: []))

        XCTAssertEqual(provider.skillsGroupedByContributor().count, 0)
    }

    // MARK: - 观察者

    func testObserverFiresOnAddAndRemove() {
        let provider = DefaultSkillProvider()
        var events: [SkillProvidingEvent] = []
        let handle = provider.addObserver { events.append($0) }

        provider.addProvider(TestContributor(providerID: "plugin.a", skills: [makeSkill(name: "alpha")]))
        provider.removeProvider(providerID: "plugin.a")

        XCTAssertEqual(events.count, 2)
        handle.cancel()
    }

    func testObserverStopsAfterCancel() {
        let provider = DefaultSkillProvider()
        var count = 0
        let handle = provider.addObserver { _ in count += 1 }

        handle.cancel()
        provider.addProvider(TestContributor(providerID: "plugin.a", skills: [makeSkill(name: "alpha")]))

        XCTAssertEqual(count, 0)
    }
}

// MARK: - SkillDirectoryLoader

@MainActor
final class SkillDirectoryLoaderTests: XCTestCase {
    /// 在临时目录构造一个含标准结构的技能目录树。
    private func makeSkillDirectory(
        skills: [(name: String, title: String)],
        missingSKILLMD: Set<String> = [],
        emptyNameSkills: Set<String> = []
    ) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillLoaderTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        for skill in skills {
            let dir = root.appendingPathComponent(skill.name, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let meta: [String: Any] = [
                "name": emptyNameSkills.contains(skill.name) ? "   " : skill.name,
                "title": skill.title,
                "description": "desc-\(skill.name)",
                "triggers": ["trigger-\(skill.name)"],
                "version": "1.0.0",
            ]
            let data = try! JSONSerialization.data(withJSONObject: meta)
            try! data.write(to: dir.appendingPathComponent("metadata.json"))
            if !missingSKILLMD.contains(skill.name) {
                try? "content of \(skill.name)".write(to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
            }
        }
        return root
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func testLoadsAndSortsSkills() {
        let root = makeSkillDirectory(skills: [
            (name: "beta", title: "Beta"),
            (name: "alpha", title: "Alpha"),
        ])
        defer { cleanup(root) }

        let loader = SkillDirectoryLoader()
        let skills = loader.loadSkills(from: root)

        XCTAssertEqual(skills.map(\.name), ["alpha", "beta"])
        XCTAssertEqual(skills.first?.title, "Alpha")
        XCTAssertEqual(skills.first?.triggers, ["trigger-alpha"])
        XCTAssertTrue(skills.allSatisfy { $0.contentPath.hasSuffix("SKILL.md") })
    }

    func testSkipsDirectoriesWithoutSKILLMD() {
        let root = makeSkillDirectory(
            skills: [(name: "good", title: "Good"), (name: "bad", title: "Bad")],
            missingSKILLMD: ["bad"]
        )
        defer { cleanup(root) }

        let loader = SkillDirectoryLoader()
        let skills = loader.loadSkills(from: root)
        XCTAssertEqual(skills.map(\.name), ["good"])
    }

    func testSkipsWhitespaceName() {
        let root = makeSkillDirectory(
            skills: [(name: "good", title: "Good"), (name: " ", title: "Empty")],
            emptyNameSkills: [" "]
        )
        defer { cleanup(root) }

        let loader = SkillDirectoryLoader()
        let skills = loader.loadSkills(from: root)
        XCTAssertEqual(skills.map(\.name), ["good"])
    }

    func testRespectsMaxSkillCount() {
        let root = makeSkillDirectory(skills: [
            (name: "a", title: "A"),
            (name: "b", title: "B"),
            (name: "c", title: "C"),
        ])
        defer { cleanup(root) }

        let loader = SkillDirectoryLoader(maxSkillCount: 2)
        let skills = loader.loadSkills(from: root)
        XCTAssertEqual(skills.count, 2)
    }

    func testMissingDirectoryReturnsEmpty() {
        let loader = SkillDirectoryLoader()
        let skills = loader.loadSkills(from: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)"))
        XCTAssertTrue(skills.isEmpty)
    }

    func testLoadContentFallsBackToContentPath() {
        let root = makeSkillDirectory(skills: [(name: "alpha", title: "Alpha")])
        defer { cleanup(root) }

        let loader = SkillDirectoryLoader()
        let skills = loader.loadSkills(from: root)
        XCTAssertEqual(skills.count, 1)

        let content = skills[0].loadContent()
        XCTAssertEqual(content, "content of alpha")
    }

    func testLoadContentPrefersInlineContent() {
        let skill = SkillMetadata(
            name: "inline",
            title: "Inline",
            description: "desc",
            contentPath: "/nonexistent/SKILL.md",
            content: "inline body"
        )
        XCTAssertEqual(skill.loadContent(), "inline body")
    }
}