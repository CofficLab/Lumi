import SwiftUI
import LumiKernel

/// 编辑器加载状态视图。
///
/// 当文件内容、会话或相关资源仍在准备阶段时显示，用于给编辑区域提供简洁
/// 的加载反馈。
public struct EditorLoadingStateView: View {
    public var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            Text(LumiPluginLocalization.string("Loading...", bundle: .module))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "98989E"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
