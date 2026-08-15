import Foundation
import KernelLumi
import LumiUI
import LocalizationKit
import SwiftUI

/// OpenCode Go 配额详情视图
struct OpenCodeGoDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let status: OpenCodeGoStatus
    let onRefresh: () -> Void

    var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("OpenCode Go", bundle: .module),
            systemImage: "bolt.fill"
        ) {
            AppIconButton(systemImage: "arrow.clockwise") {
                onRefresh()
            }
        } content: {
            switch status {
            case .loading:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载中...")
                        .foregroundColor(theme.textSecondary)
                }

            case .success(let state):
                detailContent(state)

            case .unavailable(let message):
                HStack {
                    Image(systemName: "bolt.slash.fill")
                        .foregroundColor(theme.warning)
                    Text(message)
                        .foregroundColor(theme.warning)
                }
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(_ state: OpenCodeGoState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 服务端配额（如果有官方数据）
            if let serverQuotas = state.server, !serverQuotas.isEmpty {
                serverSection(serverQuotas)

                if !state.windows.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                }
            }

            // 本地配额窗口
            if !state.windows.isEmpty {
                windowsSection(state.windows)
            }

            // 统计信息
            Divider()
                .padding(.vertical, 8)

            statsSection(state)
        }
    }

    // MARK: - Server Quotas Section

    @ViewBuilder
    private func serverSection(_ quotas: [OpenCodeGoServerQuota]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("官方配额", description: "来自 opencode.ai 的实时数据")

            ForEach(Array(quotas.enumerated()), id: \.offset) { index, quota in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 4)
                }
                serverQuotaRow(quota)
            }
        }
    }

    @ViewBuilder
    private func serverQuotaRow(_ quota: OpenCodeGoServerQuota) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(quota.label)
                    .fontWeight(.medium)
                Spacer()
                let remaining = max(0, 100 - Int(quota.pct))
                Text("\(remaining)%")
                    .fontWeight(.semibold)
                    .foregroundColor(remaining > 20 ? theme.success : theme.error)
            }

            ProgressView(value: quota.pct, total: 100)
                .progressViewStyle(.linear)
                .tint(quota.pct < 80 ? theme.success : theme.error)

            if let resetText = quota.resetText {
                Text(resetText)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            }
        }
    }

    // MARK: - Windows Section

    @ViewBuilder
    private func windowsSection(_ windows: [OpenCodeGoWindow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("本地配额", description: "基于本地日志统计")

            ForEach(Array(windows.enumerated()), id: \.offset) { index, window in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 4)
                }
                windowRow(window)
            }
        }
    }

    @ViewBuilder
    private func windowRow(_ window: OpenCodeGoWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(window.label)
                    .fontWeight(.medium)
                Spacer()
                let remaining = max(0, 100 - Int(window.pct))
                Text("\(remaining)%")
                    .fontWeight(.semibold)
                    .foregroundColor(remaining > 20 ? theme.success : theme.error)
            }

            ProgressView(value: window.pct, total: 100)
                .progressViewStyle(.linear)
                .tint(window.pct < 80 ? theme.success : theme.error)

            if let resetText = window.resetText {
                Text(resetText)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            } else {
                // 显示已用/总量
                Text("\(Int(window.used)) / \(Int(window.limit))")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            }
        }
    }

    // MARK: - Stats Section

    @ViewBuilder
    private func statsSection(_ state: OpenCodeGoState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("日志记录:")
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("\(state.rows) 条")
                    .fontWeight(.medium)
            }

            HStack {
                Text("API Key:")
                    .foregroundColor(theme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(state.key ? theme.success : theme.textSecondary)
                        .frame(width: 6, height: 6)
                    Text(state.key ? "已配置" : "未配置")
                        .fontWeight(.medium)
                        .foregroundColor(state.key ? theme.success : theme.textSecondary)
                }
            }

            HStack {
                Text("官方同步:")
                    .foregroundColor(theme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(state.serverConfigured ? theme.success : theme.textSecondary)
                        .frame(width: 6, height: 6)
                    Text(state.serverConfigured ? "已启用" : "未启用")
                        .fontWeight(.medium)
                        .foregroundColor(state.serverConfigured ? theme.success : theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, description: String = "") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            if !description.isEmpty {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            }
        }
    }
}
