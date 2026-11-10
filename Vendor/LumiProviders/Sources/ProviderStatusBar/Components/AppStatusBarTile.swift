import SwiftUI
import LumiUI

/// 状态栏项组件：图标 + 内容的小胶囊，hover 时显示状态栏强调背景和轻微动效。
///
/// 对齐旧版 GitOK 的 `AppStatusBarTile`（24pt 高、8pt 横向 padding、
/// 4pt 圆角、hover 背景），配色使用 LumiUI 主题的 `statusBarItem*` 色板，
/// 保证与状态栏容器视觉一致。
///
/// 该组件原属本地 LumiUI；GitOK 迁移到远程 LumiUI（其不含此组件）后，
/// 移入本包（ProviderStatusBar）作为 GitOK 状态栏专用组件。
public struct AppStatusBarTile<Content: View>: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference

    let systemImage: String?
    let tint: Color?
    let iconSize: CGFloat
    let hoverScale: CGFloat
    let action: (() -> Void)?
    let content: Content

    @State private var isHovered = false

    public init(
        systemImage: String? = nil,
        tint: Color? = nil,
        iconSize: CGFloat = 11,
        hoverScale: CGFloat = 1,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.iconSize = iconSize
        self.hoverScale = hoverScale
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    label
                }
                .buttonStyle(.plain)
            } else {
                label
            }
        }
        .scaleEffect(
            isHovered && motionPreference.allowsMotion
                ? hoverScale
                : 1
        )
        .onHover { hovering in
            LumiMotion.animate(
                LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)
            ) {
                isHovered = hovering
            }
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(tint ?? theme.statusBarItemForeground)
            }

            content
                .font(.footnote)
                .foregroundStyle(tint ?? theme.statusBarItemForeground)
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: height)
        .frame(maxHeight: .infinity, alignment: .center)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(Rectangle())
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isHovered ? theme.statusBarItemBackground : Color.clear)
    }

    var height: CGFloat { 24 }
    var horizontalPadding: CGFloat { 8 }
    var cornerRadius: CGFloat { 4 }
}

public extension AppStatusBarTile where Content == EmptyView {
    init(
        systemImage: String? = nil,
        tint: Color? = nil,
        iconSize: CGFloat = 11,
        hoverScale: CGFloat = 1,
        action: (() -> Void)? = nil
    ) {
        self.init(
            systemImage: systemImage,
            tint: tint,
            iconSize: iconSize,
            hoverScale: hoverScale,
            action: action
        ) {
            EmptyView()
        }
    }
}
