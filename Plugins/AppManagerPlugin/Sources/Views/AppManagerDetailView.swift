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
                    AppCard(style: .subtle, cornerRadius: 12, padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
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
                                AppIdentityRow(
                                    title: app.bundleIdentifier ?? PluginAppManagerLocalization.string("Unknown Bundle ID"),
                                    metadata: [app.version ?? ""],
                                    metadataColor: theme.textSecondary
                                )
                                Text(app.bundleURL.path)
                                    .font(.appMicro)
                                    .foregroundColor(theme.textSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }

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
                                        AppTag(file.type.displayName)

                                        Text(file.path)
                                            .font(.appMicro)
                                            .foregroundColor(theme.textPrimary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    AppSizeLabel(bytes: file.size)
                                }
                            }
                        }
                    }

                    GlassDivider()

                    // Footer Action
                    HStack {
                        Text(PluginAppManagerLocalization.format("Selected: %@", ByteCountFormatter.string(fromByteCount: viewModel.totalSelectedSize, countStyle: .file)))
                            .font(.appBodyEmphasized)
                            .foregroundColor(theme.textPrimary)

                        Spacer()

                        AppButton(PluginAppManagerLocalization.string("Uninstall Selected"), style: .destructive, size: .small, action: { viewModel.showUninstallConfirmation = true })
                            .disabled(viewModel.selectedFileIds.isEmpty || viewModel.isDeleting)
                    }
                    .padding()
                }
            } else {
                AppEmptyState(
                    icon: "hand.tap",
                    title: PluginAppManagerLocalization.string("Select an App")
                )
            }
        }
        .alert(PluginAppManagerLocalization.string("Confirm Uninstall"), isPresented: $viewModel.showUninstallConfirmation) {
            Button(PluginAppManagerLocalization.string("Cancel"), role: .cancel) { }
            Button(PluginAppManagerLocalization.string("Uninstall"), role: .destructive) {
                viewModel.deleteSelectedFiles()
            }
        } message: {
            Text(PluginAppManagerLocalization.string("Are you sure you want to delete the selected files? This action cannot be undone."))
        }
    }
}
