import SwiftUI

/// 中间栏视图：Agent 模式显示插件提供的 detail 视图，App 模式为空
struct MiddleColumn: View {
    @EnvironmentObject var app: GlobalVM
    @EnvironmentObject var pluginProvider: PluginVM

    var body: some View {
        Group {
            if app.selectedMode == .agent {
                agentDetailContent
            } else {
                appModeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var agentDetailContent: some View {
        let detailViews = pluginProvider.getDetailViews()
        if detailViews.isEmpty {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // 直接返回第一个 detail view（目前只有一个 FilePreviewPlugin）
            detailViews[0]
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 200, idealWidth: 300)
        }
    }

    @ViewBuilder
    private var appModeContent: some View {
        if app.hasCurrentNavigationContent(pluginVM: pluginProvider) {
            app.getCurrentNavigationView(pluginVM: pluginProvider)
        } else {
            NavigationEmptyGuideView()
        }
    }
}