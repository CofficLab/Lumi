import MagicKit
import SwiftUI

/// 模型可用性工具栏按钮。
///
/// 在编辑器侧栏工具栏显示可用模型数量，点击后展示详情。
struct AvailabilityIndicatorButton: View {
    @ObservedObject private var store = LLMAvailabilityStore.shared
    @EnvironmentObject private var themeVM: AppThemeVM

    @State private var isPresented = false

    private var summary: AvailabilitySummary {
        AvailabilityService.summary(store: store)
    }

    var body: some View {
        Button(action: { isPresented = true }) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)

                if summary.totalModelCount > 0 {
                    if summary.isChecking {
                        Text(String(localized: "Checking...", table: "LLMAvailability"))
                            .font(.system(size: 11))
                            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    } else {
                        Text(summary.displayText ?? "")
                            .font(.system(size: 11, weight: summary.hasAvailableModels ? .semibold : .regular))
                            .foregroundColor(iconColor)
                    }
                } else {
                    Text(String(localized: "No LLM", table: "LLMAvailability"))
                        .font(.system(size: 11))
                        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeVM.activeAppTheme.workspaceTextColor().opacity(0.06))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .leading) {
            AvailabilityDetailView(mode: .popover)
        }
        .accessibilityLabel(String(localized: "LLM Availability", table: "LLMAvailability"))
    }

    // MARK: - Computed Properties

    private var iconName: String {
        if summary.isChecking {
            return "arrow.triangle.2.circlepath"
        } else if summary.hasAvailableModels {
            return "network"
        } else {
            return "network.slash"
        }
    }

    private var iconColor: Color {
        if summary.isChecking {
            return Color(hex: "FF9F0A")
        } else if summary.hasAvailableModels {
            return Color(hex: "30D158")
        } else {
            return Color(hex: "FF3B30")
        }
    }
}

// MARK: - Preview

#Preview("Availability Indicator Button") {
    AvailabilityIndicatorButton()
        .frame(height: 30)
        .inRootView()
}
