import SwiftUI

/// 中间栏视图：Agent 模式显示插件提供的 detail 视图，App 模式为空
struct MiddleColumn: View {
    @EnvironmentObject var app: GlobalVM
    @EnvironmentObject var pluginProvider: PluginVM

    var body: some View {
        Group {
            if app.selectedMode == .agent {
                let detailViews = pluginProvider.getDetailViews()
                if detailViews.isEmpty {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(detailViews.indices, id: \.self) { index in
                            detailViews[index]
                                .id("detail_\(index)")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: 200, idealWidth: 300)
                }
            } else {
                // App 模式：中间栏承载当前导航内容
                VStack(spacing: 0) {
                    app.getCurrentNavigationView(pluginVM: pluginProvider)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
