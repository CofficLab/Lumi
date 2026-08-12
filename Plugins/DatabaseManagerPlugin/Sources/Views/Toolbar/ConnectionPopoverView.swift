import LumiUI
import SwiftUI

/// Popover 内容：紧凑版的「数据库连接管理」。
///
/// 仅承载连接列表、Add Connection、当前连接状态、断开等高频操作；
/// Tables/Keys 浏览、Query 编辑、结果表仍放在主面板 `DatabaseMainView`。
struct ConnectionPopoverView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: DatabaseViewModel

    /// 由调用方在 popover 关闭时置 false，用于通知主面板同步按钮高亮状态。
    @Binding var isPopoverPresented: Bool

    @State private var showAddConfigSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            divider
            connectionList
            divider
            footer
        }
        .padding(.vertical, 4)
        .frame(width: 280)
        .sheet(isPresented: $showAddConfigSheet) {
            ConnectionFormView(viewModel: viewModel, isPresented: $showAddConfigSheet)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "cylinder.split.1x2")
                .foregroundColor(theme.primary)
            Text(LumiPluginLocalization.string("Database Connections", bundle: .module))
                .font(.appBodyEmphasized)
                .foregroundColor(theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - List

    @ViewBuilder
    private var connectionList: some View {
        if viewModel.configs.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .foregroundColor(theme.textSecondary)
                Text(LumiPluginLocalization.string("No saved connections", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.configs.enumerated()), id: \.element.id) { _, config in
                    connectionRow(config)
                    if config.id != viewModel.configs.last?.id {
                        Divider()
                            .background(theme.appSubtleBorder.opacity(0.4))
                    }
                }
            }
        }
    }

    private func connectionRow(_ config: DatabaseConfig) -> some View {
        let isSelected = viewModel.selectedConfig?.id == config.id
        let isConnected = isSelected && viewModel.isConnected
        return Button {
            Task {
                await viewModel.connect(config: config)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon(for: config.type))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(config.name)
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Text(detailLine(for: config))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                statusIndicator(isSelected: isSelected, isConnected: isConnected)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? theme.appListRowHoverBackground.opacity(0.5) : Color.clear)
    }

    @ViewBuilder
    private func statusIndicator(isSelected: Bool, isConnected: Bool) -> some View {
        if viewModel.isLoading && isSelected {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        } else if isConnected {
            Circle()
                .fill(theme.success)
                .frame(width: 8, height: 8)
        } else if isSelected {
            Circle()
                .stroke(theme.appSubtleBorder, lineWidth: 1)
                .frame(width: 8, height: 8)
        }
    }

    private func icon(for type: DatabaseType) -> String {
        switch type {
        case .sqlite: return "doc.text.fill"
        case .mysql: return "cylinder.split.1x2.fill"
        case .postgresql: return "cylinder.split.1x2"
        case .redis: return "memorychip"
        }
    }

    private func detailLine(for config: DatabaseConfig) -> String {
        switch config.type {
        case .sqlite:
            return "SQLite · \(config.database)"
        case .redis:
            let host = config.host ?? "127.0.0.1"
            return "Redis · \(host):\(config.port ?? 6379)"
        case .mysql:
            let host = config.host ?? "127.0.0.1"
            return "MySQL · \(host):\(config.port ?? 3306)/\(config.database)"
        case .postgresql:
            let host = config.host ?? "127.0.0.1"
            return "PostgreSQL · \(host):\(config.port ?? 5432)/\(config.database)"
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            AppButton(
                LumiPluginLocalization.string("Add Connection", bundle: .module),
                systemImage: "plus",
                style: .ghost,
                fillsWidth: true,
                action: { showAddConfigSheet = true }
            )
            if viewModel.isConnected {
                AppButton(
                    LumiPluginLocalization.string("Disconnect", bundle: .module),
                    systemImage: "power",
                    style: .secondary,
                    fillsWidth: false,
                    action: {
                        Task {
                            await viewModel.disconnect()
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.appDivider.opacity(0.6))
            .frame(height: 1)
    }
}
