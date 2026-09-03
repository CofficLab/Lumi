import Foundation
import KitSuperLog
import os

/// `SkillProviding` 的默认实现：线程安全的插件贡献注册表。
///
/// 只维护「插件贡献」这一层来源。内置技能与项目 `.agent/skills/` 扫描
/// 由 `PluginSkill` 作为 `SkillContributing` 提供者接入，因此聚合时自然形成
/// 三层来源（插件贡献 → 项目 → 内置），且优先级由 Provider 注册顺序决定。
@MainActor
public final class DefaultSkillProvider: SkillProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-skill", category: "Skill")
    public nonisolated static let emoji = "✨"

    /// 已注册的贡献者，按注册顺序。
    private var registeredContributors: [any SkillContributing] = []

    /// 观察者集合（弱引用令牌）。
    private var observers: [WeakObserver] = []

    public init() {
        Self.logger.info("\(Self.t)DefaultSkillProvider ready")
    }

    // MARK: - SkillProviding

    public var contributors: [any SkillContributing] {
        registeredContributors
    }

    public func addProvider(_ provider: any SkillContributing) {
        guard !isProviderRegistered(providerID: provider.providerID) else {
            Self.logger.warning("\(Self.t)Skip duplicate Skill contributor '\(provider.providerID)'")
            return
        }
        registeredContributors.append(provider)
        Self.logger.info("\(Self.t)Registered Skill contributor '\(provider.providerID)' (\(provider.allSkills.count) skills)")
        notify(.contributorsChanged)
    }

    public func removeProvider(providerID: String) {
        let before = registeredContributors.count
        registeredContributors.removeAll { $0.providerID == providerID }
        guard registeredContributors.count != before else { return }
        Self.logger.info("\(Self.t)Removed Skill contributor '\(providerID)'")
        notify(.contributorsChanged)
    }

    public func isProviderRegistered(providerID: String) -> Bool {
        registeredContributors.contains { $0.providerID == providerID }
    }

    public func allSkills() -> [SkillMetadata] {
        var skills: [SkillMetadata] = []
        var seenNames: Set<String> = []
        for contributor in registeredContributors {
            for skill in contributor.allSkills {
                guard !seenNames.contains(skill.name),
                      !skill.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                seenNames.insert(skill.name)
                skills.append(skill)
            }
        }
        return skills
    }

    public func skillsGroupedByContributor() -> [(providerID: String, skills: [SkillMetadata])] {
        var result: [(providerID: String, skills: [SkillMetadata])] = []
        for contributor in registeredContributors {
            let skills = contributor.allSkills.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard !skills.isEmpty else { continue }
            result.append((providerID: contributor.providerID, skills: skills))
        }
        return result
    }

    // MARK: - Observation

    @discardableResult
    public func addObserver(
        _ callback: @escaping (SkillProvidingEvent) -> Void
    ) -> any SkillProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: SkillProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        let activeObservers = observers
        for observer in activeObservers {
            observer.observer?.invoke(event)
        }
    }

    // MARK: - Observer Token

    private final class Observer: SkillProvidingObserverHandle {
        private weak var owner: DefaultSkillProvider?
        private let callback: (SkillProvidingEvent) -> Void
        private var cancelled = false

        init(owner: DefaultSkillProvider, callback: @escaping (SkillProvidingEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            owner?.remove(self)
        }

        func invoke(_ event: SkillProvidingEvent) {
            guard !cancelled else { return }
            callback(event)
        }
    }

    private final class WeakObserver {
        weak var observer: Observer?

        init(_ observer: Observer) {
            self.observer = observer
        }
    }
}