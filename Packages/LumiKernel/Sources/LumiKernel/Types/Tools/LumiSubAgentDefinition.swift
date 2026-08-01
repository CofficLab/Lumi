import Foundation

public struct LumiSubAgentDefinition: Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    public let providerID: String
    public let modelID: String
    public let systemPrompt: String
    public let requiredTags: Set<LumiToolTag>
    public let excludedTags: Set<LumiToolTag>
    public let additionalToolNames: Set<String>
    public let excludedToolNames: Set<String>
    public let maxTurns: Int
    public let iconName: String?

    /// When `true`, the runtime ignores `providerID`/`modelID` and instead runs
    /// this sub-agent with the host's currently selected provider and model
    /// (read live from `LLMProviderManaging` at execution time).
    ///
    /// This lets a plugin ship provider-agnostic built-in sub-agents that always
    /// track the user's active model, instead of being pinned to one provider.
    /// Resolution happens lazily in `SubAgentDelegateTool.runDelegate`, so model
    /// switches take effect immediately without re-collecting contributions.
    ///
    /// Defaults to `false` to preserve the pinned-provider behavior.
    public let inheritsSelectedProvider: Bool

    /// Stable internal routing key. Sub-agent ids are provider-local, so two
    /// providers may both register an agent named "explore" without colliding.
    public var routingID: String { "\(providerID):\(id)" }

    public init(
        id: String,
        displayName: String,
        description: String,
        providerID: String,
        modelID: String,
        systemPrompt: String,
        requiredTags: Set<LumiToolTag> = [],
        excludedTags: Set<LumiToolTag> = [],
        additionalToolNames: Set<String> = [],
        excludedToolNames: Set<String> = [],
        maxTurns: Int = 10,
        iconName: String? = nil,
        inheritsSelectedProvider: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.providerID = providerID
        self.modelID = modelID
        self.systemPrompt = systemPrompt
        self.requiredTags = requiredTags
        self.excludedTags = excludedTags
        self.additionalToolNames = additionalToolNames
        self.excludedToolNames = excludedToolNames
        self.maxTurns = maxTurns
        self.iconName = iconName
        self.inheritsSelectedProvider = inheritsSelectedProvider
    }
}
