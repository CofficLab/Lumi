import LumiPreviewKit
import SwiftUI

struct HotPreviewList: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorRemoteHotPreviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.previews.isEmpty {
                Text(String(localized: "No Preview", table: "EditorPreviewRemoteHotPlugin"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(14)
            } else {
                ForEach(viewModel.previews) { preview in
                    Button {
                        viewModel.selectedPreviewID = preview.id
                    } label: {
                        previewRow(preview)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.04))
    }

    private func previewRow(_ preview: LumiPreviewPackage.PreviewDiscovery) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(preview.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
                .lineLimit(1)
            Text(String(localized: "Line \(preview.lineNumber)-\(preview.endLineNumber)", table: "EditorPreviewRemoteHotPlugin"))
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            preview.id == viewModel.selectedPreviewID
                ? themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.16)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}
