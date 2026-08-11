import Foundation

enum XiaomiEventParser {
    static func parse(_ data: Data) -> [XiaomiEvent] {
        let text = String(decoding: data, as: UTF8.self)
        return text
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("data:") }
            .compactMap { line in
                let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                if payload == "[DONE]" {
                    return XiaomiEvent(content: nil, toolDeltas: [], stopReason: nil, done: true, error: nil, inputTokens: nil, outputTokens: nil)
                }
                guard let jsonData = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                else { return nil }

                if let error = json["error"] as? [String: Any] {
                    return XiaomiEvent(content: nil, toolDeltas: [], stopReason: nil, done: false, error: error["message"] as? String, inputTokens: nil, outputTokens: nil)
                }

                let usage = json["usage"] as? [String: Any]
                let choice = (json["choices"] as? [[String: Any]])?.first
                let delta = choice?["delta"] as? [String: Any]
                let toolDeltas = (delta?["tool_calls"] as? [[String: Any]] ?? []).map { item in
                    let function = item["function"] as? [String: Any]
                    return XiaomiToolDelta(
                        id: item["id"] as? String,
                        name: function?["name"] as? String,
                        arguments: function?["arguments"] as? String ?? ""
                    )
                }
                return XiaomiEvent(
                    content: delta?["content"] as? String,
                    toolDeltas: toolDeltas,
                    stopReason: choice?["finish_reason"] as? String,
                    done: false,
                    error: nil,
                    inputTokens: usage?["prompt_tokens"] as? Int,
                    outputTokens: usage?["completion_tokens"] as? Int
                )
            }
    }
}
