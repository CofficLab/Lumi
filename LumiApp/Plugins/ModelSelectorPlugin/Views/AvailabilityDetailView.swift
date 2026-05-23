import SwiftUI
import LumiUI

enum AvailabilityDetailMode: Equatable {
    case popover
    case tab
}

/// LLM 可用性详情面板
///
/// 显示所有供应商和模型的可用性状态，支持刷新和搜索
struct AvailabilityDetailView: View {
    @ObservedObject private var store = LLMAvailabilityStore.shared
    @EnvironmentObject private var llmVM: AppLLMVM

    let mode: AvailabilityDetailMode

    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var checkingProviderIds: Set<String> = []
    @State private var errorMessage: String?

    // MARK: - Computed

    /// 过滤后的供应商列表
    private var filteredProviders: [LLMProviderAvailability] {
        AvailabilityService.filteredProviders(from: store.providers, searchText: searchText)
    }

    /// 可用模型数量
    private var availableModelCount: Int {
        summary.availableModelCount
    }

    /// 总模型数量
    private var totalModelCount: Int {
        summary.totalModelCount
    }

    /// 是否正在检测
    private var isChecking: Bool {
        summary.isChecking
    }

    private var summary: AvailabilitySummary {
        AvailabilityService.summary(store: store)
    }

    // MARK: - Adaptive Colors

    @LumiUI.LumiTheme private var theme: any LumiUITheme

    private var availableColor: Color { theme.success }
    private var unavailableColor: Color { theme.error }
    private var checkingColor: Color { theme.warning }
    private var unknownColor: Color { theme.textTertiary }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            if isRefreshing {
                Divider()
                loadingView
            } else if let error = errorMessage {
                Divider()
                errorView(message: error)
            } else if store.providers.isEmpty {
                Divider()
                emptyStateView
            } else {
                Divider()
                contentSection
            }

            if isChecking {
                Divider()
                checkingFooterView
            }
        }
        .frame(height: mode == .popover ? 500 : nil)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 8) {
            AppSearchBar(
                text: $searchText,
                placeholder: "Search providers or models…"
            )

            AppIconButton(
                systemImage: "arrow.clockwise",
                size: .compact,
                action: refreshAvailability
            )
            .help(String(localized: "Refresh", table: "LLMAvailability"))
            .disabled(isRefreshing || isChecking)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 统计信息
                statsSection

                // 供应商列表
                providerListSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            // 可用数量
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.appMicro)
                    .foregroundColor(availableColor)

                Text("\(availableModelCount)")
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Text(String(localized: "Available", table: "LLMAvailability"))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }

            // 总数
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.appMicro)
                    .foregroundColor(unknownColor)

                Text("\(totalModelCount)")
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Text(String(localized: "Total", table: "LLMAvailability"))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .appSurface(style: .subtle, cornerRadius: 8)
    }

    private var providerListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if filteredProviders.isEmpty {
                Text(String(localized: "No providers found", table: "LLMAvailability"))
                    .font(.appCaption)
                    .foregroundColor(unknownColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(filteredProviders) { provider in
                    providerCard(provider: provider)
                }
            }
        }
    }

    private func providerCard(provider: LLMProviderAvailability) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                // 供应商标题
                HStack(spacing: 8) {
                    providerStatusIcon(provider: provider)

                    Text(provider.displayName)
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)

                    Spacer()

                    AppIconButton(
                        systemImage: checkingProviderIds.contains(provider.providerId) ? "arrow.triangle.2.circlepath" : "arrow.clockwise",
                        size: .compact,
                        action: { recheckProvider(provider) }
                    )
                    .help(String(localized: "Recheck this provider", table: "LLMAvailability"))
                    .disabled(checkingProviderIds.contains(provider.providerId) || isRefreshing)

                    Text("\(provider.availableModels.count)/\(provider.models.count)")
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }

                // 模型列表
                if !provider.models.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(provider.models) { model in
                            modelRow(model: model)
                        }
                    }
                }
            }
        }
    }

    private func modelRow(model: LLMModelAvailability) -> some View {
        HStack(spacing: 8) {
            modelStatusIcon(model: model)
                .frame(width: 16, alignment: .center)

            Text(model.modelId)
                .font(.appCaption)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            Spacer()

            if case .unavailable(let reason) = model.status {
                Text(reason)
                    .font(.appMicro)
                    .foregroundColor(unavailableColor)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(modelBackgroundColor(model: model))
        )
    }

    // MARK: - Status Helpers

    private func providerStatusIcon(provider: LLMProviderAvailability) -> some View {
        if provider.hasAvailableModels {
            return Image(systemName: "checkmark.circle.fill")
                .font(.appCaption)
                .foregroundColor(availableColor)
        } else {
            return Image(systemName: "xmark.circle.fill")
                .font(.appCaption)
                .foregroundColor(unavailableColor)
        }
    }

    private func modelStatusIcon(model: LLMModelAvailability) -> some View {
        switch model.status {
        case .available:
            return Image(systemName: "checkmark")
                .font(.appMicroEmphasized)
                .foregroundColor(availableColor)
        case .unavailable:
            return Image(systemName: "xmark")
                .font(.appMicroEmphasized)
                .foregroundColor(unavailableColor)
        case .checking:
            return Image(systemName: "ellipsis")
                .font(.appMicroEmphasized)
                .foregroundColor(checkingColor)
        case .unknown:
            return Image(systemName: "questionmark")
                .font(.appMicroEmphasized)
                .foregroundColor(unknownColor)
        }
    }

    private func modelBackgroundColor(model: LLMModelAvailability) -> Color {
        switch model.status {
        case .available:
            return availableColor.opacity(0.1)
        case .unavailable:
            return unavailableColor.opacity(0.1)
        case .checking:
            return checkingColor.opacity(0.1)
        case .unknown:
            return unknownColor.opacity(0.1)
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(0.8)
            Text(String(localized: "Loading provider information…", table: "LLMAvailability"))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.appLargeTitle)
                .foregroundColor(theme.warning)

            Text(message)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.appLargeTitle)
                .foregroundColor(unknownColor)

            Text(String(localized: "No LLM providers configured", table: "LLMAvailability"))
                .font(.appBody)
                .foregroundColor(theme.textSecondary)

            Text(String(localized: "Please add LLM providers in Settings to enable AI features.", table: "LLMAvailability"))
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var checkingFooterView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            Text(String(localized: "Checking availability…", table: "LLMAvailability"))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .appSurface(style: .subtle)
    }

    // MARK: - Actions

    private func refreshAvailability() {
        guard !isRefreshing && !isChecking else { return }

        isRefreshing = true
        errorMessage = nil

        Task { @MainActor in
            await AvailabilityService.refresh(llmVM: llmVM)
            isRefreshing = false
        }
    }

    private func recheckProvider(_ provider: LLMProviderAvailability) {
        guard !checkingProviderIds.contains(provider.providerId) else { return }

        checkingProviderIds.insert(provider.providerId)

        Task { @MainActor in
            await AvailabilityService.recheckProvider(provider, llmVM: llmVM)
            checkingProviderIds.remove(provider.providerId)
        }
    }
}

// MARK: - Preview

#Preview("Availability Detail") {
    AvailabilityDetailView(mode: .popover)
        .inRootView()
}
