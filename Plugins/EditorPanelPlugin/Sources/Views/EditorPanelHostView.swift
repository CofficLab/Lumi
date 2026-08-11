import LumiKernel
import LumiUI
import SwiftUI

/// 编辑器面板宿主视图
///
/// 由 `EditorPanelPlugin.viewContainers` 贡献的容器视图入口。
/// 通过内核解析 `EditorProviding`，调用其 `makeEditorView()` 展示真正的编辑器视图；
/// 服务未就绪时显示降级占位。当前文件由编辑器实现内部跟踪，本视图不直接读取文件。
public struct EditorPanelHostView: View {
    let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        if let editorProvider = kernel.editorProvider {
            editorProvider.makeEditorView()
        } else {
            Text(LumiPluginLocalization.string("Editor service unavailable", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
