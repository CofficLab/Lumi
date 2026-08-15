import KernelLumi
import LumiUI
import SwiftUI

/// 编辑器面板宿主视图
///
/// 由 `EditorPanelPlugin.viewContainers` 贡献的容器视图入口。
/// 通过内核 V2 契约解析 `kernel.editorV2.surface`，调用其 `makeEditorView()`
/// 展示 Host 组装的标准编辑器 Surface；Host 未就绪时回退 legacy
/// `EditorProviding` 契约，仍不可用则显示降级占位。
/// 本视图不依赖 EditorService，当前文件由编辑器实现内部跟踪。
public struct EditorPanelHostView: View {
    let kernel: KernelLumi

    public init(kernel: KernelLumi) {
        self.kernel = kernel
    }

    public var body: some View {
        if let surface = kernel.editorV2?.surface {
            surface.makeEditorView()
        } else if let editorProvider = kernel.editorProvider {
            // 迁移期回退：V2 Host 未注册（如测试宿主）时走 legacy 契约。
            editorProvider.makeEditorView()
        } else {
            Text(LumiPluginLocalization.string("Editor service unavailable", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
