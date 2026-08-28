import Foundation

public struct CodexParsedOutput: Equatable {
    var agentMessages: [String]
    var errors: [String]
    var inputTokens: Int?
    var outputTokens: Int?
    var failedMessage: String?
    var nonJSONLines: [String]
}

public enum CodexOutputParser {
    public static func parse(_ output: String) -> CodexParsedOutput {
        var agentMessages: [String] = []
        var errors: [String] = []
        var inputTokens: Int?
        var outputTokens: Int?
        var failedMessage: String?
        var nonJSONLines: [String] = []

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    nonJSONLines.append(trimmed)
                }
                continue
            }

            switch json["type"] as? String {
            case "item.completed":
                if let item = json["item"] as? [String: Any],
                   item["type"] as? String == "agent_message",
                   let text = item["text"] as? String,
                   !text.isEmpty {
                    agentMessages.append(text)
                }
            case "agent_message":
                if let text = json["message"] as? String ?? json["text"] as? String,
                   !text.isEmpty {
                    agentMessages.append(text)
                }
            case "error":
                if let message = json["message"] as? String,
                   !message.contains("Reconnecting") {
                    errors.append(message)
                }
            case "turn.failed":
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    failedMessage = message
                    errors.append(message)
                } else if let message = json["message"] as? String {
                    failedMessage = message
                    errors.append(message)
                }
            case "turn.completed":
                if let usage = json["usage"] as? [String: Any] {
                    inputTokens = usage["input_tokens"] as? Int
                    outputTokens = usage["output_tokens"] as? Int
                }
            default:
                break
            }
        }

        return CodexParsedOutput(
            agentMessages: agentMessages,
            errors: errors,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            failedMessage: failedMessage,
            nonJSONLines: nonJSONLines
        )
    }
}
