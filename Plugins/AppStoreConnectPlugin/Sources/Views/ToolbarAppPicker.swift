import LumiUI
import SwiftUI

public struct ToolbarAppPicker: View {
    @ObservedObject private var viewModel: AppStoreConnectViewModel
    @State private var showingAppPicker = false

    public init() {
        self.viewModel = .shared
    }

    public var body: some View {
        Button {
            showingAppPicker.toggle()
        } label: {
            HStack(spacing: 8) {
                IconView(url: viewModel.selectedApp?.iconURL, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.selectedApp?.name ?? AppStoreConnectLocalization.string("Select App"))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(viewModel.selectedApp?.bundleID ?? AppStoreConnectLocalization.string("Choose an App Store Connect app"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 320)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.credentials.isComplete)
        .popover(isPresented: $showingAppPicker, arrowEdge: .bottom) {
            AppPicker(viewModel: viewModel) {
                showingAppPicker = false
            }
        }
    }
}

struct AppPicker: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            pickerToolbar
            pickerContent
        }
        .padding(12)
        .frame(width: 380)
        .task {
            if viewModel.credentials.isComplete && viewModel.apps.isEmpty {
                await viewModel.loadApps()
            }
        }
    }

    private var pickerToolbar: some View {
        HStack {
            AppSearchBar(text: $viewModel.searchText, placeholder: LocalizedStringKey(AppStoreConnectLocalization.string("Search apps")))

            AppButton(AppStoreConnectLocalization.string("Reload"), systemImage: "arrow.clockwise", size: .small) {
                Task { await viewModel.loadApps() }
            }
            .disabled(viewModel.isBusy)
        }
    }

    @ViewBuilder
    private var pickerContent: some View {
        if viewModel.filteredApps.isEmpty {
            AppEmptyState(
                icon: "square.grid.2x2",
                title: AppStoreConnectLocalization.string("No Apps"),
                description: AppStoreConnectLocalization.string("Load apps from App Store Connect or adjust your search.")
            )
            .frame(height: 180)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.filteredApps) { app in
                        appRow(app)
                    }
                }
            }
            .frame(maxHeight: 360)
        }
    }

    private func appRow(_ app: AppStoreApp) -> some View {
        AppListRow(isSelected: viewModel.selectedApp?.id == app.id, action: {
            viewModel.selectApp(app, openDistribution: true)
            onSelect()
        }) {
            HStack(spacing: 10) {
                IconView(url: app.iconURL, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(app.primaryLocale)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.selectedApp?.id == app.id {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}
