import AgentToolKit

enum ToolCoreToolRisk {
    static func elevatedRiskIfPathOutOfBounds(
        arguments: [String: ToolArgument],
        baseRisk: CommandRiskLevel,
        context: ToolExecutionContext
    ) -> CommandRiskLevel {
        guard !context.allowedDirectories.isEmpty else { return baseRisk }

        let filePath = (arguments["file_path"]?.value as? String) ??
            (arguments["path"]?.value as? String) ??
            (arguments["directory"]?.value as? String)

        guard let path = filePath else { return baseRisk }
        guard !context.isPathAllowed(path) else { return baseRisk }

        switch baseRisk {
        case .safe:
            return .low
        case .low:
            return .medium
        case .medium:
            return .high
        case .high:
            return .high
        }
    }
}
