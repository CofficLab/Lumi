import Foundation
import MCP

/// 把 MCP `Tool.Content` 数组编码为 KitMCP 的结果模型。
public enum MCPContentCodec {
    public static func encode(
        _ content: [Tool.Content],
        isError: Bool
    ) -> MCPCallResult {
        var textParts: [String] = []
        var images: [MCPImageContent] = []
        for item in content {
            switch item {
            case .text(let text, _, _):
                textParts.append(text)
            case .image(let data, let mimeType, _, _):
                images.append(MCPImageContent(base64Data: data, mimeType: mimeType))
            case .audio(let data, let mimeType, _, _):
                textParts.append("[audio \(mimeType), base64 \(data.count) bytes]")
            case .resource(let resource, _, _):
                textParts.append(resourceText(resource))
            case .resourceLink(let uri, let name, _, _, _, _):
                textParts.append("[resource \(name): \(uri)]")
            }
        }
        let text = textParts.joined(separator: "\n")
        return MCPCallResult(text: text, images: images, isError: isError)
    }

    private static func resourceText(_ resource: Resource.Content) -> String {
        if let text = resource.text {
            return text
        }
        if let blob = resource.blob {
            return "[binary resource \(resource.mimeType ?? "application/octet-stream"), base64 \(blob.count) chars]"
        }
        return "[resource \(resource.uri)]"
    }
}
