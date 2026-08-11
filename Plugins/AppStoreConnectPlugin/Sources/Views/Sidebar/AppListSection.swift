import LumiUI
import SwiftUI

/// APP 列表组件，用于在 RailView 中内联展示 APP 列表。
struct AppListSection: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                AppSectionLabel(AppStoreConnectLocalization.string("Apps"))

                Spacer()

                AppIconButton(systemImage: "arrow.clockwise") {
                    Task { await viewModel.loadApps() }
                }
                .disabled(viewModel.isBusy || !viewModel.credentials.isComplete)
                .help(AppStoreConnectLocalization.string("Refresh"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // APP 列表
            if viewModel.apps.isEmpty {
                emptyState
            } else {
                appList
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
            LazyVStack(spacing: 2) {
                ForEach(viewModel.apps) { app in
                    AppListRow(
                        isSelected: viewModel.selectedApp?.id == app.id,
                        action: { viewModel.selectApp(app, openDistribution: true) }
                    ) {
                        HStack(spacing: 8) {
                            IconView(url: app.iconURL)
                                .frame(width: 16, height: 16)

                            Text(app.name)
                                .font(.callout)
                                .lineLimit(1)

                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
