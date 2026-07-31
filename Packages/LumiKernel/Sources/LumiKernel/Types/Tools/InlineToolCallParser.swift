import Foundation

public struct ParsedInlineToolCalls: Sendable {
    public let cleanedContent: String
    public let toolCalls: [LumiToolCall]

    public init(cleanedContent: String, toolCalls: [LumiToolCall]) {
        self.cleanedContent = cleanedContent
        self.toolCalls = toolCalls
    }
}

/// Converts the common XML tool-call formats emitted by models that ignore the
/// OpenAI-compatible structured tool-call channel into Lumi tool calls.
public enum InlineToolCallParser {
    public static func parse(
        _ content: String,
        availableToolNames: Set<String>
    ) -> ParsedInlineToolCalls? {
        var calls: [LumiToolCall] = []
        var ranges: [Range<String.Index>] = []

        let toolCallPattern = #"(?s)<tool_call>\s*(.*?)\s*</tool_call>"#
        if let regex = try? NSRegularExpression(pattern: toolCallPattern) {
            let nsContent = content as NSString
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
            for match in matches {
                guard let payloadRange = Range(match.range(at: 1), in: content),
                      let call = parseJSONCall(String(content[payloadRange]), availableToolNames: availableToolNames)
                        ?? parseTaggedCall(String(content[payloadRange]), availableToolNames: availableToolNames),
                      let fullRange = Range(match.range, in: content) else { continue }
                calls.append(call)
                ranges.append(fullRange)
            }
        }

        let invokePattern = #"(?s)<invoke\s+name=[\"']([^\"']+)[\"']\s*>(.*?)</invoke>"#
        if let regex = try? NSRegularExpression(pattern: invokePattern) {
            let nsContent = content as NSString
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
            for match in matches {
                guard let nameRange = Range(match.range(at: 1), in: content),
                      let bodyRange = Range(match.range(at: 2), in: content),
                      let fullRange = Range(match.range, in: content) else { continue }
                let arguments = parseParameters(String(content[bodyRange]))
                calls.append(makeCall(name: String(content[nameRange]), arguments: arguments, availableToolNames: availableToolNames))
                ranges.append(fullRange)
            }
        }

        guard !calls.isEmpty else { return nil }
        var cleaned = content
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            cleaned.removeSubrange(range)
        }
        return ParsedInlineToolCalls(
            cleanedContent: cleaned.trimmingCharacters(in: .whitespacesAndNewlines),
            toolCalls: calls
        )
    }

    private static func parseJSONCall(_ payload: String, availableToolNames: Set<String>) -> LumiToolCall? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = object["name"] as? String else { return nil }

        let rawArguments: Any = object["arguments"] ?? [:]
        let argumentsObject: Any
        if let string = rawArguments as? String,
           let stringData = string.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: stringData) {
            argumentsObject = decoded
        } else {
            argumentsObject = rawArguments
        }
        guard JSONSerialization.isValidJSONObject(argumentsObject),
              let argumentsData = try? JSONSerialization.data(withJSONObject: argumentsObject),
              let arguments = String(data: argumentsData, encoding: .utf8) else { return nil }
        return makeCall(name: name, arguments: arguments, availableToolNames: availableToolNames)
    }

    private static func parseParameters(_ body: String) -> String {
        var values: [String: Any] = [:]
        let pattern = #"(?s)<parameter\s+name=[\"']([^\"']+)[\"']\s*>(.*?)</parameter>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "{}" }
        let nsBody = body as NSString
        for match in regex.matches(in: body, range: NSRange(location: 0, length: nsBody.length)) {
            guard let keyRange = Range(match.range(at: 1), in: body),
                  let valueRange = Range(match.range(at: 2), in: body) else { continue }
            let value = String(body[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            values[String(body[keyRange])] = value
        }
        guard let data = try? JSONSerialization.data(withJSONObject: values),
              let result = String(data: data, encoding: .utf8) else { return "{}" }
        return result
    }

    private static func parseTaggedCall(_ payload: String, availableToolNames: Set<String>) -> LumiToolCall? {
        let pattern = #"(?s)<name>\s*([^<]+?)\s*</name>.*?<arguments>\s*(.*?)\s*</arguments>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: payload, range: NSRange(location: 0, length: (payload as NSString).length)),
              let nameRange = Range(match.range(at: 1), in: payload),
              let argumentsRange = Range(match.range(at: 2), in: payload) else { return nil }
        let name = String(payload[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let arguments = String(payload[argumentsRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let normalizedData = try? JSONSerialization.data(withJSONObject: object),
              let normalized = String(data: normalizedData, encoding: .utf8) else { return nil }
        return makeCall(name: name, arguments: normalized, availableToolNames: availableToolNames)
    }

    private static func makeCall(name: String, arguments: String, availableToolNames: Set<String>) -> LumiToolCall {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()
        let resolved = availableToolNames.first(where: { $0.lowercased() == lowercased })
            ?? (lowercased == "glob" && availableToolNames.contains("glob") ? "glob" : normalized)
        return LumiToolCall(id: "inline_(UUID().uuidString)", name: resolved, arguments: arguments)
    }
}
