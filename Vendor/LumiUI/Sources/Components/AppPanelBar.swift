import SwiftUI

/// 面板内的紧凑信息栏，用于编辑器与聊天分区中的面包屑/工具栏行。
///
/// 固定为 `AppPanelChromeMetrics.breadcrumbBarHeight` 高度、`.panel` 表面背景、
/// 底部边框与 `md` 阴影，并保持内容在 `breadcrumbContentHeight` 行高内垂直居中，
/// 使同一窗口里相邻的多个面板栏高度、内边距和分隔线完全一致。
///
/// 与 `AppToolbarContainer` 的分工：`AppToolbarContainer` 只提供尺寸与表面，
/// 装饰（边框、阴影）由调用方各自追加；本组件把面板栏这套完整胶囊样式收敛为单一
/// 来源，避免每处调用重复声明同一组参数。
///
/// ```swift
/// AppPanelBar {
///     HStack(spacing: AppPanelChromeMetrics.breadcrumbItemSpacing) {
///         Image(systemName: "tray.full.fill")
///         Text("所有项目的对话")
///         Spacer(minLength: 0)
///     }
/// }
/// ```
public struct AppPanelBar<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    /// 栏整体高度（含上下内边距）。
    var height: CGFloat { AppPanelChromeMetrics.breadcrumbBarHeight }

    /// 内容可用行高：超出部分会被裁切，与相邻面板栏对齐。
    var contentHeight: CGFloat { AppPanelChromeMetrics.breadcrumbContentHeight }

    /// 与聊天工具栏一致的内边距（上下 4、左右 10）。
    var padding: EdgeInsets {
        EdgeInsets(
            top: AppPanelChromeMetrics.breadcrumbVerticalPadding,
            leading: AppPanelChromeMetrics.breadcrumbHorizontalPadding,
            bottom: AppPanelChromeMetrics.breadcrumbVerticalPadding,
            trailing: AppPanelChromeMetrics.breadcrumbHorizontalPadding
        )
    }

    public var body: some View {
        AppToolbarContainer(
            height: height,
            backgroundStyle: .panel,
            padding: padding
        ) {
            content()
                .frame(height: contentHeight, alignment: .center)
        }
        .borderBottom()
        .shadowMd()
    }
}

#Preview {
    VStack(spacing: 12) {
        AppPanelBar {
            HStack(spacing: AppPanelChromeMetrics.breadcrumbItemSpacing) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(LumiUILocalization.string("Projects"))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }

        AppPanelBar {
            HStack(spacing: AppPanelChromeMetrics.breadcrumbItemSpacing) {
                Text(LumiUILocalization.string("Status"))
                    .font(.appCaption)
                Spacer(minLength: 0)
                Text(LumiUILocalization.string("Model"))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding(.vertical)
    .background(Color.gray.opacity(0.15))
}
