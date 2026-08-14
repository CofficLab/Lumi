import Foundation

/// 从 LLM 的回复中提取 `<artifact>` 标签内的原型产物。
///
/// 优先取**最后一个** artifact：多轮迭代时 LLM 会输出更新后的版本，
/// 最后一个即为最新的完整原型。
enum ArtifactExtractor {
    /// 正则：捕获属性串与内部 HTML（非贪婪、跨行）。
    private static let pattern = #"<artifact([^>]*)>([\s\S]*?)</artifact>"#

    /// 从文本中提取最新的产物；未找到 artifact 标签时返回 `nil`。
    static func extract(from text: String) -> PrototypeArtifact? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard let last = matches.last, last.numberOfRanges >= 3 else { return nil }

        let attributes = nsText.substring(with: last.range(at: 1))
        let html = nsText
            .substring(with: last.range(at: 2))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let title = parseAttribute(named: "title", in: attributes) ?? "Untitled"
        let deviceRaw = parseAttribute(named: "device", in: attributes) ?? PrototypeArtifact.Device.iphone.rawValue
        let device = PrototypeArtifact.Device(rawValue: deviceRaw) ?? .iphone

        return PrototypeArtifact(title: title, device: device, html: html)
    }

    /// 从 `key="value"` 形式的属性串中提取指定属性的值。
    private static func parseAttribute(named name: String, in attributes: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\#(name)\s*=\s*"([^"]*)""#, options: []) else {
            return nil
        }
        let nsAttributes = attributes as NSString
        guard let match = regex.firstMatch(
            in: attributes,
            options: [],
            range: NSRange(location: 0, length: nsAttributes.length)
        ), match.numberOfRanges >= 2 else {
            return nil
        }
        let value = nsAttributes.substring(with: match.range(at: 1))
        return value.isEmpty ? nil : value
    }
}
