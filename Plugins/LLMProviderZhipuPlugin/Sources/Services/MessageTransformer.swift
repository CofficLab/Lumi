import AgentToolKit
import Foundation
import LumiCoreKit
import os

/// 智谱 API 消息与工具格式转换
enum MessageTransformer {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.zhipu.transform")

    static func transform(_ message: ChatMessage) -> [String: Any] {
        if let toolCallID = message.toolCallID {
            return AnthropicToolResultContentBuilder.message(for: message, toolCallID: toolCallID)
        }

        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            var content: [[String: Any]] = []

            if !message.content.isEmpty {
                content.append(["type": "text", "text": message.content])
            }

            for toolCall in toolCalls {
                let inputObject: [String: Any]
                if let data = toolCall.arguments.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    inputObject = json
                } else {
                    inputObject = [:]
                }
                content.append([
                    "type": "tool_use",
                    "id": toolCall.id,
                    "name": toolCall.name,
                    "input": inputObject,
                ])
            }

            return ["role": "assistant", "content": content]
        }

        if !message.images.isEmpty {
            if ZhipuProvider.verbose {
                logger.info("消息包含 \(message.images.count) 张图片，正在转换...")
            }

            var content: [[String: Any]] = []

            if !message.content.isEmpty {
                content.append(["type": "text", "text": message.content])
            }

            for (index, image) in message.images.enumerated() {
                let base64Data = image.data.base64EncodedString()
                if ZhipuProvider.verbose {
                    logger.info("图片 \(index + 1): \(image.mimeType), base64长度: \(base64Data.count)")
                }
                content.append([
                    "type": "image",
                    "source": ["type": "base64", "media_type": image.mimeType, "data": base64Data],
                ])
            }

            if ZhipuProvider.verbose {
                logger.info("已将 \(message.images.count) 张图片转换为 API 格式")
            }

            return ["role": message.role.rawValue, "content": content]
        }

        if message.content.contains("[IMAGE_BASE64:") {
            return transformLegacyImageContent(message)
        }

        return ["role": message.role.rawValue, "content": message.content]
    }

    static func formatTool(_ tool: SuperAgentTool) -> [String: Any] {
        ["name": tool.name, "description": tool.description, "input_schema": tool.inputSchema]
    }

    private static func transformLegacyImageContent(_ message: ChatMessage) -> [String: Any] {
        var content: [[String: Any]] = []
        let components = message.content.components(separatedBy: "[IMAGE_BASE64:")

        if !components[0].isEmpty {
            content.append(["type": "text", "text": components[0]])
        }

        for component in components.dropFirst() {
            if let closeBracketIndex = component.firstIndex(of: "]") {
                let imagePart = component[..<closeBracketIndex]
                let textPart = component[component.index(after: closeBracketIndex)...]

                let imageComponents = imagePart.split(separator: ":", maxSplits: 1)
                if imageComponents.count == 2 {
                    let mimeType = String(imageComponents[0])
                    let base64Data = String(imageComponents[1])
                    content.append([
                        "type": "image",
                        "source": ["type": "base64", "media_type": mimeType, "data": base64Data],
                    ])
                }

                if !textPart.isEmpty {
                    let cleanText = String(textPart).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanText.isEmpty {
                        content.append(["type": "text", "text": cleanText])
                    }
                }
            }
        }

        return ["role": message.role.rawValue, "content": content]
    }
}
