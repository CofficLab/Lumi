import SwiftUI
import MagicKit
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

    private var availableColor: Color {
        Color(hex: "30D158")
    }

    private var unavailableColor: Color {
        Color(hex: "FF3B30")
    }

    private var checkingColor: Color {
        Color(hex: "FF9F0A")
    }

    private var unknownColor: Color {
        Color(hex: "98989E")
    }

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
        HStack(spacing: AppUI.Spacing.sm) {
            AppSearchBar(
                text: $searchText,
                placeholder: String(localized: "Search providers or models…", table: "LLMAvailability")
            )

            AppIconButton(
                systemImage: "arrow.clockwise",
                size: .compact,
                action: refreshAvailability
            )
            .help(String(localized: "Refresh", table: "LLMAvailability"))
            .disabled(isRefreshing || isChecking)
        }
        .padding(.horizontal, AppUI.Spacing.lg)
        .padding(.vertical, AppUI.Spacing.sm)
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
                    .font(.system(size: 12))
                    .foregroundColor(availableColor)

                Text("\(availableModelCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Text(String(localized: "Available", table: "LLMAvailability"))
                    .font(.system(size: 12))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }

            // 总数
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(unknownColor)

                Text("\(totalModelCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Text(String(localized: "Total", table: "LLMAvailability"))
                    .font(.system(size: 12))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptive(light: "F5F5F7", dark: "1C1C1E"))
        )
    }

    private var providerListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if filteredProviders.isEmpty {
                Text(String(localized: "No providers found", table: "LLMAvailability"))
                    .font(.system(size: 12))
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
        VStack(alignment: .leading, spacing: 8) {
            // 供应商标题
            HStack(spacing: 8) {
                providerStatusIcon(provider: provider)

                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Spacer()

                Button(action: { recheckProvider(provider) }) {
                    Image(systemName: checkingProviderIds.contains(provider.providerId) ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .buttonStyle(.plain)
                .help(String(localized: "Recheck this provider", table: "LLMAvailability"))
                .disabled(checkingProviderIds.contains(provider.providerId) || isRefreshing)

                Text("\(provider.availableModels.count)/\(provider.models.count)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptive(light: "FFFFFF", dark: "0D0D12"))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }

    private func modelRow(model: LLMModelAvailability) -> some View {
        HStack(spacing: 8) {
            modelStatusIcon(model: model)
                .frame(width: 16, alignment: .center)

            Text(model.modelId)
                .font(.system(size: 12))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                .lineLimit(1)

            Spacer()

            if case .unavailable(let reason) = model.status {
                Text(reason)
                    .font(.system(size: 10))
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
                .font(.system(size: 14))
                .foregroundColor(availableColor)
        } else {
            return Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(unavailableColor)
        }
    }

    private func modelStatusIcon(model: LLMModelAvailability) -> some View {
        switch model.status {
        case .available:
            return Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(availableColor)
        case .unavailable:
            return Image(systemName: "xmark")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(unavailableColor)
        case .checking:
            return Image(systemName: "ellipsis")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(checkingColor)
        case .unknown:
            return Image(systemName: "questionmark")
                .font(.system(size: 10, weight: .medium))
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
                .font(.system(size: 12))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "FF9F0A"))

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 32))
                .foregroundColor(unknownColor)

            Text(String(localized: "No LLM providers configured", table: "LLMAvailability"))
                .font(.system(size: 13))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            Text(String(localized: "Please add LLM providers in Settings to enable AI features.", table: "LLMAvailability"))
                .font(.system(size: 11))
                .foregroundColor(unknownColor)
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
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.adaptive(light: "F5F5F7", dark: "0D0D12"))
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
