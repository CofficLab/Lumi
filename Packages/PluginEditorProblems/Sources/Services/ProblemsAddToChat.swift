import Foundation
import KernelLumi

@MainActor
enum ProblemsAddToChat {
    static func post(_ text: String, windowId: UUID?) {
        var userInfo: [String: Any] = ["text": text]
        if let windowId {
            userInfo["windowId"] = windowId
        }
        NotificationCenter.default.post(
            name: LumiEditorNotifications.addToChat,
            object: nil,
            userInfo: userInfo
        )
    }

    static func message(
        for diagnostic: EditorDiagnosticItem,
        relativeFilePath: String,
        prompt: String
    ) -> String {
        let line = diagnostic.range.start.line + 1
        let column = diagnostic.range.start.character + 1
        let severity = severityLabel(for: diagnostic.severity)
        let source = diagnostic.source ?? "LSP"
        return """
        \(prompt)

        \(relativeFilePath):\(line):\(column)
        \(severity) (\(source)): \(diagnostic.message)
        """
    }

    private static func severityLabel(for severity: EditorDiagnosticSeverity) -> String {
        switch severity {
        case .error: "Error"
        case .warning: "Warning"
        case .information: "Information"
        case .hint: "Hint"
        }
    }
}
