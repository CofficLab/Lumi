import MagicKit
import SwiftUI

/// Editor root overlay
struct EditorRootOverlay<Content: View>: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM

    let content: Content

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: projectVM.selectedFileURL) {
            guard projectVM.selectedFileURL != nil else { return }
            // 有文件被选中时，激活代码编辑器 Detail
            layoutVM.selectAgentDetail(EditorPlugin.id)
        }
    }
}
