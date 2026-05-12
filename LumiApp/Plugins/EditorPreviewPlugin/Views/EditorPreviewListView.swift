#if canImport(LumiPreviewKit)
import LumiPreviewKit
import SwiftUI

struct EditorPreviewListView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    let previews: [PreviewDiscovery]
    @Binding var selectedPreviewID: String?

    var body: some View {
        List(selection: $selectedPreviewID) {
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
#endif
