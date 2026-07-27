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
        iconName: String? = nil
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
    }
}
