import LumiUI
import SwiftUI

/// `ProjectProviding` 的当前打开文件标签栏。
public struct ProjectFilesTabStripView: View {
    @ObservedObject private var viewModel: ProjectFilesTabViewModel
    @LumiTheme private var theme

    public init(viewModel: ProjectFilesTabViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        AppToolbarContainer(
            height: 40,
            backgroundStyle: .panel,
            padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        ) {
            if viewModel.tabState.fileURLs.isEmpty {
                Text(viewModel.projectIsOpen ? "No files open" : "No project open")
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.tabState.fileURLs, id: \.self) { fileURL in
                            ProjectFilesTabItem(
                                fileURL: fileURL,
                                isActive: fileURL == viewModel.tabState.activeFileURL,
                                onActivate: { viewModel.activate(fileURL) },
                                onClose: { viewModel.close(fileURL) },
                                onCloseOthers: { viewModel.closeOthers(keeping: fileURL) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .borderBottom()
    }
}

private struct ProjectFilesTabItem: View {
    let fileURL: URL
    let isActive: Bool
    let onActivate: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void

    @LumiTheme private var theme

    var body: some View {
        HStack(spacing: 5) {
            Button(action: onActivate) {
                Text(fileURL.lastPathComponent)
                    .font(isActive ? .appMicroEmphasized : .appMicro)
                    .foregroundStyle(isActive ? theme.textPrimary : theme.textSecondary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(minHeight: 28)
        .appSurface(
            style: isActive ? .listRowSelected : .listRow,
            cornerRadius: 7,
            borderColor: isActive ? theme.primary.opacity(0.35) : nil
        )
        .contextMenu {
            Button("Close", action: onClose)
            Button("Close Others", action: onCloseOthers)
        }
    }
}
