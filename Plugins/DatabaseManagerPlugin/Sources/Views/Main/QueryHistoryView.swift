import SwiftUI
import LumiUI
import KernelLumi

/// 查询历史面板：搜索 + 列表 + 点击载入编辑器。
///
/// 通过 ``DatabaseViewModel/showHistory`` 控制显示。
struct QueryHistoryView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @ObservedObject var viewModel: DatabaseViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchField
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            Divider()
            if viewModel.history.isEmpty {
                AppEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: LumiPluginLocalization.string("No history", bundle: .module),
                    description: LumiPluginLocalization.string("Executed queries will appear here.", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.history) { entry in
                            HistoryRow(entry: entry) {
                                viewModel.loadHistoryEntry(entry)
                            } onDelete: {
                                Task { await viewModel.deleteHistoryEntry(entry) }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            footer
        }
        .frame(width: 480, height: 520)
        .onAppear { Task { await viewModel.loadRecentHistory() } }
    }

    private var header: some View {
        HStack {
            Text(LumiPluginLocalization.string("Query History", bundle: .module))
                .font(.appBodyEmphasized)
                .foregroundColor(theme.textPrimary)
            Spacer()
            AppButton(LumiPluginLocalization.string("Close", bundle: .module), style: .ghost, size: .small) {
                viewModel.showHistory = false
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField(LumiPluginLocalization.string("Search history", bundle: .module), text: $viewModel.historySearchText)
                .textFieldStyle(.plain)
                .font(.appCaption)
            if !viewModel.historySearchText.isEmpty {
                Button {
                    viewModel.historySearchText = ""
                    Task { await viewModel.loadRecentHistory() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(theme.appSubtleBorder, in: .rect(cornerRadius: 6))
        .onChange(of: viewModel.historySearchText) { _, new in
            Task { await viewModel.searchHistory(new) }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(viewModel.history.count) \(LumiPluginLocalization.string("entries", bundle: .module))")
                .font(.appMicro)
                .foregroundStyle(.secondary)
            Spacer()
            AppButton(LumiPluginLocalization.string("Clear All", bundle: .module), systemImage: "trash", style: .secondary, size: .small) {
                Task { await viewModel.clearHistory() }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }
}

// MARK: - Row

private struct HistoryRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let entry: QueryHistoryEntry
    var onLoad: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onLoad) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.sql)
                    .font(.monospaced(.callout)())
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Label(entry.configName, systemImage: "cylinder.split.1x2")
                    Text("·")
                    Text(entry.database)
                    Spacer()
                    Text(relativeTime(entry.executedAt))
                }
                .font(.appMicro)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(LumiPluginLocalization.string("Load into Editor", bundle: .module)) { onLoad() }
            Button(role: .destructive) { onDelete() } label: {
                Label(LumiPluginLocalization.string("Delete", bundle: .module), systemImage: "trash")
            }
        }
        Divider()
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return LumiPluginLocalization.string("just now", bundle: .module) }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }
}
