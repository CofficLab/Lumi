import EditorService
import Foundation
import LanguageServerProtocol

@MainActor
enum ProblemsAddToChat {
    static func post(_ text: String, windowId: UUID?) {
        var userInfo: [String: Any] = ["text": text]
        if let windowId {
            userInfo["windowId"] = windowId
        }
        NotificationCenter.default.post(
            name: EditorContext.addToChatNotificationName,
            object: nil,
            userInfo: userInfo
        )
    }

    static func message(
        for diagnostic: Diagnostic,
        relativeFilePath: String,
        prompt: String
    ) -> String {
        let line = Int(diagnostic.range.start.line) + 1
        let column = Int(diagnostic.range.start.character) + 1
        let severity = severityLabel(for: diagnostic.severity)
        let source = diagnostic.source ?? "LSP"
        return """
        \(prompt)

        \(relativeFilePath):\(line):\(column)
        \(severity) (\(source)): \(diagnostic.message)
        """
    }

    static func message(
        for problem: EditorSemanticProblem,
        prompt: String
    ) -> String {
        """
        \(prompt)

        \(problem.title)
        \(problem.message)
        """
    }

    private static func severityLabel(for severity: DiagnosticSeverity?) -> String {
        switch severity {
        case .error: "Error"
        case .warning: "Warning"
        case .information: "Information"
        case .hint: "Hint"
        case .none: "Diagnostic"
        }
    }
}
