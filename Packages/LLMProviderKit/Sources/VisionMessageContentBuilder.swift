import Foundation

public enum VisionMessageContentBuilder {
    public static func anthropicBlocks(text: String, images: [MessageImage]) -> [[String: Any]] {
        var content: [[String: Any]] = []

        if !text.isEmpty {
            content.append(["type": "text", "text": text])
        }

        for image in images {
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": image.mimeType,
                    "data": image.data.base64EncodedString(),
                ],
            ])
        }

        return content
    }

    public static func openAIContent(text: String, images: [MessageImage]) -> Any {
        guard !images.isEmpty else { return text }

        var content: [[String: Any]] = []
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

        return content
    }
}
