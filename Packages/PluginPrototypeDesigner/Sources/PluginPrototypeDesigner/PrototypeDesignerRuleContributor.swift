import Foundation
import ProviderAgentRules

/// Prototype Designer 插件贡献的 Agent 规则。
public struct PrototypeDesignerRuleContributor: AgentRuleContributing {
    public let providerID: String
    private let rules: [AgentRuleDefinition]

    public init(
        providerID: String = "com.coffic.lumi.plugin.prototype-designer",
        resourceName: String = "prototype-designer-workflow"
    ) {
        self.providerID = providerID
        self.rules = Self.loadRule(resourceName: resourceName)
    }

    public var allRules: [AgentRuleDefinition] { rules }

    private static func loadRule(resourceName: String) -> [AgentRuleDefinition] {
        guard let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: "md",
            subdirectory: "AgentRules"
        ), let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        let (title, description) = metadata(from: content, fallbackTitle: resourceName)
        return [AgentRuleDefinition(
            id: resourceName,
            title: title,
            description: description,
            content: content,
            version: "1.0.0"
        )]
    }

    private static func metadata(
        from content: String,
        fallbackTitle: String
    ) -> (title: String, description: String) {
        let lines = content.components(separatedBy: .newlines)
        var title = fallbackTitle
        var descriptionStartIndex = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                descriptionStartIndex = index + 1
                break
            }
        }

        var descriptionLines: [String] = []
        for line in lines.dropFirst(descriptionStartIndex) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                descriptionLines.append(trimmed)
                if descriptionLines.count >= 3 { break }
            } else if !descriptionLines.isEmpty {
                break
            }
        }

        let description = descriptionLines.joined(separator: " ")
        return (title, description.isEmpty ? "Plugin-contributed agent rule." : description)
    }
}
