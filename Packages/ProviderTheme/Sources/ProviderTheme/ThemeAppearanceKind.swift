import Foundation

/// 主题外观类型：固定暗色、固定亮色，或跟随系统明暗。
///
/// 复刻旧版 Lumi（`LumiUI.ThemeAppearanceKind`）的语义：
/// - `.dark`：固定暗色外观
/// - `.light`：固定亮色外观
/// - `.system`：跟随 macOS / iOS 系统外观
public enum ThemeAppearanceKind: String, CaseIterable, Sendable, Identifiable {
    case dark
    case light
    case system

    public var id: String { rawValue }
}
