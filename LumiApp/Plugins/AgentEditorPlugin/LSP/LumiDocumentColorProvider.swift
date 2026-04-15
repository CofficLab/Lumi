import SwiftUI
import LanguageServerProtocol

/// 文档颜色提供者
@MainActor
final class LumiDocumentColorProvider: ObservableObject {
    
    private let lspService = LumiLSPService.shared
    
    @Published var colors: [LumiDocumentColor] = []
    
    var isAvailable: Bool { lspService.isAvailable }
    
    func requestColors(uri: String) async {
        let serverColors = await lspService.requestDocumentColors(uri: uri)
        colors = serverColors.map { info in
            LumiDocumentColor(
                range: info.range,
                red: Double(info.color.red),
                green: Double(info.color.green),
                blue: Double(info.color.blue),
                alpha: Double(info.color.alpha)
            )
        }
    }
    
    func requestColorPresentations(uri: String, color: LumiDocumentColor) async -> [ColorPresentation] {
        let range = color.range
        return await lspService.requestColorPresentation(
            uri: uri,
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha,
            range: range
        )
    }
    
    func clear() { colors.removeAll() }
    
    func colorAtPosition(line: Int, character: Int) -> LumiDocumentColor? {
        let position = Position(line: line, character: character)
        return colors.first { c in
            position >= c.range.start && position <= c.range.end
        }
    }
}

struct LumiDocumentColor: Identifiable, Equatable {
    let id = UUID()
    let range: LSPRange
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    var nsColor: NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
    
    var hexString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        let a = Int(round(alpha * 255))
        if alpha >= 1.0 {
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
    }
    
    var rgbString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        if alpha >= 1.0 {
            return String(format: "rgb(%d, %d, %d)", r, g, b)
        } else {
            return String(format: "rgba(%d, %d, %d, %.2f)", r, g, b, alpha)
        }
    }
    
    var hslString: String {
        let (h, s, l) = rgbToHSL(red: red, green: green, blue: blue)
        if alpha >= 1.0 {
            return String(format: "hsl(%d, %d%%, %d%%)", h, Int(s * 100), Int(l * 100))
        } else {
            return String(format: "hsla(%d, %d%%, %d%%, %.2f)", h, Int(s * 100), Int(l * 100), alpha)
        }
    }
    
    private func rgbToHSL(red: Double, green: Double, blue: Double) -> (hue: Int, saturation: Double, lightness: Double) {
        let max = Swift.max(red, green, blue)
        let min = Swift.min(red, green, blue)
        let l = (max + min) / 2.0
        var h: Double = 0, s: Double = 0
        if max != min {
            let d = max - min
            s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min)
            if max == red { h = (green - blue) / d + (green < blue ? 6 : 0) }
            else if max == green { h = (blue - red) / d + 2 }
            else { h = (red - green) / d + 4 }
            h /= 6.0
        }
        return (Int(round(h * 360)), s, l)
    }
}

struct LumiColorPreview: View {
    let color: LumiDocumentColor
    var body: some View {
        Circle()
            .fill(Color(nsColor: color.nsColor))
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .help(color.hexString)
    }
}
