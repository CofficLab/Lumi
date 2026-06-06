import AgentToolKit
import Foundation
import LumiCoreKit
import os

/// 智谱流式 SSE 响应解析
///
/// 正常内容兼容 Anthropic 格式；结束标记使用 OpenAI 风格的 `data: [DONE]`。
enum StreamParser {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.zhipu.stream")

    static func parseChunk(data: Data) -> StreamChunk? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        if text.contains("data: [DONE]") || text.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
            if ZhipuProvider.verbose {
                logger.info("检测到 [DONE] 标记，流式响应结束")
            }
            return StreamChunk(isDone: true, eventType: .messageStop)
        }

        var eventType: String?
        var eventDataLines: [String] = []

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                eventDataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }

        let dataStr = eventDataLines.isEmpty ? nil : eventDataLines.joined(separator: "\n")
        guard let dataStr, !dataStr.isEmpty else {
            return nil
        }

        guard let jsonData = dataStr.data(using: .utf8) else {
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            return mapEvent(
                json: json,
                eventType: eventType,
                jsonType: json?["type"] as? String,
                rawEvent: text
            )
        } catch {
            if ZhipuProvider.verbose {
                logger.warning("解析流式数据块失败: \(error.localizedDescription)")
            }
            return StreamChunk(
                error: "解析失败: \(error.localizedDescription)",
                eventType: .unknown,
                rawEvent: text
            )
        }
    }

    private static func mapEvent(
        json: [String: Any]?,
        eventType: String?,
        jsonType: String?,
        rawEvent: String
    ) -> StreamChunk {
        let effectiveEventType = eventType ?? jsonType ?? "unknown"

        if let error = json?["error"] as? [String: Any],
           let errorMessage = error["message"] as? String {
            return StreamChunk(error: errorMessage, eventType: .unknown, rawEvent: rawEvent)
        }

        if effectiveEventType == "ping" {
            return StreamChunk(eventType: .ping, rawEvent: rawEvent)
        }

        if effectiveEventType == "message_start" {
            var inputTokens: Int?
            if let message = json?["message"] as? [String: Any],
               let usage = message["usage"] as? [String: Any] {
                inputTokens = usage["input_tokens"] as? Int
            }
            return StreamChunk(eventType: .messageStart, rawEvent: rawEvent, inputTokens: inputTokens)
        }

        if effectiveEventType == "message_delta" {
            let stopReason = (json?["delta"] as? [String: Any])?["stop_reason"] as? String
                ?? json?["stop_reason"] as? String
            var inputTokens: Int?
            var outputTokens: Int?
            if let usage = json?["usage"] as? [String: Any] {
                inputTokens = usage["input_tokens"] as? Int
                outputTokens = usage["output_tokens"] as? Int
            }
            return StreamChunk(
                eventType: .messageDelta,
                rawEvent: rawEvent,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                stopReason: stopReason
            )
        }

        if effectiveEventType == "message_stop" {
            return StreamChunk(isDone: true, eventType: .messageStop, rawEvent: rawEvent)
        }

        if effectiveEventType == "content_block_start" {
            return mapContentBlockStart(json: json, rawEvent: rawEvent)
        }

        if effectiveEventType == "content_block_delta" {
            return mapContentBlockDelta(json: json, rawEvent: rawEvent)
        }

        if effectiveEventType == "content_block_stop" {
            return StreamChunk(eventType: .contentBlockStop, rawEvent: rawEvent)
        }

        return StreamChunk(eventType: .unknown, rawEvent: rawEvent)
    }

    private static func mapContentBlockStart(json: [String: Any]?, rawEvent: String) -> StreamChunk {
        guard let contentBlock = json?["content_block"] as? [String: Any],
              let blockType = contentBlock["type"] as? String else {
            return StreamChunk(eventType: .contentBlockStart, rawEvent: rawEvent)
        }

        if blockType == "thinking" {
            return StreamChunk(eventType: .contentBlockStart, rawEvent: rawEvent)
        }

        if blockType == "tool_use",
           let id = contentBlock["id"] as? String,
           let name = contentBlock["name"] as? String {
            let toolCall = ToolCall(id: id, name: name, arguments: "{}")
            return StreamChunk(toolCalls: [toolCall], eventType: .contentBlockStart, rawEvent: rawEvent)
        }

        if blockType == "text",
           let textContent = contentBlock["text"] as? String,
           !textContent.isEmpty {
            return StreamChunk(content: textContent, eventType: .contentBlockStart, rawEvent: rawEvent)
        }

        return StreamChunk(eventType: .contentBlockStart, rawEvent: rawEvent)
    }

    private static func mapContentBlockDelta(json: [String: Any]?, rawEvent: String) -> StreamChunk {
        guard let delta = json?["delta"] as? [String: Any] else {
            return StreamChunk(eventType: .contentBlockDelta, rawEvent: rawEvent)
        }

        if let thinkingDelta = delta["thinking_delta"] as? String {
            return StreamChunk(content: thinkingDelta, eventType: .thinkingDelta, rawEvent: rawEvent)
        }
        if let thinkingDelta = delta["thinking"] as? String {
            return StreamChunk(content: thinkingDelta, eventType: .thinkingDelta, rawEvent: rawEvent)
        }
        if let textContent = delta["text"] as? String {
            return StreamChunk(content: textContent, eventType: .textDelta, rawEvent: rawEvent)
        }
        if let textDelta = delta["text_delta"] as? String {
            return StreamChunk(content: textDelta, eventType: .textDelta, rawEvent: rawEvent)
        }
        if let partialJson = delta["partial_json"] as? String {
            return StreamChunk(partialJson: partialJson, eventType: .inputJsonDelta, rawEvent: rawEvent)
        }
        if delta["signature"] != nil {
            return StreamChunk(eventType: .signatureDelta, rawEvent: rawEvent)
        }

        return StreamChunk(eventType: .contentBlockDelta, rawEvent: rawEvent)
    }
}
