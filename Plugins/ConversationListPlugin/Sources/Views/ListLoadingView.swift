import LumiUI
import SwiftUI

/// 对话列表加载视图
/// 用于在加载会话列表时显示加载状态。
public struct ListLoadingView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public init() {}

    public var body: some View {
        ProgressView(LumiPluginLocalization.string("Loading...", bundle: .module))
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }
}

#if DEBUG
    #Preview("对话列表加载视图") {
        ListLoadingView()
            .frame(width: 300, height: 200)
    }
#endif
