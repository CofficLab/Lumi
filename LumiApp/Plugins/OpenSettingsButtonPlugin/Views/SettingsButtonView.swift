import SwiftUI
import OSLog

/// 设置按钮视图（状态栏左侧）
struct SettingsButtonView: View {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.settings-button.view")

    // MARK: - Constants

    private let iconSize: CGFloat = 12

    // MARK: - Body

    var body: some View {
        StatusBarHoverContainer(
            detailView: SettingsDetailView(),
            id: "settings-status"
        ) {
            Button(action: {
                openSettings()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: iconSize))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help("打开设置")
        }
    }

    // MARK: - Actions

    /// 打开设置窗口
    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

// MARK: - Detail View

/// 设置详情视图（在 popover 中显示）
struct SettingsDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))

                Text("设置")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                Button(action: {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("打开")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 快捷键提示
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("快捷键")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                HStack(spacing: DesignTokens.Spacing.md) {
                    KeyboardShortcutBadge(keys: ["⌘", ","])
                    Text("打开设置")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }
            }
        }
        .padding()
        .frame(width: 280)
    }
}

/// 键盘快捷键徽章
struct KeyboardShortcutBadge: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
        }
    }
}

// MARK: - Preview

#Preview("Settings Button") {
    HStack(spacing: 8) {
        SettingsButtonView()
        Spacer()
    }
    .frame(height: 40)
    .background(Color.gray.opacity(0.1))
}

#Preview("Settings Button - Dark Mode") {
    HStack(spacing: 8) {
        SettingsButtonView()
        Spacer()
    }
    .frame(height: 40)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
