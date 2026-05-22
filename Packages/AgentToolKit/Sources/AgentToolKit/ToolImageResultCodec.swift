import Foundation

/// 工具图片结果编解码器
///
/// 用于在工具执行结果中嵌入图片数据。
/// 格式：`__LUMI_TOOL_IMAGE_RESULT__:` + JSON payload
public enum ToolImageResultCodec {
    private static let markerPrefix = "__LUMI_TOOL_IMAGE_RESULT__:"

    struct Payload: Codable {
        let content: String
        let images: [Image]

        struct Image: Codable {
            let dataBase64: String
            let mimeType: String
        }
    }

    public static func encode(content: String, images: [ImageAttachment]) -> String {
        let payload = Payload(
            content: content,
            images: images.map {
                Payload.Image(
                    dataBase64: $0.data.base64EncodedString(),
                    mimeType: $0.mimeType
                )
            }
        )

        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return content
        }

        return markerPrefix + json
    }

    public static func decode(_ result: String) -> (content: String, images: [ImageAttachment])? {
        guard result.hasPrefix(markerPrefix) else {
            return nil
        }

        let json = String(result.dropFirst(markerPrefix.count))
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }

        let images = payload.images.compactMap { image -> ImageAttachment? in
            guard let data = Data(base64Encoded: image.dataBase64) else {
                return nil
            }
            return ImageAttachment(data: data, mimeType: image.mimeType)
        }

        return (payload.content, images)
    }
}
