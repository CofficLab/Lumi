import LumiUI
import SwiftUI

/// MiniMax Token Plan 详情面板：逐模型展示 5 小时窗口与本周配额。
struct TokenPlanDetailView: View {
    @LumiTheme private var theme: any LumiUITheme

    let status: TokenPlanStatus
    let onRefresh: () -> Void

    // MARK: - View

    var body: some View {
        StatusBarPopoverScaffold(
            title: pluginLocalization.string("MiniMax Token Plan"),
            systemImage: "chart.bar.fill",
            subtitle: pluginLocalization.string("MiniMax Token Plan Quota")
        ) {
            AppIconButton(systemImage: "arrow.clockwise") {
                onRefresh()
            }
            .help(pluginLocalization.string("Refresh"))
        } content: {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .loading:
            loadingState
        case .success(let plans):
            details(plans)
        case .authError:
            messageState(
                systemImage: "exclamationmark.triangle.fill",
                text: pluginLocalization.string("Authentication failed; please check your API Key"),
                color: theme.error
            )
        case .unavailable:
            messageState(
                systemImage: "xmark.octagon.fill",
                text: pluginLocalization.string("Unable to fetch quota info"),
                color: theme.warning
            )
        }
    }

    private var loadingState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(pluginLocalization.string("Loading..."))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func messageState(systemImage: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(color)
            Text(text)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func details(_ plans: [TokenPlanData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(plans.enumerated()), id: \.offset) { index, plan in
                if index > 0 {
                    Divider()
                }
                modelSection(plan)
            }
        }
    }

    @ViewBuilder
    private func modelSection(_ plan: TokenPlanData) -> some View {
        let config = TokenPlanModelDisplayConfig.from(plan.modelName)

        VStack(alignment: .leading, spacing: 10) {
            labeledRow(
                label: pluginLocalization.string("Model:"),
                value: pluginLocalization.string(config.displayNameKey)
            )

            sectionHeader(
                pluginLocalization.string(config.intervalTitleKey),
                description: pluginLocalization.string(config.intervalDescriptionKey)
            )

            // MARK: - 5 小时窗口

            percentRow(percent: plan.remainingPercent)
            statusRow(label: pluginLocalization.string("Status:"), plan: plan, isWeekly: false)
            countRow(usage: plan.intervalUsage, total: plan.intervalTotal)
            timeRow(
                label: pluginLocalization.string("Time range:"),
                value: plan.intervalTimeRange
            )
            timeRow(
                label: pluginLocalization.string("Resets at:"),
                value: plan.remainsTimeComponents
                    .map(TokenPlanStatusLocalization.resetTimeText) ?? "—"
            )

            // MARK: - 本周

            sectionHeader(
                pluginLocalization.string("Weekly Quota"),
                description: pluginLocalization.string("Weekly cumulative call limit")
            )

            percentRow(percent: plan.weeklyRemainingPercent)
            statusRow(label: pluginLocalization.string("Status:"), plan: plan, isWeekly: true)
            countRow(usage: plan.weeklyUsage, total: plan.weeklyTotal)
            timeRow(
                label: pluginLocalization.string("Time range:"),
                value: plan.weeklyTimeRange
            )
            timeRow(
                label: pluginLocalization.string("Resets at:"),
                value: plan.weeklyRemainsTimeComponents
                    .map(TokenPlanStatusLocalization.resetTimeText) ?? "—"
            )
        }
    }

    // MARK: - Row Builders

    private func sectionHeader(_ title: String, description: String) -> some View {
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

    private func labeledRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private func percentRow(percent: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(pluginLocalization.string("Remaining:"))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("\(percent)%")
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            ProgressView(value: Double(percent), total: 100)
                .progressViewStyle(.linear)
                .tint(percent > 20 ? theme.success : theme.error)
        }
    }

    private func statusRow(label: String, plan: TokenPlanData, isWeekly: Bool) -> some View {
        let statusCode = isWeekly ? plan.weeklyStatus : plan.intervalStatus
        let isNormal = statusCode == QuotaStatusCode.normal.rawValue
        let color = isNormal ? theme.success : theme.error
        let key = isWeekly ? plan.weeklyStatusKey : plan.intervalStatusKey

        return HStack {
            Text(label)
                .foregroundColor(theme.textSecondary)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(pluginLocalization.string(key))
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
        }
    }

    private func countRow(usage: Int, total: Int) -> some View {
        HStack {
            Text(pluginLocalization.string("Call count:"))
                .foregroundColor(theme.textSecondary)
            Spacer()
            if total == 0 {
                Text(pluginLocalization.string("Unlimited"))
                    .fontWeight(.medium)
                    .foregroundColor(theme.success)
            } else {
                Text("\(usage) / \(total)")
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
    }

    private func timeRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .font(.system(size: 11))
                .monospacedDigit()
        }
    }
}

// MARK: - Preview

#if DEBUG
#if os(macOS)
#Preview("Detail - Success") {
    TokenPlanDetailView(
        status: .success(TokenPlanPreviewFixtures.allPlans),
        onRefresh: {}
    )
    .inRootView()
    .frame(width: 600, height: 1000)
}

#Preview("Detail - Success Compact") {
    TokenPlanDetailView(
        status: .success(TokenPlanPreviewFixtures.allPlans),
        onRefresh: {}
    )
    .inRootView()
    .frame(width: 600, height: 600)
}

#Preview("Detail - Auth Error") {
    TokenPlanDetailView(status: .authError, onRefresh: {})
        .inRootView()
        .frame(width: 600, height: 1000)
}
#endif
#endif
