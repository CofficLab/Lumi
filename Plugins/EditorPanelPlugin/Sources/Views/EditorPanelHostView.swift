import EditorService
import LumiKernel
import LumiUI
import SwiftUI

/// 编辑器面板宿主视图
///
/// 由 `EditorPanelPlugin.viewContainers` 贡献的容器视图入口。
/// 从内核解析具象 `EditorService` 并注入为 `@EnvironmentObject`,再渲染 `EditorPanelView`。
/// 若 EditorService 未就绪(装配异常),显示降级占位视图。
public struct EditorPanelHostView: View {
    let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        if let editorService = kernel.resolveService(EditorService.self) {
            EditorPanelView(kernel: kernel)
                .environmentObject(editorService)
        } else {
            Text("Editor Service Unavailable")
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
