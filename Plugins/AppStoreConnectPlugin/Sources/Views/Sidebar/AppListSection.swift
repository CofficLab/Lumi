import LumiUI
import SwiftUI

/// APP 列表组件，用于在 RailView 中内联展示 APP 列表。
struct AppListSection: View {
    @ObservedObject var viewModel: VM
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                AppSectionLabel(AppStoreConnectLocalization.string("Apps"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }

                Spacer()

                AppIconButton(systemImage: "arrow.clockwise") {
                    Task { await viewModel.loadApps() }
                }
                .disabled(viewModel.isBusy || !viewModel.credentials.isComplete)
                .help(AppStoreConnectLocalization.string("Refresh"))
            }
            .contentShape(Rectangle())

            // APP 列表
            if isExpanded {
                if viewModel.apps.isEmpty {
                    emptyState
                } else {
                    appList
                }
            }
        }
        .task {
            if viewModel.apps.isEmpty, viewModel.credentials.isComplete {
                await viewModel.loadApps(silent: true)
            }
        }
    }

    private var emptyState: some View {
        Text(viewModel.credentials.isComplete
            ? AppStoreConnectLocalization.string("No Apps")
            : AppStoreConnectLocalization.string("Configure credentials first"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    private var appList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.apps) { app in
                    AppListItemRow(
                        app: app,
                        isSelected: viewModel.selectedApp?.id == app.id
                    ) {
                        viewModel.selectApp(app, openDistribution: true)
                    }
                }
            }
        }
    }
}

/// 单个 APP 列表项
struct AppListItemRow: View {
    let app: AppStoreApp
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                IconView(url: app.iconURL)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.callout)
                        .lineLimit(1)
                    Text(app.bundleID)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
