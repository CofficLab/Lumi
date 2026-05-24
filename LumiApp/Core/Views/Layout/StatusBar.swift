import SwiftUI
import LumiUI
import LumiPluginKit

/// 底部状态栏视图
struct StatusBar: View {
    @EnvironmentObject var pluginProvider: AppPluginVM
    @EnvironmentObject private var themeVM: AppThemeVM
    @EnvironmentObject private var layoutVM: WindowLayoutVM
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM

    /// 当前活跃的供应商 ID（优先对话级偏好，回退到全局选择）
    private var activeProviderId: String? {
        conversationVM.getModelPreference()?.providerId ?? llmVM.selectedProviderId
    }

    var body: some View {
        let context = PluginContext(
            activeIcon: pluginProvider.activePanelIcon,
            isEditorVisible: layoutVM.editorVisible,
            activeProviderId: activeProviderId
        )
        let statusBarLeadingViews = pluginProvider.getStatusBarLeadingViews(context: context)
        let statusBarCenterViews = pluginProvider.getStatusBarCenterViews(context: context)
        let statusBarTrailingViews = pluginProvider.getStatusBarTrailingViews(context: context)
        let hasLeadingViews = !statusBarLeadingViews.isEmpty
        let hasCenterViews = !statusBarCenterViews.isEmpty
        let hasTrailingViews = !statusBarTrailingViews.isEmpty

        return Group {
            if hasLeadingViews || hasCenterViews || hasTrailingViews {
                HStack(spacing: 12) {
                    // 左侧视图
                    if hasLeadingViews {
                        HStack(spacing: 12) {
                            ForEach(statusBarLeadingViews.indices, id: \.self) { index in
                                statusBarLeadingViews[index]
                                    .id("status_bar_leading_\(index)")
                            }
                        }
                    }

                    Spacer()

                    // 中间视图
                    if hasCenterViews {
                        HStack(spacing: 12) {
                            ForEach(statusBarCenterViews.indices, id: \.self) { index in
                                statusBarCenterViews[index]
                                    .id("status_bar_center_\(index)")
                            }
                        }
                    }

                    Spacer()

                    // 右侧视图
                    if hasTrailingViews {
                        HStack(spacing: 12) {
                            ForEach(statusBarTrailingViews.indices, id: \.self) { index in
                                statusBarTrailingViews[index]
                                    .id("status_bar_trailing_\(index)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 32)
                .foregroundColor(statusBarForegroundColor)
                .appSurface(style: .custom(statusBarBackground), cornerRadius: 0)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(statusBarDividerColor)
                        .frame(height: 1)
                }
            }
        }
    }

    private var statusBarBackground: Color {
        let theme = themeVM.activeChromeTheme
        return theme.effectiveIsDarkTheme
            ? theme.atmosphereColors().deep
            : theme.atmosphereColors().medium
    }

    private var statusBarForegroundColor: Color {
        themeVM.activeChromeTheme.workspaceTextColor()
    }

    private var statusBarDividerColor: Color {
        themeVM.activeChromeTheme.workspaceTertiaryTextColor().opacity(0.18)
    }
}
