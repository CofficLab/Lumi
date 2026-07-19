import SwiftUI
import LumiKernel

/// 编辑器无内容状态视图。
///
/// 当源码编辑器实例已经进入内容区域，但当前没有可渲染文本时显示，作为
/// 比面板级空态更细粒度的占位反馈。
public struct EditorEmptyContentStateView: View {
    public var body: some View {
        Text(LumiPluginLocalization.string("No content available", bundle: .module))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 预览

#Preview("空内容状态") {
    EditorEmptyStateView()
        .frame(width: 400, height: 300)
}
