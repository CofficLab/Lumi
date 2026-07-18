public struct LumiPluginEligibility: Equatable, Sendable {
    public let policy: LumiPluginPolicy
    public let userEnabled: Bool

    public init(policy: LumiPluginPolicy, userEnabled: Bool) {
        self.policy = policy
        self.userEnabled = userEnabled
    }

    public var shouldRegister: Bool {
        policy.shouldRegister
    }

    public var isConfigurable: Bool {
        policy.isConfigurable
    }

    public var enabledByDefault: Bool {
        policy.enabledByDefault
    }

    public var isEligible: Bool {
        guard shouldRegister else { return false }
        guard isConfigurable else { return true }
        return userEnabled
    }

    public var appearsInSettings: Bool {
        shouldRegister
    }
}
