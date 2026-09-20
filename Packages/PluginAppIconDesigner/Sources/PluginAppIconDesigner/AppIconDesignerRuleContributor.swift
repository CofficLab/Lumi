import Foundation
import ProviderAgentRules

/// App Icon Designer 插件贡献的 Agent 规则。
public struct AppIconDesignerRuleContributor: AgentRuleContributing {
    public let providerID: String
    private let rules: [AgentRuleDefinition]

    public init(
        providerID: String = "com.coffic.lumi.plugin.app-icon-designer",
        directoryName: String = "AgentRules"
    ) {
        self.providerID = providerID
        self.rules = Self.loadRules(from: directoryName)
    }

    public var allRules: [AgentRuleDefinition] { rules }

    private static func loadRules(from directoryName: String) -> [AgentRuleDefinition] {
        guard let root = Bundle.module.resourceURL?.appendingPathComponent(
            directoryName,
            isDirectory: true
        ), let files = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { file in
                guard let content = try? String(contentsOf: file, encoding: .utf8) else {
                    return nil
                }

                let id = file.deletingPathExtension().lastPathComponent
                let (title, description) = metadata(from: content, fallbackTitle: id)
                return AgentRuleDefinition(
                    id: id,
                    title: title,
                    description: description,
                    content: content,
                    version: "plugin"
                )
            }
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
