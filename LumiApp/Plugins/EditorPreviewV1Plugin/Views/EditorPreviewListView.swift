import LumiPreviewKit
import SwiftUI

/// 编辑器预览列表侧边栏。
///
/// 展示当前文件中所有 #Preview 宏的列表，支持选择切换。
struct EditorPreviewListView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    let previews: [LumiPreviewPackage.PreviewDiscovery]
    let selectedPreviewID: String?
    let onSelectPreview: (String?) -> Void

    var body: some View {
        List(selection: Binding(
            get: { selectedPreviewID },
            set: { onSelectPreview($0) }
        )) {
            ForEach(previews, id: \.id) { preview in
                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(format: String(localized: "Lines %lld-%lld", table: "EditorPreview"), preview.lineNumber, preview.endLineNumber))
                        .font(.system(size: 11))
                        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                }
                .tag(preview.id)
                .padding(.vertical, 3)
            }
        }
        .listStyle(.sidebar)
    }
}
