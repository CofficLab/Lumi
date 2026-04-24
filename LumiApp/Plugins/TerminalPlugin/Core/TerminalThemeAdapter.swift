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
        case "xcode-dark":       return xcodeDarkColors()
        case "xcode-light":      return xcodeLightColors()
        case "midnight":         return midnightColors()
        case "solarized-dark":   return solarizedDarkColors()
        case "solarized-light":  return solarizedLightColors()
        case "high-contrast":    return highContrastColors()
        default:                 return defaultColors(isDark: true)
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
            tc(0.000, 0.000, 0.000),  // Black
            tc(1.000, 0.267, 0.333),  // Red
            tc(0.200, 0.867, 0.600),  // Green
            tc(1.000, 0.800, 0.333),  // Yellow
            tc(0.333, 0.600, 1.000),  // Blue
            tc(0.867, 0.533, 0.933),  // Magenta
            tc(0.333, 0.867, 0.933),  // Cyan
            tc(0.867, 0.867, 0.867),  // White
            tc(0.533, 0.533, 0.533),  // Bright Black
            tc(1.000, 0.400, 0.467),  // Bright Red
            tc(0.467, 1.000, 0.733),  // Bright Green
            tc(1.000, 0.933, 0.533),  // Bright Yellow
            tc(0.533, 0.733, 1.000),  // Bright Blue
            tc(1.000, 0.667, 1.000),  // Bright Magenta
            tc(0.533, 1.000, 1.000),  // Bright Cyan
            tc(1.000, 1.000, 1.000),  // Bright White
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
            tc(0.000, 0.000, 0.000),  // Black
            tc(0.800, 0.000, 0.000),  // Red
            tc(0.000, 0.600, 0.000),  // Green
            tc(0.800, 0.600, 0.000),  // Yellow
            tc(0.000, 0.000, 0.800),  // Blue
            tc(0.800, 0.000, 0.800),  // Magenta
            tc(0.000, 0.800, 0.800),  // Cyan
            tc(0.600, 0.600, 0.600),  // White
            tc(0.400, 0.400, 0.400),  // Bright Black
            tc(1.000, 0.200, 0.200),  // Bright Red
            tc(0.200, 0.800, 0.200),  // Bright Green
            tc(1.000, 0.800, 0.200),  // Bright Yellow
            tc(0.200, 0.200, 1.000),  // Bright Blue
            tc(1.000, 0.200, 1.000),  // Bright Magenta
            tc(0.200, 1.000, 1.000),  // Bright Cyan
            tc(0.933, 0.933, 0.933),  // Bright White
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
                tc(0.050, 0.050, 0.100),  // Black
                tc(0.867, 0.333, 0.333),  // Red
                tc(0.333, 0.867, 0.467),  // Green
                tc(0.867, 0.800, 0.333),  // Yellow
                tc(0.400, 0.533, 0.867),  // Blue
                tc(0.800, 0.467, 0.867),  // Magenta
                tc(0.333, 0.800, 0.867),  // Cyan
                tc(0.800, 0.800, 0.800),  // White
                tc(0.400, 0.400, 0.467),  // Bright Black
                tc(1.000, 0.467, 0.467),  // Bright Red
                tc(0.467, 1.000, 0.600),  // Bright Green
                tc(1.000, 0.933, 0.467),  // Bright Yellow
                tc(0.533, 0.667, 1.000),  // Bright Blue
                tc(1.000, 0.600, 1.000),  // Bright Magenta
                tc(0.467, 1.000, 1.000),  // Bright Cyan
                tc(1.000, 1.000, 1.000),  // Bright White
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
            tc(0.027, 0.212, 0.259),  // Base02 (Black)
            tc(0.827, 0.110, 0.149),  // Red
            tc(0.522, 0.600, 0.000),  // Green
            tc(0.706, 0.545, 0.000),  // Yellow
            tc(0.149, 0.545, 0.824),  // Blue
            tc(0.827, 0.212, 0.510),  // Magenta
            tc(0.165, 0.600, 0.600),  // Cyan
            tc(0.933, 0.910, 0.835),  // Base2 (White)
            tc(0.000, 0.169, 0.212),  // Base03 (Bright Black)
            tc(0.827, 0.110, 0.149),  // Bright Red
            tc(0.522, 0.600, 0.000),  // Bright Green
            tc(0.706, 0.545, 0.000),  // Bright Yellow
            tc(0.149, 0.545, 0.824),  // Bright Blue
            tc(0.827, 0.212, 0.510),  // Bright Magenta
            tc(0.165, 0.600, 0.600),  // Bright Cyan
            tc(0.996, 0.965, 0.886),  // Base3 (Bright White)
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
                tc(0.200, 0.200, 0.200),  // Black
                tc(1.000, 0.333, 0.333),  // Red
                tc(0.333, 1.000, 0.333),  // Green
                tc(1.000, 1.000, 0.333),  // Yellow
                tc(0.333, 0.533, 1.000),  // Blue
                tc(1.000, 0.333, 1.000),  // Magenta
                tc(0.333, 1.000, 1.000),  // Cyan
                tc(0.867, 0.867, 0.867),  // White
                tc(0.467, 0.467, 0.467),  // Bright Black
                tc(1.000, 0.467, 0.467),  // Bright Red
                tc(0.467, 1.000, 0.467),  // Bright Green
                tc(1.000, 1.000, 0.467),  // Bright Yellow
                tc(0.467, 0.667, 1.000),  // Bright Blue
                tc(1.000, 0.467, 1.000),  // Bright Magenta
                tc(0.467, 1.000, 1.000),  // Bright Cyan
                tc(1.000, 1.000, 1.000),  // Bright White
            ]
        )
    }
}
