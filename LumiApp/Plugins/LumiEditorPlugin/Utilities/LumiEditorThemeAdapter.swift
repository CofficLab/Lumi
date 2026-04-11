import SwiftUI
import CodeEditSourceEditor

/// 主题适配器
/// 将预设配色映射到 CodeEditSourceEditor 的 EditorTheme
enum LumiEditorThemeAdapter {
    
    /// 预设主题
    enum PresetTheme: String, CaseIterable {
        case xcodeDark = "xcode-dark"
        case xcodeLight = "xcode-light"
        case midnight = "midnight"
        case solarizedDark = "solarized-dark"
        case solarizedLight = "solarized-light"
        case highContrast = "high-contrast"
        
        var displayName: String {
            switch self {
            case .xcodeDark: return "Xcode Dark"
            case .xcodeLight: return "Xcode Light"
            case .midnight: return "Midnight"
            case .solarizedDark: return "Solarized Dark"
            case .solarizedLight: return "Solarized Light"
            case .highContrast: return "High Contrast"
            }
        }
    }
    
    /// 便捷构造 Attribute
    private static func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }
    
    /// 便捷构造 NSColor
    private static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
    
    /// 根据 preset 生成 EditorTheme
    @MainActor
    static func theme(from preset: PresetTheme) -> EditorTheme {
        switch preset {
        case .xcodeDark: return xcodeDarkTheme()
        case .xcodeLight: return xcodeLightTheme()
        case .midnight: return midnightTheme()
        case .solarizedDark: return solarizedDarkTheme()
        case .solarizedLight: return solarizedLightTheme()
        case .highContrast: return highContrastTheme()
        }
    }
    
    // MARK: - Xcode Dark
    
    @MainActor
    private static func xcodeDarkTheme() -> EditorTheme {
        EditorTheme(
            text: attr(1.0, 1.0, 1.0),
            insertionPoint: color(1.0, 1.0, 1.0),
            invisibles: attr(0.4, 0.4, 0.4),
            background: color(0.116, 0.116, 0.137),
            lineHighlight: color(0.204, 0.216, 0.251),
            selection: color(0.298, 0.349, 0.447, 0.6),
            keywords: attr(1.0, 0.149, 0.373),
            commands: attr(0.784, 0.714, 0.541),
            types: attr(0.259, 0.800, 0.835),
            attributes: attr(0.835, 0.596, 0.918),
            variables: attr(1.0, 1.0, 1.0),
            values: attr(0.784, 0.714, 0.541),
            numbers: attr(1.0, 0.388, 0.282),
            strings: attr(1.0, 0.416, 0.337),
            characters: attr(1.0, 0.416, 0.337),
            comments: attr(0.459, 0.498, 0.545)
        )
    }
    
    // MARK: - Xcode Light
    
    @MainActor
    private static func xcodeLightTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.0, 0.0, 0.0),
            insertionPoint: color(0.0, 0.0, 0.0),
            invisibles: attr(0.85, 0.85, 0.85),
            background: color(1.0, 1.0, 1.0),
            lineHighlight: color(0.12, 0.31, 0.51, 0.06),
            selection: color(0.0, 0.478, 1.0, 0.2),
            keywords: attr(0.702, 0.086, 0.149),
            commands: attr(0.0, 0.0, 0.0),
            types: attr(0.247, 0.0, 0.898),
            attributes: attr(0.298, 0.141, 0.482),
            variables: attr(0.0, 0.0, 0.0),
            values: attr(0.0, 0.0, 0.0),
            numbers: attr(0.373, 0.129, 0.0),
            strings: attr(0.463, 0.01, 0.024),
            characters: attr(0.463, 0.01, 0.024),
            comments: attr(0.271, 0.322, 0.298)
        )
    }
    
    // MARK: - Midnight
    
    @MainActor
    private static func midnightTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.933, 0.933, 0.933),
            insertionPoint: color(0.933, 0.933, 0.933),
            invisibles: attr(0.35, 0.35, 0.35),
            background: color(0.059, 0.059, 0.098),
            lineHighlight: color(0.098, 0.098, 0.157),
            selection: color(0.216, 0.275, 0.392, 0.6),
            keywords: attr(0.624, 0.510, 0.878),
            commands: attr(0.933, 0.933, 0.933),
            types: attr(0.282, 0.769, 0.804),
            attributes: attr(0.867, 0.624, 0.867),
            variables: attr(0.933, 0.933, 0.933),
            values: attr(0.933, 0.933, 0.933),
            numbers: attr(0.867, 0.624, 0.271),
            strings: attr(0.600, 0.800, 0.600),
            characters: attr(0.600, 0.800, 0.600),
            comments: attr(0.400, 0.451, 0.518)
        )
    }
    
    // MARK: - Solarized Dark
    
    @MainActor
    private static func solarizedDarkTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.706, 0.725, 0.702),
            insertionPoint: color(0.706, 0.725, 0.702),
            invisibles: attr(0.298, 0.318, 0.310),
            background: color(0.000, 0.169, 0.212),
            lineHighlight: color(0.039, 0.212, 0.259),
            selection: color(0.078, 0.282, 0.341, 0.6),
            keywords: attr(0.451, 0.565, 0.667),
            commands: attr(0.706, 0.725, 0.702),
            types: attr(0.608, 0.490, 0.388),
            attributes: attr(0.667, 0.482, 0.565),
            variables: attr(0.706, 0.725, 0.702),
            values: attr(0.706, 0.725, 0.702),
            numbers: attr(0.878, 0.569, 0.169),
            strings: attr(0.518, 0.600, 0.259),
            characters: attr(0.518, 0.600, 0.259),
            comments: attr(0.380, 0.447, 0.459)
        )
    }
    
    // MARK: - Solarized Light
    
    @MainActor
    private static func solarizedLightTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.278, 0.294, 0.271),
            insertionPoint: color(0.278, 0.294, 0.271),
            invisibles: attr(0.757, 0.773, 0.753),
            background: color(0.933, 0.910, 0.835),
            lineHighlight: color(0.898, 0.875, 0.800),
            selection: color(0.776, 0.745, 0.663, 0.6),
            keywords: attr(0.298, 0.384, 0.463),
            commands: attr(0.278, 0.294, 0.271),
            types: attr(0.416, 0.337, 0.271),
            attributes: attr(0.463, 0.329, 0.396),
            variables: attr(0.278, 0.294, 0.271),
            values: attr(0.278, 0.294, 0.271),
            numbers: attr(0.529, 0.345, 0.106),
            strings: attr(0.325, 0.388, 0.169),
            characters: attr(0.325, 0.388, 0.169),
            comments: attr(0.612, 0.675, 0.682)
        )
    }
    
    // MARK: - High Contrast
    
    @MainActor
    private static func highContrastTheme() -> EditorTheme {
        EditorTheme(
            text: attr(1.0, 1.0, 1.0),
            insertionPoint: color(1.0, 1.0, 1.0),
            invisibles: attr(0.5, 0.5, 0.5),
            background: color(0.0, 0.0, 0.0),
            lineHighlight: color(0.15, 0.15, 0.15),
            selection: color(0.3, 0.3, 0.5, 0.7),
            keywords: attr(1.0, 0.2, 0.4),
            commands: attr(1.0, 1.0, 1.0),
            types: attr(0.4, 1.0, 0.4),
            attributes: attr(0.9, 0.5, 1.0),
            variables: attr(1.0, 1.0, 1.0),
            values: attr(1.0, 1.0, 1.0),
            numbers: attr(1.0, 0.6, 0.2),
            strings: attr(1.0, 0.9, 0.3),
            characters: attr(1.0, 0.9, 0.3),
            comments: attr(0.6, 0.6, 0.6)
        )
    }
}
