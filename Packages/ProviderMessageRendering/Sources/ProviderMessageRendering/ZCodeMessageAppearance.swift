import SwiftUI

/// ZCode（V4）消息列表的双主题视觉 token。
///
/// 基准是 ZCode 3.15.1 的 `theme-zai-light` / `theme-zai-dark`
/// （`packages/ui/src/styles.css`），而不是普通 `.dark` fallback。
///
/// - Note: 这些 token 只服务于 V4 呈现，不改变 Lumi 现有的 `LumiTheme`。
public enum ZCodeMessageAppearance {

    /// 一套完整的主题 token。
    public struct Palette: Equatable, Sendable {
        public let background: Color
        public let border: Color
        public let hover: Color
        public let selected: Color
        public let panel: Color
        public let card: Color
        public let popover: Color
        public let surface: Color
        public let foreground: Color
        /// foreground 的 60% 叠加层。
        public let subtle: Color
        /// foreground 的 40%（明亮）/ 30%（暗色）叠加层。
        public let subtlest: Color
        public let destructive: Color
        public let warning: Color
        /// 行内代码的基础底色。
        public let inlineCode: Color
        /// 行内代码以 50% alpha 叠加后的实际呈现色。
        public let inlineCodeOverlay: Color
        public let iconBlue: Color

        public init(
            background: Color,
            border: Color,
            hover: Color,
            selected: Color,
            panel: Color,
            card: Color,
            popover: Color,
            surface: Color,
            foreground: Color,
            subtle: Color,
            subtlest: Color,
            destructive: Color,
            warning: Color,
            inlineCode: Color,
            inlineCodeOverlay: Color,
            iconBlue: Color
        ) {
            self.background = background
            self.border = border
            self.hover = hover
            self.selected = selected
            self.panel = panel
            self.card = card
            self.popover = popover
            self.surface = surface
            self.foreground = foreground
            self.subtle = subtle
            self.subtlest = subtlest
            self.destructive = destructive
            self.warning = warning
            self.inlineCode = inlineCode
            self.inlineCodeOverlay = inlineCodeOverlay
            self.iconBlue = iconBlue
        }
    }

    /// ZCode `theme-zai-light`。
    public static let light = Palette(
        background: Color(red: 0xF8 / 255.0, green: 0xF8 / 255.0, blue: 0xF8 / 255.0),
        border: Color(red: 13 / 255.0, green: 13 / 255.0, blue: 13 / 255.0).opacity(0.10),
        hover: Color(red: 13 / 255.0, green: 13 / 255.0, blue: 13 / 255.0).opacity(0.05),
        selected: Color(red: 13 / 255.0, green: 13 / 255.0, blue: 13 / 255.0).opacity(0.05),
        panel: Color(red: 1.0, green: 1.0, blue: 1.0),
        card: Color(red: 1.0, green: 1.0, blue: 1.0),
        popover: Color(red: 1.0, green: 1.0, blue: 1.0),
        surface: Color(red: 13 / 255.0, green: 13 / 255.0, blue: 13 / 255.0).opacity(0.03),
        foreground: Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0),
        subtle: Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0).opacity(0.60),
        subtlest: Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0).opacity(0.40),
        destructive: Color(red: 0xE0 / 255.0, green: 0x31 / 255.0, blue: 0x31 / 255.0),
        warning: Color(red: 0xE0 / 255.0, green: 0x7B / 255.0, blue: 0x00 / 255.0),
        inlineCode: Color(red: 0xE6 / 255.0, green: 0xE6 / 255.0, blue: 0xE6 / 255.0),
        inlineCodeOverlay: Color(red: 0xE6 / 255.0, green: 0xE6 / 255.0, blue: 0xE6 / 255.0).opacity(0.5),
        iconBlue: Color(red: 0x00 / 255.0, green: 0x66 / 255.0, blue: 0xDD / 255.0)
    )

    /// ZCode `theme-zai-dark`。
    public static let dark = Palette(
        background: Color(red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x16 / 255.0),
        border: Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.10),
        hover: Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.05),
        selected: Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.10),
        panel: Color(red: 0x20 / 255.0, green: 0x20 / 255.0, blue: 0x20 / 255.0),
        card: Color(red: 0x2B / 255.0, green: 0x2B / 255.0, blue: 0x2B / 255.0),
        popover: Color(red: 0x2B / 255.0, green: 0x2B / 255.0, blue: 0x2B / 255.0),
        surface: Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.05),
        foreground: Color(red: 0xD4 / 255.0, green: 0xD4 / 255.0, blue: 0xD4 / 255.0),
        subtle: Color(red: 0xD4 / 255.0, green: 0xD4 / 255.0, blue: 0xD4 / 255.0).opacity(0.60),
        subtlest: Color(red: 0xD4 / 255.0, green: 0xD4 / 255.0, blue: 0xD4 / 255.0).opacity(0.30),
        destructive: Color(red: 0xFF / 255.0, green: 0x5C / 255.0, blue: 0x5C / 255.0),
        warning: Color(red: 0xFF / 255.0, green: 0x8A / 255.0, blue: 0x30 / 255.0),
        inlineCode: Color(red: 0x36 / 255.0, green: 0x36 / 255.0, blue: 0x36 / 255.0),
        inlineCodeOverlay: Color(red: 0x36 / 255.0, green: 0x36 / 255.0, blue: 0x36 / 255.0).opacity(0.5),
        iconBlue: Color(red: 0x80 / 255.0, green: 0xBE / 255.0, blue: 0xFF / 255.0)
    )

    /// 按 SwiftUI 外观解析主题 token。
    public static func palette(for colorScheme: ColorScheme) -> Palette {
        colorScheme == .dark ? dark : light
    }
}
