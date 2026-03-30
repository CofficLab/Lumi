import SwiftUI
import OSLog

/// 设置按钮视图（状态栏左侧）
struct SettingsButtonView: View {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.settings-button.view")

    // MARK: - State

    @State private var isHovering = false

    // MARK: - Constants

    private let iconSize: CGFloat = 12
    private let textFontSize: CGFloat = 12
    private let horizontalPadding: CGFloat = 10
    private let verticalPadding: CGFloat = 5
    private let cornerRadius: CGFloat = 6

    // MARK: - Body

    var body: some View {
        Button(action: {
            openSettings()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundView)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .appTooltip("打开设置")
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isHovering {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.08))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.clear)
        }
    }

    // MARK: - Actions

    /// 打开设置窗口
    private func openSettings() {
        logger.debug("用户点击设置按钮，打开设置窗口")
        NotificationCenter.default.post(name: .openSettings, object: nil)
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
