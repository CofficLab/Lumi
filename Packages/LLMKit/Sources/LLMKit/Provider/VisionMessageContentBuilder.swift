import Foundation
import os
import SuperLogKit

public enum VisionMessageContentBuilder: SuperLog {
    public static let emoji = "🖼️"
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.vision-content-builder")
    static let verbose = false

    public static func anthropicBlocks(text: String, images: [MessageImage]) -> [[String: Any]] {
        var content: [[String: Any]] = []
        if Self.verbose {
            let imageBytes = images.reduce(0) { $0 + $1.data.count }
            Self.logger.info("\(Self.t)anthropicBlocks start textChars=\(text.count) images=\(images.count) imageBytes=\(imageBytes)")
        }

        if !text.isEmpty {
            content.append(["type": "text", "text": text])
        }

        var totalBase64Chars = 0
        for image in images {
            let base64 = image.data.base64EncodedString()
            totalBase64Chars += base64.count
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": image.mimeType,
                    "data": base64,
                ],
            ])
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)anthropicBlocks done blocks=\(content.count) imageBase64Chars=\(totalBase64Chars)")
        }

        return content
    }

    public static func openAIContent(text: String, images: [MessageImage]) -> Any {
        guard !images.isEmpty else { return text }

        var content: [[String: Any]] = []
        if Self.verbose {
            let imageBytes = images.reduce(0) { $0 + $1.data.count }
            Self.logger.info("\(Self.t)openAIContent start textChars=\(text.count) images=\(images.count) imageBytes=\(imageBytes)")
        }
        if !text.isEmpty {
            content.append(["type": "text", "text": text])
        }

        var totalDataURLChars = 0
        for image in images {
            let dataURL = "data:\(image.mimeType);base64,\(image.data.base64EncodedString())"
            totalDataURLChars += dataURL.count
            content.append([
                "type": "image_url",
                "image_url": ["url": dataURL],
            ])
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)openAIContent done parts=\(content.count) imageDataURLChars=\(totalDataURLChars)")
        }

        return content
    }
}
