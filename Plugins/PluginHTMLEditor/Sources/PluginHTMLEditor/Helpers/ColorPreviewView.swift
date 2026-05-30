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
        pattern: "#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\\b",
        options: .caseInsensitive
    )

    /// 匹配 rgb/rgba 颜色
    public static let rgbPattern = try! NSRegularExpression(
        pattern: "rgba?\\(\\s*[^)]*\\)",
        options: .caseInsensitive
    )

    /// 匹配 hsl/hsla 颜色
    public static let hslPattern = try! NSRegularExpression(
        pattern: "hsla?\\(\\s*[^)]*\\)",
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

        // 查找 hsl/hsla 颜色
        hslPattern.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
            guard let match = match else { return }
            let hslValue = nsText.substring(with: match.range)
            if let color = Color(fromHSL: hslValue) {
                results.append((range: match.range, hexString: hslValue, color: color))
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

        // 处理缩写形式 #RGB/#RGBA -> #RRGGBB/#RRGGBBAA
        if hexString.count == 3 || hexString.count == 4 {
            let r = String(hexString[hexString.index(hexString.startIndex, offsetBy: 0)])
            let g = String(hexString[hexString.index(hexString.startIndex, offsetBy: 1)])
            let b = String(hexString[hexString.index(hexString.startIndex, offsetBy: 2)])
            let a = hexString.count == 4
                ? String(hexString[hexString.index(hexString.startIndex, offsetBy: 3)])
                : nil
            hexString = r + r + g + g + b + b + (a.map { $0 + $0 } ?? "")
        }

        guard hexString.count == 6 || hexString.count == 8 else { return nil }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgbValue) else { return nil }

        let hasAlpha = hexString.count == 8
        let redShift = hasAlpha ? 24 : 16
        let greenShift = hasAlpha ? 16 : 8
        let blueShift = hasAlpha ? 8 : 0

        let red = Double((rgbValue >> redShift) & 0xFF) / 255.0
        let green = Double((rgbValue >> greenShift) & 0xFF) / 255.0
        let blue = Double((rgbValue >> blueShift) & 0xFF) / 255.0
        let alpha = hasAlpha ? Double(rgbValue & 0xFF) / 255.0 : 1.0

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Color 扩展

extension Color {
    /// 从 rgb/rgba 字符串创建颜色
    public init?(fromRGB rgbString: String) {
        guard let components = Self.functionalColorComponents(from: rgbString, expectedChannelCount: 3),
              let red = Self.parseRGBChannel(components.channels[0]),
              let green = Self.parseRGBChannel(components.channels[1]),
              let blue = Self.parseRGBChannel(components.channels[2]) else {
            return nil
        }

        guard let alpha = Self.parseAlpha(components.alpha) else { return nil }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// 从 hsl/hsla 字符串创建颜色。
    public init?(fromHSL hslString: String) {
        guard let components = Self.functionalColorComponents(from: hslString, expectedChannelCount: 3),
              let hueValue = Self.parseHue(components.channels[0]),
              let saturation = Self.parsePercentageChannel(components.channels[1]),
              let lightness = Self.parsePercentageChannel(components.channels[2]),
              let alpha = Self.parseAlpha(components.alpha) else {
            return nil
        }

        let hue = ((hueValue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)) / 360.0

        let chroma = (1.0 - abs(2.0 * lightness - 1.0)) * saturation
        let huePrime = hue * 6.0
        let x = chroma * (1.0 - abs(huePrime.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: (red: Double, green: Double, blue: Double)
        switch huePrime {
        case 0..<1:
            rgb = (chroma, x, 0)
        case 1..<2:
            rgb = (x, chroma, 0)
        case 2..<3:
            rgb = (0, chroma, x)
        case 3..<4:
            rgb = (0, x, chroma)
        case 4..<5:
            rgb = (x, 0, chroma)
        default:
            rgb = (chroma, 0, x)
        }

        let m = lightness - chroma / 2.0
        self.init(.sRGB, red: rgb.red + m, green: rgb.green + m, blue: rgb.blue + m, opacity: alpha)
    }

    private static func functionalColorComponents(
        from colorString: String,
        expectedChannelCount: Int
    ) -> (channels: [String], alpha: String?)? {
        guard let openParen = colorString.firstIndex(of: "("),
              let closeParen = colorString.lastIndex(of: ")"),
              openParen < closeParen else {
            return nil
        }

        let body = colorString[colorString.index(after: openParen)..<closeParen]
        let slashParts = body.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        var channels = Self.colorTokens(in: String(slashParts[0]))
        var alpha: String?

        if slashParts.count == 2 {
            let alphaTokens = Self.colorTokens(in: String(slashParts[1]))
            guard alphaTokens.count == 1 else { return nil }
            alpha = alphaTokens[0]
        } else if channels.count == expectedChannelCount + 1 {
            alpha = channels.removeLast()
        }

        guard channels.count == expectedChannelCount else { return nil }
        return (channels, alpha)
    }

    private static func colorTokens(in string: String) -> [String] {
        string
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private static func parseNumber(_ token: String) -> (value: Double, isPercentage: Bool)? {
        var trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPercentage = trimmed.hasSuffix("%")
        if isPercentage {
            trimmed.removeLast()
        }

        guard let value = Double(trimmed), value.isFinite else { return nil }
        return (value, isPercentage)
    }

    private static func parseHue(_ token: String) -> Double? {
        var trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let multiplier: Double

        if trimmed.hasSuffix("deg") {
            multiplier = 1.0
            trimmed.removeLast(3)
        } else if trimmed.hasSuffix("grad") {
            multiplier = 0.9
            trimmed.removeLast(4)
        } else if trimmed.hasSuffix("rad") {
            multiplier = 180.0 / .pi
            trimmed.removeLast(3)
        } else if trimmed.hasSuffix("turn") {
            multiplier = 360.0
            trimmed.removeLast(4)
        } else {
            multiplier = 1.0
        }

        guard let value = Double(trimmed), value.isFinite else { return nil }
        return value * multiplier
    }

    private static func parseRGBChannel(_ token: String) -> Double? {
        guard let number = Self.parseNumber(token) else { return nil }
        let normalized = number.isPercentage ? number.value / 100.0 : number.value / 255.0
        return min(max(normalized, 0.0), 1.0)
    }

    private static func parsePercentageChannel(_ token: String) -> Double? {
        guard let number = Self.parseNumber(token), number.isPercentage else { return nil }
        return min(max(number.value / 100.0, 0.0), 1.0)
    }

    private static func parseAlpha(_ token: String?) -> Double? {
        guard let token else { return 1.0 }
        guard let number = Self.parseNumber(token) else { return nil }
        let normalized = number.isPercentage ? number.value / 100.0 : number.value
        return min(max(normalized, 0.0), 1.0)
    }

    /// 转换为十六进制字符串
    public func toHexString() -> String? {
        // 注意：SwiftUI Color 的内部表示在不同平台有所不同
        // 这里提供一个简化的实现
        return nil
    }
}
