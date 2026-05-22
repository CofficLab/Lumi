import LumiUI
import SwiftUI

/// 应用详情与相关文件列表
struct AppManagerDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: AppManagerViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let app = viewModel.selectedApp {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 16) {
                        if let icon = app.icon {
                            AppImageThumbnail(
                                image: Image(nsImage: icon),
                                size: CGSize(width: 64, height: 64),
                                shape: .none
                            )
                        } else {
                            Image(systemName: "app.fill")
                                .resizable()
                                .frame(width: 64, height: 64)
                                .foregroundColor(theme.textSecondary)
                        }

                        VStack(alignment: .leading) {
                            Text(app.displayName)
                                .font(.appTitle)
                                .foregroundColor(theme.textPrimary)
                            Text(app.bundleIdentifier ?? String(localized: "Unknown Bundle ID", table: "AppManager"))
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                            Text(app.bundleURL.path)
                                .font(.appMicro)
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding()

                    GlassDivider()

                    // Related Files List
                    if viewModel.isScanningFiles {
                        AppManagerScanningView()
                    } else {
                        List {
                            ForEach(viewModel.relatedFiles) { file in
                                HStack {
                                    Toggle("", isOn: Binding(
                                        get: { viewModel.selectedFileIds.contains(file.id) },
                                        set: { _ in viewModel.toggleFileSelection(file.id) }
                                    ))
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()

                                    VStack(alignment: .leading) {
                                        Text(file.type.displayName)
                                            .font(.appCaption)
                                            .foregroundColor(theme.textSecondary)
                                        Text(file.path)
                                            .font(.appMicro)
                                            .foregroundColor(theme.textPrimary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    Text(formatBytes(file.size))
                                        .font(.appMonoCaption)
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                        }
                    }

                    GlassDivider()

                    // Footer Action
                    HStack {
                        Text(String(localized: "Selected: \(formatBytes(viewModel.totalSelectedSize))", table: "AppManager"))
                            .font(.appBodyEmphasized)
                            .foregroundColor(theme.textPrimary)

                        Spacer()

                        AppButton(localized: "Uninstall Selected", table: "AppManager", style: .destructive, fillsWidth: true, action: { viewModel.showUninstallConfirmation = true })
                        .controlSize(.mini)
                        .disabled(viewModel.selectedFileIds.isEmpty || viewModel.isDeleting)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(String(localized: "Select an App", table: "AppManager"), systemImage: "hand.tap")
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
