import SwiftUI
import LumiUI
import LumiKernel

/// ``MainView`` 的空状态视图。
///
/// 由两部分组成：
/// 1. 顶部 ``MainEmptyStateHeaderView`` —— 文案 + Add Connection 按钮；
/// 2. 已保存连接列表（如果有）—— 每个 ``DatabaseConfig`` 一行，点击触发连接。
///
/// 与父视图的耦合通过两个入口参数降到最低：
/// - `viewModel`：用于读取 configs、selectedConfig、isLoading 等展示态，
///   以及响应点击时的 `connect(config:)` 调用；
/// - `onAddConnection`：Add Connection 按钮的回调，由父视图决定是否弹出 sheet。
struct MainEmptyStateView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Properties

    /// 父视图注入的视图模型，用于读取状态与触发连接。
    @ObservedObject var viewModel: DatabaseViewModel

    /// 点击「Add Connection」按钮时触发的回调。
    let onAddConnection: () -> Void

    // MARK: - Initialization

    init(viewModel: DatabaseViewModel, onAddConnection: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onAddConnection = onAddConnection
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            MainEmptyStateHeaderView(onAddConnection: onAddConnection)
            savedConnectionsSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Saved connections

    @ViewBuilder
    private var savedConnectionsSection: some View {
        if !viewModel.configs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(LumiPluginLocalization.string("Saved Connections", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                AppCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.configs.enumerated()), id: \.element.id) { _, config in
                            savedConnectionRow(config)
                            if config.id != viewModel.configs.last?.id {
                                Divider()
                                    .background(theme.appSubtleBorder.opacity(0.4))
                            }
                        }
                    }
                }
                .frame(maxWidth: 480)
            }
            .padding(.horizontal, 24)
        }
    }

    private func savedConnectionRow(_ config: DatabaseConfig) -> some View {
        let isSelected = viewModel.selectedConfig?.id == config.id
        let isConnecting = viewModel.isLoading && isSelected
        return Button {
            Task { await viewModel.connect(config: config) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon(for: config.type))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.name)
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Text(detailLine(for: config))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isConnecting)
        .background(isSelected ? theme.appListRowHoverBackground.opacity(0.5) : Color.clear)
    }

    // MARK: - Helpers

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
}

// MARK: - 预览

#if DEBUG
#Preview("Empty - No Saved") {
    MainEmptyStateView(viewModel: DatabaseViewModel(), onAddConnection: {})
        .frame(width: 600, height: 400)
}
#endif