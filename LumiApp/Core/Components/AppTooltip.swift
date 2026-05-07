import SwiftUI

// MARK: - AppTooltip

/// 统一的工具提示修饰符
///
/// 为视图添加统一的工具提示样式，替代分散的 .help() 调用。
///
/// ## 使用示例
/// ```swift
/// Image(systemName: "info.circle")
///     .appTooltip("查看更多信息")
///
/// Button("保存") { }
///     .appTooltip("保存当前更改 (⌘S)", shortcut: .keyboardShortcut("s", modifiers: .command))
/// ```
extension View {
    /// 添加统一的工具提示
    func appTooltip(_ text: LocalizedStringKey) -> some View {
        help(text)
    }

    /// 添加带快捷键提示的工具提示
    func appTooltip(_ text: LocalizedStringKey, shortcut: KeyboardShortcut?) -> some View {
        Group {
            if let shortcut {
                let shortcutStr = shortcutText(shortcut)
                // 将 LocalizedStringKey 转换为 Text，然后追加快捷键文本
                let tooltipText = Text(text) + Text(" (\(shortcutStr))")
                help(tooltipText)
            } else {
                help(text)
            }
        }
    }

    /// 将 KeyboardShortcut 转换为可读文本
    private func shortcutText(_ shortcut: KeyboardShortcut) -> String {
        var parts: [String] = []

        if shortcut.modifiers.contains(.command) { parts.append("⌘") }
        if shortcut.modifiers.contains(.option) { parts.append("⌥") }
        if shortcut.modifiers.contains(.control) { parts.append("⌃") }
        if shortcut.modifiers.contains(.shift) { parts.append("⇧") }

        parts.append(shortcut.key)

        return parts.joined()
    }
}

// MARK: - KeyboardShortcut Extension

extension KeyboardShortcut {
    /// 快捷键 key 文本表示
    var key: String {
        switch self {
        case .defaultAction: return "↩"
        case .cancelAction: return "⌘."
        default: return ""
        }
    }
}

// MARK: - Preview

#Preview("AppTooltip") {
    VStack(spacing: 20) {
        Image(systemName: "info.circle")
            .font(.title)
            .appTooltip("查看更多信息")

        Button("保存") { }
            .appTooltip("保存当前更改 (⌘S)")

        Image(systemName: "gearshape")
            .appTooltip("打开设置")
    }
    .padding(50)
    .frame(width: 300, height: 200)
    .background(AppUI.Color.basePalette.deepBackground)
}