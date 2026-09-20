import Foundation

/// 一条可由项目或插件贡献的 Agent 规则。
public struct AgentRuleDefinition: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let content: String
    public let version: String

    public init(
        id: String,
        title: String,
        description: String,
        content: String,
        version: String = "1.0.0"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.content = content
        self.version = version
    }
}

/// 插件贡献 Agent 规则的数据源契约。
public protocol AgentRuleContributing: Sendable {
    /// 通常使用插件 ID，作为撤回和诊断的唯一标识。
    var providerID: String { get }

    /// 贡献方提供的全部规则。
    var allRules: [AgentRuleDefinition] { get }
}

/// Agent 规则贡献注册表。
@MainActor
public protocol AgentRuleProviding: AnyObject {
    var contributors: [any AgentRuleContributing] { get }

    func addProvider(_ provider: any AgentRuleContributing)
    func removeProvider(providerID: String)
    func isProviderRegistered(providerID: String) -> Bool

    /// 按注册顺序聚合规则；重复 ID 保留先注册者。
    func allRules() -> [AgentRuleDefinition]

    /// 按贡献者分组返回规则，供 UI 和诊断使用。
    func rulesGroupedByContributor() -> [(providerID: String, rules: [AgentRuleDefinition])]

    @discardableResult
    func addObserver(_ callback: @escaping (AgentRuleProvidingEvent) -> Void) -> any AgentRuleProvidingObserverHandle
}

@MainActor
public enum AgentRuleProvidingEvent {
    case contributorsChanged
}

@MainActor
public protocol AgentRuleProvidingObserverHandle: AnyObject {
    func cancel()
}

/// `AgentRuleProviding` 的默认内存实现。
@MainActor
public final class DefaultAgentRuleProvider: AgentRuleProviding {
    private var registeredContributors: [any AgentRuleContributing] = []
    private var observers: [WeakObserver] = []

    public init() {}

    public var contributors: [any AgentRuleContributing] {
        registeredContributors
    }

    public func addProvider(_ provider: any AgentRuleContributing) {
        guard !isProviderRegistered(providerID: provider.providerID) else { return }
        registeredContributors.append(provider)
        notify(.contributorsChanged)
    }

    public func removeProvider(providerID: String) {
        let oldCount = registeredContributors.count
        registeredContributors.removeAll { $0.providerID == providerID }
        guard oldCount != registeredContributors.count else { return }
        notify(.contributorsChanged)
    }

    public func isProviderRegistered(providerID: String) -> Bool {
        registeredContributors.contains { $0.providerID == providerID }
    }

    public func allRules() -> [AgentRuleDefinition] {
        var result: [AgentRuleDefinition] = []
        var seenIDs: Set<String> = []

        for contributor in registeredContributors {
            for rule in contributor.allRules {
                guard !rule.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !seenIDs.contains(rule.id) else { continue }
                seenIDs.insert(rule.id)
                result.append(rule)
            }
        }

        return result
    }

    public func rulesGroupedByContributor() -> [(providerID: String, rules: [AgentRuleDefinition])] {
        registeredContributors.compactMap { contributor in
            let rules = contributor.allRules.filter {
                !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return rules.isEmpty ? nil : (providerID: contributor.providerID, rules: rules)
        }
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (AgentRuleProvidingEvent) -> Void
    ) -> any AgentRuleProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: AgentRuleProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        for observer in observers {
            observer.observer?.invoke(event)
        }
    }

    private final class Observer: AgentRuleProvidingObserverHandle {
        private weak var owner: DefaultAgentRuleProvider?
        private let callback: (AgentRuleProvidingEvent) -> Void
        private var cancelled = false

        init(owner: DefaultAgentRuleProvider, callback: @escaping (AgentRuleProvidingEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            owner?.remove(self)
        }

        func invoke(_ event: AgentRuleProvidingEvent) {
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
