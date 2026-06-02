import Foundation

public enum AnthropicToolResultContentBuilder {
    public static func message(for message: ChatMessage, toolCallID: String) -> [String: Any] {
        if message.images.isEmpty {
            return [
                "role": "user",
                "content": [
                    ["type": "tool_result", "tool_use_id": toolCallID, "content": message.content],
                ],
            ]
        }

        var resultContent: [[String: Any]] = []
        if !message.content.isEmpty {
            resultContent.append(["type": "text", "text": message.content])
        }

        for image in message.images {
            resultContent.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": image.mimeType,
                    "data": image.data.base64EncodedString(),
                ],
            ])
        }

        return [
            "role": "user",
            "content": [
                ["type": "tool_result", "tool_use_id": toolCallID, "content": resultContent],
            ],
        ]
    }
}
