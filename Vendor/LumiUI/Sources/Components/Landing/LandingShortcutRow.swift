import SwiftUI

/// 一条快捷键数据,供 `LandingShortcutList` 渲染。
public struct LandingShortcut: Identifiable {
    public let id = UUID()
    public let keys: String       // 形如 "⌘T"
    public let description: String

    public init(keys: String, description: String) {
        self.keys = keys
        self.description = description
    }
}

/// 单行快捷键说明:左侧描述 + 右侧等宽字体的按键徽标。
public struct LandingShortcutRow: View {
    @LumiTheme private var theme

    private let shortcut: LandingShortcut

    public init(_ shortcut: LandingShortcut) {
        self.shortcut = shortcut
    }

    public var body: some View {
        HStack {
            Text(shortcut.description)
                .font(.appCaption)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text(shortcut.keys)
                .font(.appMonoCaption)
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.textSecondary.opacity(0.10))
                )
        }
    }
}

/// 快捷键列表:把多条 `LandingShortcut` 收纳进一张卡片,行间以分隔线区隔。
public struct LandingShortcutList: View {
    @LumiTheme private var theme

    private let shortcuts: [LandingShortcut]

    public init(shortcuts: [LandingShortcut]) {
        self.shortcuts = shortcuts
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                LandingShortcutRow(shortcut)
                    .padding(.vertical, 8)
                if index < shortcuts.count - 1 {
                    AppDivider()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.textSecondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.appSubtleBorder, lineWidth: 1)
        )
    }
}

#Preview {
    LandingShortcutList(shortcuts: [
        .init(keys: "⌘T", description: "新建标签页"),
        .init(keys: "⌘W", description: "关闭当前标签页"),
        .init(keys: "⌘1…9", description: "切换到第 N 个标签页")
    ])
    .padding()
    .frame(width: 420)
}
