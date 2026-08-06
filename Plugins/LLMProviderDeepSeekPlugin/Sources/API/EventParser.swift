import Foundation

enum DeepSeekEventParser {
    static func parse(_ data: Data) -> [DeepSeekEvent] {
        let text = String(decoding: data, as: UTF8.self)
        return text
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("data:") }
            .compactMap { line in
                let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                if payload == "[DONE]" {
                    return DeepSeekEvent(content: nil, reasoning: nil, toolDeltas: [], stopReason: nil, done: true, error: nil, inputTokens: nil, outputTokens: nil, cacheHitTokens: nil, cacheTotalInputTokens: nil)
                }
                guard let jsonData = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                else { return nil }

                if let error = json["error"] as? [String: Any] {
                    return DeepSeekEvent(content: nil, reasoning: nil, toolDeltas: [], stopReason: nil, done: false, error: error["message"] as? String, inputTokens: nil, outputTokens: nil, cacheHitTokens: nil, cacheTotalInputTokens: nil)
                }

                let usage = json["usage"] as? [String: Any]
                let hit = usage?["prompt_cache_hit_tokens"] as? Int
                let miss = usage?["prompt_cache_miss_tokens"] as? Int
                let total = hit.flatMap { h in miss.map { h + $0 } } ?? usage?["prompt_tokens"] as? Int
                let choice = (json["choices"] as? [[String: Any]])?.first
                let delta = choice?["delta"] as? [String: Any]
                let toolDeltas = (delta?["tool_calls"] as? [[String: Any]] ?? []).map { item in
                    let function = item["function"] as? [String: Any]
                    return DeepSeekToolDelta(
                        id: item["id"] as? String,
                        name: function?["name"] as? String,
                        arguments: function?["arguments"] as? String ?? ""
                    )
                }
                return DeepSeekEvent(
                    content: delta?["content"] as? String,
                    reasoning: delta?["reasoning_content"] as? String,
                    toolDeltas: toolDeltas,
                    stopReason: choice?["finish_reason"] as? String,
                    done: false,
                    error: nil,
                    inputTokens: total,
                    outputTokens: usage?["completion_tokens"] as? Int,
                    cacheHitTokens: hit,
                    cacheTotalInputTokens: total
                )
            }
    }
}
