import AppKit
import SwiftTerm

/// 终端主题适配器
///
/// 从编辑器主题的配色中提取终端所需的颜色，包括：
/// - 前景/背景色
/// - 光标颜色
/// - 选中颜色
/// - ANSI 16 色板（用于 ls --color、git diff 等终端彩色输出）
///
/// 每个预设编辑器主题都对应一组精心调配的终端 ANSI 颜色，
/// 确保终端和编辑器的视觉风格一致。
enum TerminalThemeAdapter {
    // MARK: - Terminal Colors

    /// 终端颜色配置
    struct TerminalColors: @unchecked Sendable {
        let foreground: NSColor
        let background: NSColor
        let cursor: NSColor
        let selection: NSColor
        /// ANSI 16 色板，顺序为：
        /// Black, Red, Green, Yellow, Blue, Magenta, Cyan, White,
        /// BrightBlack, BrightRed, BrightGreen, BrightYellow,
        /// BrightBlue, BrightMagenta, BrightCyan, BrightWhite
        let ansiColors: [SwiftTerm.Color]
    }

    // MARK: - Color Helper

    private static func sc(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func tc(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> SwiftTerm.Color {
        SwiftTerm.Color(
            red: UInt16(min(max(r * 65535, 0), 65535)),
            green: UInt16(min(max(g * 65535, 0), 65535)),
            blue: UInt16(min(max(b * 65535, 0), 65535))
        )
    }

    // MARK: - Theme Mapping

    /// 根据编辑器主题 ID 获取终端颜色
    static func colors(for themeId: String) -> TerminalColors {
        switch themeId {
        case "xcode-dark": return xcodeDarkColors()
        case "xcode-light": return xcodeLightColors()
        case "midnight": return midnightColors()
        case "solarized-dark": return solarizedDarkColors()
        case "solarized-light": return solarizedLightColors()
        case "high-contrast": return highContrastColors()
        case "dracula": return draculaColors()
        case "monokai": return monokaiColors()
        case "one-dark": return oneDarkColors()
        case "github-dark": return githubDarkColors()
        case "nord": return nordColors()
        default: return defaultColors(isDark: true)
        }
    }

    /// 根据系统外观获取默认颜色（不依赖编辑器主题时的 fallback）
    static func defaultColors(isDark: Bool) -> TerminalColors {
        if isDark {
            return TerminalColors(
                foreground: NSColor(white: 0.92, alpha: 1.0),
                background: NSColor(red: 0.116, green: 0.116, blue: 0.137, alpha: 1.0),
                cursor: NSColor(white: 0.92, alpha: 0.7),
                selection: NSColor(red: 0.298, green: 0.349, blue: 0.447, alpha: 0.6),
                ansiColors: xcodeDarkAnsi()
            )
        } else {
            return TerminalColors(
                foreground: NSColor(white: 0.12, alpha: 1.0),
                background: NSColor.white,
                cursor: NSColor(white: 0.12, alpha: 0.7),
                selection: NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 0.2),
                ansiColors: xcodeLightAnsi()
            )
        }
    }

    // MARK: - Apply Colors

    /// 将颜色配置应用到终端视图
    @MainActor
    static func apply(_ colors: TerminalColors, to terminalView: LumiTerminalView) {
        terminalView.nativeForegroundColor = colors.foreground
        terminalView.nativeBackgroundColor = colors.background
        terminalView.caretColor = colors.cursor
        terminalView.caretTextColor = colors.cursor
        terminalView.selectedTextBackgroundColor = colors.selection
        // NSView 层背景设为透明，由 SwiftUI 层统一渲染背景色，
        // 避免 padding 区域与终端内容区域出现两种背景色
        terminalView.layer?.backgroundColor = CGColor.clear

        if colors.ansiColors.count == 16 {
            terminalView.installColors(colors.ansiColors)
        }

        // 强制重绘以应用颜色
        terminalView.getTerminal().softReset()
        terminalView.feed(text: "")
    }

    // MARK: - Xcode Dark

    private static func xcodeDarkColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(1.0, 1.0, 1.0),
            background: sc(0.116, 0.116, 0.137),
            cursor: sc(1.0, 1.0, 1.0, 0.7),
            selection: sc(0.298, 0.349, 0.447, 0.6),
            ansiColors: xcodeDarkAnsi()
        )
    }

    private static func xcodeDarkAnsi() -> [SwiftTerm.Color] {
        // 标准 8 色 + 亮色
        [
            tc(0.000, 0.000, 0.000), // Black
            tc(1.000, 0.267, 0.333), // Red
            tc(0.200, 0.867, 0.600), // Green
            tc(1.000, 0.800, 0.333), // Yellow
            tc(0.333, 0.600, 1.000), // Blue
            tc(0.867, 0.533, 0.933), // Magenta
            tc(0.333, 0.867, 0.933), // Cyan
            tc(0.867, 0.867, 0.867), // White
            tc(0.533, 0.533, 0.533), // Bright Black
            tc(1.000, 0.400, 0.467), // Bright Red
            tc(0.467, 1.000, 0.733), // Bright Green
            tc(1.000, 0.933, 0.533), // Bright Yellow
            tc(0.533, 0.733, 1.000), // Bright Blue
            tc(1.000, 0.667, 1.000), // Bright Magenta
            tc(0.533, 1.000, 1.000), // Bright Cyan
            tc(1.000, 1.000, 1.000), // Bright White
        ]
    }

    // MARK: - Xcode Light

    private static func xcodeLightColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(0.0, 0.0, 0.0),
            background: sc(1.0, 1.0, 1.0),
            cursor: sc(0.0, 0.0, 0.0, 0.7),
            selection: sc(0.0, 0.478, 1.0, 0.2),
            ansiColors: xcodeLightAnsi()
        )
    }

    private static func xcodeLightAnsi() -> [SwiftTerm.Color] {
        [
            tc(0.000, 0.000, 0.000), // Black
            tc(0.800, 0.000, 0.000), // Red
            tc(0.000, 0.600, 0.000), // Green
            tc(0.800, 0.600, 0.000), // Yellow
            tc(0.000, 0.000, 0.800), // Blue
            tc(0.800, 0.000, 0.800), // Magenta
            tc(0.000, 0.800, 0.800), // Cyan
            tc(0.600, 0.600, 0.600), // White
            tc(0.400, 0.400, 0.400), // Bright Black
            tc(1.000, 0.200, 0.200), // Bright Red
            tc(0.200, 0.800, 0.200), // Bright Green
            tc(1.000, 0.800, 0.200), // Bright Yellow
            tc(0.200, 0.200, 1.000), // Bright Blue
            tc(1.000, 0.200, 1.000), // Bright Magenta
            tc(0.200, 1.000, 1.000), // Bright Cyan
            tc(0.933, 0.933, 0.933), // Bright White
        ]
    }

    // MARK: - Midnight

    private static func midnightColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(0.933, 0.933, 0.933),
            background: sc(0.059, 0.059, 0.098),
            cursor: sc(0.933, 0.933, 0.933, 0.7),
            selection: sc(0.216, 0.275, 0.392, 0.6),
            ansiColors: [
                tc(0.050, 0.050, 0.100), // Black
                tc(0.867, 0.333, 0.333), // Red
                tc(0.333, 0.867, 0.467), // Green
                tc(0.867, 0.800, 0.333), // Yellow
                tc(0.400, 0.533, 0.867), // Blue
                tc(0.800, 0.467, 0.867), // Magenta
                tc(0.333, 0.800, 0.867), // Cyan
                tc(0.800, 0.800, 0.800), // White
                tc(0.400, 0.400, 0.467), // Bright Black
                tc(1.000, 0.467, 0.467), // Bright Red
                tc(0.467, 1.000, 0.600), // Bright Green
                tc(1.000, 0.933, 0.467), // Bright Yellow
                tc(0.533, 0.667, 1.000), // Bright Blue
                tc(1.000, 0.600, 1.000), // Bright Magenta
                tc(0.467, 1.000, 1.000), // Bright Cyan
                tc(1.000, 1.000, 1.000), // Bright White
            ]
        )
    }

    // MARK: - Solarized Dark

    private static func solarizedDarkColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(0.706, 0.725, 0.702),
            background: sc(0.000, 0.169, 0.212),
            cursor: sc(0.706, 0.725, 0.702, 0.7),
            selection: sc(0.078, 0.282, 0.341, 0.6),
            ansiColors: solarizedAnsi()
        )
    }

    // MARK: - Solarized Light

    private static func solarizedLightColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(0.278, 0.294, 0.271),
            background: sc(0.933, 0.910, 0.835),
            cursor: sc(0.278, 0.294, 0.271, 0.7),
            selection: sc(0.776, 0.745, 0.663, 0.6),
            ansiColors: solarizedAnsi()
        )
    }

    /// Solarized 的 ANSI 色板是统一的
    private static func solarizedAnsi() -> [SwiftTerm.Color] {
        [
            tc(0.027, 0.212, 0.259), // Base02 (Black)
            tc(0.827, 0.110, 0.149), // Red
            tc(0.522, 0.600, 0.000), // Green
            tc(0.706, 0.545, 0.000), // Yellow
            tc(0.149, 0.545, 0.824), // Blue
            tc(0.827, 0.212, 0.510), // Magenta
            tc(0.165, 0.600, 0.600), // Cyan
            tc(0.933, 0.910, 0.835), // Base2 (White)
            tc(0.000, 0.169, 0.212), // Base03 (Bright Black)
            tc(0.827, 0.110, 0.149), // Bright Red
            tc(0.522, 0.600, 0.000), // Bright Green
            tc(0.706, 0.545, 0.000), // Bright Yellow
            tc(0.149, 0.545, 0.824), // Bright Blue
            tc(0.827, 0.212, 0.510), // Bright Magenta
            tc(0.165, 0.600, 0.600), // Bright Cyan
            tc(0.996, 0.965, 0.886), // Base3 (Bright White)
        ]
    }

    // MARK: - High Contrast

    private static func highContrastColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(1.0, 1.0, 1.0),
            background: sc(0.0, 0.0, 0.0),
            cursor: sc(1.0, 1.0, 1.0, 0.9),
            selection: sc(0.3, 0.3, 0.5, 0.7),
            ansiColors: [
                tc(0.200, 0.200, 0.200), // Black
                tc(1.000, 0.333, 0.333), // Red
                tc(0.333, 1.000, 0.333), // Green
                tc(1.000, 1.000, 0.333), // Yellow
                tc(0.333, 0.533, 1.000), // Blue
                tc(1.000, 0.333, 1.000), // Magenta
                tc(0.333, 1.000, 1.000), // Cyan
                tc(0.867, 0.867, 0.867), // White
                tc(0.467, 0.467, 0.467), // Bright Black
                tc(1.000, 0.467, 0.467), // Bright Red
                tc(0.467, 1.000, 0.467), // Bright Green
                tc(1.000, 1.000, 0.467), // Bright Yellow
                tc(0.467, 0.667, 1.000), // Bright Blue
                tc(1.000, 0.467, 1.000), // Bright Magenta
                tc(0.467, 1.000, 1.000), // Bright Cyan
                tc(1.000, 1.000, 1.000), // Bright White
            ]
        )
    }

    // MARK: - Dracula

    private static func draculaColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(0.973, 0.973, 0.949),
            background: sc(0.157, 0.165, 0.212),
            cursor: sc(0.973, 0.973, 0.949, 0.7),
            selection: sc(0.267, 0.278, 0.353, 0.6),
            ansiColors: [
                tc(0.129, 0.133, 0.173), // Black
                tc(1.000, 0.333, 0.333), // Red
                tc(0.314, 0.980, 0.482), // Green
                tc(0.945, 0.980, 0.549), // Yellow
                tc(0.741, 0.576, 0.976), // Blue
                tc(1.000, 0.475, 0.776), // Magenta
                tc(0.545, 0.914, 0.992), // Cyan
                tc(0.973, 0.973, 0.949), // White
                tc(0.384, 0.447, 0.643), // Bright Black
                tc(1.000, 0.431, 0.431), // Bright Red
                tc(0.412, 1.000, 0.580), // Bright Green
                tc(1.000, 1.000, 0.647), // Bright Yellow
                tc(0.839, 0.674, 1.000), // Bright Blue
                tc(1.000, 0.573, 0.875), // Bright Magenta
                tc(0.643, 1.000, 1.000), // Bright Cyan
                tc(1.000, 1.000, 1.000), // Bright White
            ]
        )
    }

    // MARK: - Monokai

    private static func monokaiColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(0.969, 0.969, 0.890),
            background: sc(0.149, 0.157, 0.133),
            cursor: sc(0.969, 0.969, 0.890, 0.7),
            selection: sc(0.380, 0.380, 0.380, 0.5),
            ansiColors: [
                tc(0.149, 0.157, 0.133), // Black
                tc(0.973, 0.282, 0.545), // Red
                tc(0.565, 0.835, 0.259), // Green
                tc(0.898, 0.639, 0.310), // Yellow
                tc(0.545, 0.596, 0.827), // Blue
                tc(0.973, 0.282, 0.545), // Magenta
                tc(0.400, 0.812, 0.843), // Cyan
                tc(0.969, 0.969, 0.890), // White
                tc(0.459, 0.447, 0.380), // Bright Black
                tc(1.000, 0.400, 0.620), // Bright Red
                tc(0.678, 0.900, 0.357), // Bright Green
                tc(0.961, 0.733, 0.388), // Bright Yellow
                tc(0.631, 0.678, 0.902), // Bright Blue
                tc(1.000, 0.400, 0.620), // Bright Magenta
                tc(0.502, 0.886, 0.922), // Bright Cyan
                tc(1.000, 1.000, 0.949), // Bright White
            ]
        )
    }

    // MARK: - One Dark

    private static func oneDarkColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(0.655, 0.690, 0.757),
            background: sc(0.180, 0.200, 0.247),
            cursor: sc(0.655, 0.690, 0.757, 0.7),
            selection: sc(0.310, 0.337, 0.400, 0.5),
            ansiColors: [
                tc(0.180, 0.200, 0.247), // Black
                tc(0.863, 0.475, 0.620), // Red
                tc(0.612, 0.812, 0.412), // Green
                tc(0.878, 0.776, 0.424), // Yellow
                tc(0.439, 0.627, 0.816), // Blue
                tc(0.706, 0.545, 0.855), // Magenta
                tc(0.400, 0.780, 0.816), // Cyan
                tc(0.655, 0.690, 0.757), // White
                tc(0.376, 0.412, 0.486), // Bright Black
                tc(0.933, 0.576, 0.722), // Bright Red
                tc(0.722, 0.890, 0.522), // Bright Green
                tc(0.953, 0.855, 0.506), // Bright Yellow
                tc(0.545, 0.722, 0.898), // Bright Blue
                tc(0.800, 0.643, 0.933), // Bright Magenta
                tc(0.502, 0.855, 0.886), // Bright Cyan
                tc(0.780, 0.816, 0.886), // Bright White
            ]
        )
    }

    // MARK: - GitHub Dark

    private static func githubDarkColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(0.831, 0.878, 0.922),
            background: sc(0.106, 0.110, 0.141),
            cursor: sc(0.831, 0.878, 0.922, 0.7),
            selection: sc(0.259, 0.286, 0.349, 0.5),
            ansiColors: [
                tc(0.106, 0.110, 0.141), // Black
                tc(1.000, 0.533, 0.388), // Red
                tc(0.580, 0.878, 0.451), // Green
                tc(0.933, 0.847, 0.353), // Yellow
                tc(0.545, 0.773, 0.922), // Blue
                tc(0.827, 0.624, 0.898), // Magenta
                tc(0.451, 0.859, 0.878), // Cyan
                tc(0.831, 0.878, 0.922), // White
                tc(0.310, 0.357, 0.408), // Bright Black
                tc(1.000, 0.627, 0.490), // Bright Red
                tc(0.690, 0.933, 0.565), // Bright Green
                tc(1.000, 0.922, 0.447), // Bright Yellow
                tc(0.651, 0.859, 1.000), // Bright Blue
                tc(0.933, 0.737, 1.000), // Bright Magenta
                tc(0.557, 0.933, 0.957), // Bright Cyan
                tc(0.953, 0.973, 1.000), // Bright White
            ]
        )
    }

    // MARK: - Nord

    private static func nordColors() -> TerminalColors {
        TerminalColors(
            foreground: sc(0.780, 0.816, 0.886),
            background: sc(0.133, 0.157, 0.204),
            cursor: sc(0.780, 0.816, 0.886, 0.7),
            selection: sc(0.275, 0.310, 0.384, 0.5),
            ansiColors: [
                tc(0.133, 0.157, 0.204), // Black
                tc(0.749, 0.380, 0.412), // Red
                tc(0.639, 0.843, 0.525), // Green
                tc(0.878, 0.776, 0.424), // Yellow
                tc(0.545, 0.722, 0.898), // Blue
                tc(0.890, 0.545, 0.698), // Magenta
                tc(0.451, 0.800, 0.800), // Cyan
                tc(0.780, 0.816, 0.886), // White
                tc(0.318, 0.357, 0.439), // Bright Black
                tc(0.859, 0.475, 0.506), // Bright Red
                tc(0.749, 0.922, 0.620), // Bright Green
                tc(0.957, 0.875, 0.522), // Bright Yellow
                tc(0.631, 0.800, 0.957), // Bright Blue
                tc(0.969, 0.647, 0.804), // Bright Magenta
                tc(0.549, 0.890, 0.890), // Bright Cyan
                tc(0.867, 0.898, 0.945), // Bright White
            ]
        )
    }
}
