import Foundation
import SwiftUI

/// HTML 内联颜色预览视图
///
/// 在颜色值（如 `#ff0000`、`rgb(255, 0, 0)`、`red`）旁边显示颜色预览。
/// 支持在 `style` 属性和 `<style>` 块内的颜色值。
public struct ColorPreviewView: View {
    public let color: Color
    public let hexString: String
    public let size: CGSize

    public init(color: Color, hexString: String, size: CGSize = CGSize(width: 12, height: 12)) {
        self.color = color
        self.hexString = hexString
        self.size = size
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size.width, height: size.height)
            .cornerRadius(2)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
    }
}

/// 颜色值解析器
public enum ColorParser {
    /// 支持的 CSS 颜色名称
    public static let namedColors: [String: String] = [
        "red": "#ff0000",
        "blue": "#0000ff",
        "green": "#008000",
        "yellow": "#ffff00",
        "orange": "#ffa500",
        "purple": "#800080",
        "pink": "#ffc0cb",
        "black": "#000000",
        "white": "#ffffff",
        "gray": "#808080",
        "grey": "#808080",
        "silver": "#c0c0c0",
        "navy": "#000080",
        "teal": "#008080",
        "cyan": "#00ffff",
        "magenta": "#ff00ff",
        "lime": "#00ff00",
        "olive": "#808000",
        "maroon": "#800000",
        "aqua": "#00ffff",
        "fuchsia": "#ff00ff",
        "coral": "#ff7f50",
        "salmon": "#fa8072",
        "tomato": "#ff6347",
        "gold": "#ffd700",
        "ivory": "#fffff0",
        "khaki": "#f0e68c",
        "lavender": "#e6e6fa",
        "linen": "#faf0e6",
        "mint": "#98ff98",
        "plum": "#dda0dd",
        "violet": "#ee82ee",
        "wheat": "#f5deb3",
        "indigo": "#4b0082",
        "crimson": "#dc143c",
        "chocolate": "#d2691e",
    ]

    // MARK: - 颜色匹配正则

    /// 匹配十六进制颜色
    public static let hexPattern = try! NSRegularExpression(
        pattern: "#(?:[0-9a-fA-F]{3}){1,2}\\b",
        options: .caseInsensitive
    )

    /// 匹配 rgb/rgba 颜色
    public static let rgbPattern = try! NSRegularExpression(
        pattern: "rgba?\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*(?:,\\s*[\\d.]+\\s*)?\\)",
        options: .caseInsensitive
    )

    /// 匹配 hsl/hsla 颜色
    public static let hslPattern = try! NSRegularExpression(
        pattern: "hsla?\\(\\s*\\d+\\s*,\\s*\\d+%\\s*,\\s*\\d+%\\s*(?:,\\s*[\\d.]+\\s*)?\\)",
        options: .caseInsensitive
    )

    // MARK: - 查找颜色

    /// 在文本中查找所有颜色值
    ///
    /// - Parameter text: 要搜索的文本
    /// - Returns: 颜色匹配结果数组 (range, hexString)
    public static func findColors(in text: String) -> [(range: NSRange, hexString: String, color: Color)] {
        var results: [(range: NSRange, hexString: String, color: Color)] = []
        let nsText = text as NSString

        // 查找十六进制颜色
        hexPattern.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
            guard let match = match else { return }
            let hexValue = nsText.substring(with: match.range)
            if let color = color(fromHex: hexValue) {
                results.append((range: match.range, hexString: hexValue, color: color))
            }
        }

        // 查找 rgb/rgba 颜色
        rgbPattern.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
            guard let match = match else { return }
            let rgbValue = nsText.substring(with: match.range)
            if let color = Color(fromRGB: rgbValue) {
                results.append((range: match.range, hexString: rgbValue, color: color))
            }
        }

        // 查找命名颜色
        let wordPattern = try! NSRegularExpression(pattern: "\\b[a-zA-Z]+\\b", options: [])
        wordPattern.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
            guard let match = match else { return }
            let word = nsText.substring(with: match.range).lowercased()
            if let hexValue = namedColors[word], let color = color(fromHex: hexValue) {
                results.append((range: match.range, hexString: word, color: color))
            }
        }

        return results
    }

    // MARK: - 上下文检查

    /// 检查光标位置是否在颜色值附近
    public static func isNearColor(text: String, character: Int, maxDistance: Int = 20) -> Color? {
        let colors = findColors(in: text)

        for colorMatch in colors {
            let range = colorMatch.range
            let distance = abs(character - range.location)

            if distance <= maxDistance || (character >= range.location && character <= NSMaxRange(range)) {
                return colorMatch.color
            }
        }

        return nil
    }

    /// 从十六进制字符串创建颜色
    private static func color(fromHex hex: String) -> Color? {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        // 处理缩写形式 #RGB -> #RRGGBB
        if hexString.count == 3 {
            let r = String(hexString[hexString.index(hexString.startIndex, offsetBy: 0)])
            let g = String(hexString[hexString.index(hexString.startIndex, offsetBy: 1)])
            let b = String(hexString[hexString.index(hexString.startIndex, offsetBy: 2)])
            hexString = r + r + g + g + b + b
        }

        guard hexString.count == 6 else { return nil }

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let red = Double((rgbValue >> 16) & 0xFF) / 255.0
        let green = Double((rgbValue >> 8) & 0xFF) / 255.0
        let blue = Double(rgbValue & 0xFF) / 255.0

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}

// MARK: - Color 扩展

extension Color {
    /// 从 rgb/rgba 字符串创建颜色
    public init?(fromRGB rgbString: String) {
        let pattern = try! NSRegularExpression(
            pattern: "rgba?\\(\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)\\s*(?:,\\s*([\\d.]+)\\s*)?\\)",
            options: .caseInsensitive
        )

        let range = NSRange(location: 0, length: rgbString.utf16.count)
        guard let match = pattern.firstMatch(in: rgbString, options: [], range: range) else {
            return nil
        }

        let nsString = rgbString as NSString
        let red = Double(nsString.substring(with: match.range(at: 1)))! / 255.0
        let green = Double(nsString.substring(with: match.range(at: 2)))! / 255.0
        let blue = Double(nsString.substring(with: match.range(at: 3)))! / 255.0

        var alpha = 1.0
        if match.range(at: 4).location != NSNotFound {
            alpha = Double(nsString.substring(with: match.range(at: 4)))!
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// 转换为十六进制字符串
    public func toHexString() -> String? {
        // 注意：SwiftUI Color 的内部表示在不同平台有所不同
        // 这里提供一个简化的实现
        return nil
    }
}
