import Foundation
import os

/// 视觉消息内容构建器（Anthropic / OpenAI 两种协议的图片块格式）。
///
/// 图片的 Base64 编码走进程内缓存（`ImageBase64Cache`）：一次会话里
/// 多轮 LLM step 会反复把同一批历史图片塞进请求体，每次重新编码都是
/// 与图片字节数成正比的 CPU 与内存分配开销（Issue #1269）。
public enum VisionMessageContentBuilder {
    nonisolated static let logger = Logger(subsystem: "com.kit.llm", category: "vision-content-builder")
    nonisolated static let verbose = false

    /// 图片 Base64 编码缓存。
    ///
    /// 进程内共享：一次会话的多个 LLM step 复用同一份编码结果。
    private static let base64Cache = ImageBase64Cache()

    public static func anthropicBlocks(text: String, images: [MessageImage]) -> [[String: Any]] {
        var content: [[String: Any]] = []
        if verbose {
            let imageBytes = images.reduce(0) { $0 + $1.data.count }
            logger.info("anthropicBlocks start textChars=\(text.count) images=\(images.count) imageBytes=\(imageBytes)")
        }

        if !text.isEmpty {
            content.append(["type": "text", "text": text])
        }

        var encodedChars = 0
        for image in images {
            let base64 = base64Cache.base64(for: image.data)
            // `String.count` 是 O(n) 的 grapheme cluster 遍历（100 万字符约
            // 1.9 ms），而 `utf8.count` 是 O(1)。日志只需要字节数，用后者。
            encodedChars += base64.utf8.count
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
            // 直接复用已编码的长度，不再为了打日志重新编码一遍。
            logger.info("anthropicBlocks done blocks=\(content.count) imageBase64Chars=\(encodedChars)")
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

        var encodedChars = 0
        for image in images {
            let base64 = base64Cache.base64(for: image.data)
            // 同上：用 O(1) 的 `utf8.count` 而不是 O(n) 的 `count`。
            encodedChars += base64.utf8.count
            let dataURL = "data:\(image.mimeType);base64,\(base64)"
            content.append([
                "type": "image_url",
                "image_url": ["url": dataURL],
            ])
        }
        if verbose {
            // 直接复用已编码的长度，不再为了打日志重新编码一遍。
            logger.info("openAIContent done parts=\(content.count) imageDataURLChars=\(encodedChars)")
        }

        return content
    }
}
