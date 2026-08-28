import Foundation
import os

/// 视觉消息内容构建器（Anthropic / OpenAI 两种协议的图片块格式）。
public enum VisionMessageContentBuilder {
    nonisolated static let logger = Logger(subsystem: "com.kit.llm", category: "vision-content-builder")
    nonisolated static let verbose = false

    public static func anthropicBlocks(text: String, images: [MessageImage]) -> [[String: Any]] {
        var content: [[String: Any]] = []
        if verbose {
            let imageBytes = images.reduce(0) { $0 + $1.data.count }
            logger.info("anthropicBlocks start textChars=\(text.count) images=\(images.count) imageBytes=\(imageBytes)")
        }

        if !text.isEmpty {
            content.append(["type": "text", "text": text])
        }

        for image in images {
            let base64 = image.data.base64EncodedString()
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": image.mimeType,
                    "data": base64,
                ],
            ])
        }
        if verbose {
            let totalBase64Chars = images.reduce(0) { $0 + $1.data.base64EncodedString().count }
            logger.info("anthropicBlocks done blocks=\(content.count) imageBase64Chars=\(totalBase64Chars)")
        }

        return content
    }

    public static func openAIContent(text: String, images: [MessageImage]) -> Any {
        guard !images.isEmpty else { return text }

        var content: [[String: Any]] = []
        if verbose {
            let imageBytes = images.reduce(0) { $0 + $1.data.count }
            logger.info("openAIContent start textChars=\(text.count) images=\(images.count) imageBytes=\(imageBytes)")
        }
        if !text.isEmpty {
            content.append(["type": "text", "text": text])
        }

        for image in images {
            let dataURL = "data:\(image.mimeType);base64,\(image.data.base64EncodedString())"
            content.append([
                "type": "image_url",
                "image_url": ["url": dataURL],
            ])
        }
        if verbose {
            let totalDataURLChars = images.reduce(0) { $0 + "data:\($1.mimeType);base64,\($1.data.base64EncodedString())".count }
            logger.info("openAIContent done parts=\(content.count) imageDataURLChars=\(totalDataURLChars)")
        }

        return content
    }
}
