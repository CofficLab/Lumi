import Foundation

/// Anthropic Messages API SSE 解析器。
enum AliyunAnthropicEventParser {
    static func parse(_ data: Data) -> [AliyunAnthropicEvent] {
        let text = String(decoding: data, as: UTF8.self)
        var events: [AliyunAnthropicEvent] = []
        
        let frames = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for frame in frames {
            var eventType: String?
            var payload: String?

            for rawLine in frame.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = String(rawLine)
                if line.hasPrefix("event:") {
                    eventType = String(line.dropFirst("event:".count))
                        .trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    let chunk = String(line.dropFirst("data:".count))
                        .trimmingCharacters(in: .whitespaces)
                    payload = chunk
                }
            }

            if let eventType, eventType == "ping" {
                continue
            }

            // 协议层错误
            if eventType == "error", let json = decode(payload) {
                let message = (json["error"] as? [String: Any])?["message"] as? String
                    ?? json["message"] as? String
                events.append(AliyunAnthropicEvent(
                    done: false,
                    error: message ?? "Aliyun API error"
                ))
                continue
            }

            guard let payload, let json = decode(payload) else { continue }

            switch eventType {
            case "message_start":
                let usage = parseUsage(json["message"] as? [String: Any])
                events.append(AliyunAnthropicEvent(usage: usage))

            case "content_block_start":
                let block = json["content_block"] as? [String: Any]
                let type = block?["type"] as? String
                if type == "tool_use" {
                    events.append(AliyunAnthropicEvent(
                        toolName: block?["name"] as? String,
                        toolID: block?["id"] as? String
                    ))
                }

            case "content_block_delta":
                let delta = json["delta"] as? [String: Any]
                let type = delta?["type"] as? String
                switch type {
                case "text_delta":
                    events.append(AliyunAnthropicEvent(
                        textDelta: delta?["text"] as? String
                    ))
                case "thinking_delta":
                    events.append(AliyunAnthropicEvent(
                        thinkingDelta: delta?["thinking"] as? String
                    ))
                case "input_json_delta":
                    events.append(AliyunAnthropicEvent(
                        toolInputJSONDelta: delta?["partial_json"] as? String
                    ))
                default:
                    break
                }

            case "content_block_stop":
                break

            case "message_delta":
                let delta = json["delta"] as? [String: Any]
                let usage = parseUsage(json)
                events.append(AliyunAnthropicEvent(
                    stopReason: delta?["stop_reason"] as? String,
                    stopSequence: delta?["stop_sequence"] as? String,
                    usage: usage
                ))

            case "message_stop":
                events.append(AliyunAnthropicEvent(done: true))

            default:
                break
            }
        }
        return events
    }

    private static func decode(_ payload: String?) -> [String: Any]? {
        guard let payload, let data = payload.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func parseUsage(_ json: [String: Any]?) -> AliyunAnthropicUsage? {
        guard let json else { return nil }
        guard let usage = json["usage"] as? [String: Any] else { return nil }
        return AliyunAnthropicUsage(
            inputTokens: usage["input_tokens"] as? Int,
            outputTokens: usage["output_tokens"] as? Int,
            cacheReadInputTokens: usage["cache_read_input_tokens"] as? Int,
            cacheCreationInputTokens: usage["cache_creation_input_tokens"] as? Int
        )
    }
}
