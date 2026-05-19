import SwiftUI
import LumiUI
import MagicKit

/// LLM 可用性状态栏视图
///
/// 在状态栏显示一个图标，点击后显示供应商和模型的可用性情况
struct LLMAvailabilityStatusBarView: View {
    @ObservedObject private var store = LLMAvailabilityStore.shared

    /// 可用模型数量
    private var availableModelCount: Int {
        store.availablePairs.count
    }

    /// 总模型数量
    private var totalModelCount: Int {
        store.providers.reduce(0) { $0 + $1.models.count }
    }

    /// 是否有可用模型
    private var hasAvailableModels: Bool {
        availableModelCount > 0
    }

    /// 是否正在检测
    private var isChecking: Bool {
        store.isCheckingAll
    }

    var body: some View {
        StatusBarHoverContainer(
            detailView: LLMAvailabilityDetailView(),
            popoverWidth: 600,
            id: "llm-availability-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 10))
                    .foregroundColor(iconColor)

                if totalModelCount > 0 {
                    if isChecking {
                        Text(String(localized: "Checking...", table: "LLMAvailability"))
                            .font(.system(size: 11))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    } else {
                        Text("\(availableModelCount)/\(totalModelCount)")
                            .font(.system(size: 11, weight: hasAvailableModels ? .semibold : .regular))
                            .foregroundColor(iconColor)
                    }
                } else {
                    Text(String(localized: "No LLM", table: "LLMAvailability"))
                        .font(.system(size: 11))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Computed Properties

    private var iconName: String {
        if isChecking {
            return "arrow.triangle.2.circlepath"
        } else if hasAvailableModels {
            return "network"
        } else {
            return "network.slash"
        }
    }

    private var iconColor: Color {
        if isChecking {
            return Color(hex: "FF9F0A")
        } else if hasAvailableModels {
            return Color(hex: "30D158")
        } else {
            return Color(hex: "FF3B30")
        }
    }
}

// MARK: - Preview

#Preview("LLM Availability Status Bar") {
    LLMAvailabilityStatusBarView()
        .frame(height: 30)
        .inRootView()
}