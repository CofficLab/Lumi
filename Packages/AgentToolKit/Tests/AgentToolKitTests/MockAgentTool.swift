import Foundation
@testable import AgentToolKit

struct MockAgentTool: SuperAgentTool {
    let name: String
    let englishDescription: String
    let chineseDescription: String
    let result: String
    let risk: CommandRiskLevel
    var executeDelayNanoseconds: UInt64 = 0
    var failure: Error?

    init(
        name: String = "mock_tool",
        englishDescription: String = "English description",
        chineseDescription: String = "中文描述",
        result: String = "ok",
        risk: CommandRiskLevel = .safe,
        executeDelayNanoseconds: UInt64 = 0,
        failure: Error? = nil
    ) {
        self.name = name
        self.englishDescription = englishDescription
        self.chineseDescription = chineseDescription
        self.result = result
        self.risk = risk
        self.executeDelayNanoseconds = executeDelayNanoseconds
        self.failure = failure
    }

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .english: englishDescription
        case .chinese: chineseDescription
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        switch language {
        case .english:
            ["type": "object", "lang": "en"]
        case .chinese:
            ["type": "object", "lang": "zh"]
        }
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        if let failure {
            throw failure
        }
        if executeDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: executeDelayNanoseconds)
        }
        try context.checkCancellation()
        return result
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        risk
    }
}
