import LumiKernel
import LumiUI
import SwiftUI

/// 编辑器面板宿主视图
///
/// 由 `EditorPanelPlugin.viewContainers` 贡献的容器视图入口。
/// 从 `kernel.project`（`ProjectProviding`）解析当前文件，并交给 `CurrentFileContentView` 展示。
public struct EditorPanelHostView: View {
    let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        if let project = kernel.project {
            CurrentFileContentView(project: project)
        } else {
            Text("Project service unavailable")
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
