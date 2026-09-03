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