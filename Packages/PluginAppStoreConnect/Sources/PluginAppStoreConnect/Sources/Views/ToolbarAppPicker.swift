import LumiUI
import SwiftUI

public struct ToolbarAppPicker: View {
    @ObservedObject private var viewModel: VM
    @State private var showingAppPicker = false

    public init() {
        self.viewModel = .shared
    }

    public var body: some View {
        Button {
            showingAppPicker.toggle()
        } label: {
            HStack(spacing: 6) {
                IconView(url: viewModel.selectedApp?.iconURL, size: 18)

                Text(viewModel.selectedApp?.name ?? AppStoreConnectLocalization.string("Select App"))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 180)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .rotationEffect(.degrees(showingAppPicker ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.primary.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .disabled(!viewModel.credentials.isComplete)
        .popover(isPresented: $showingAppPicker, arrowEdge: .bottom) {
            AppPicker(viewModel: viewModel) {
                showingAppPicker = false
            }
        }
    }
}

struct AppPicker: View {
    @ObservedObject var viewModel: VM
    let onSelect: () -> Void

    @State private var isReloading = false

    var body: some View {
        VStack(spacing: 8) {
            pickerToolbar
            pickerContent
        }
        .padding(12)
        .frame(width: 320)
        .overlay {
            if isReloading {
                ZStack {
                    Rectangle()
                        .fill(.regularMaterial)
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.regular)
                        Text(AppStoreConnectLocalization.string("Loading..."))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
            }
        }
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
                Task {
                    isReloading = true
                    let start = Date()
                    await viewModel.loadApps()
                    let elapsed = Date().timeIntervalSince(start)
                    if elapsed < 1.0 {
                        try? await Task.sleep(nanoseconds: UInt64((1.0 - elapsed) * 1_000_000_000))
                    }
                    isReloading = false
                }
            }
            .disabled(isReloading)
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
                IconView(url: app.iconURL, size: 20)

                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if viewModel.selectedApp?.id == app.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}
