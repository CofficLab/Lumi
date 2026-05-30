import LumiCoreKit
import PluginVerbosity
import SwiftUI

actor VerbosityPlugin: SuperPlugin {
    static let id = PluginVerbosity.VerbosityPlugin.id
    static let displayName = PluginVerbosity.VerbosityPlugin.displayName
    static let description = PluginVerbosity.VerbosityPlugin.description
    static let iconName = PluginVerbosity.VerbosityPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginVerbosity.VerbosityPlugin.category) }
    static var order: Int { PluginVerbosity.VerbosityPlugin.order }
    static let shared = VerbosityPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        PluginVerbosity.VerbosityPlugin.shared.addSidebarLeadingToolbarItems(context: context).map(SidebarToolbarItem.init(package:))
    }

    @MainActor
    func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "verbosity-toggle" else { return nil }
        return AnyView(VerbosityToolbarButton())
    }
}

private struct VerbosityToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var themeVM: AppThemeVM

    @State private var isPopoverPresented = false

    var body: some View {
        Button(action: {
            isPopoverPresented.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: llmVM.verbosity.iconName)
                    .font(.system(size: 13))
                Text(llmVM.verbosity.levelCode)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(String(localized: "Verbosity", table: "Verbosity"))
        .accessibilityHint(String(localized: "Verbosity Hint", table: "Verbosity"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VerbosityLevelPopover(
                selectedLevel: llmVM.verbosity,
                onSelect: selectLevel
            )
            .environmentObject(themeVM)
        }
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            if let preference = conversationVM.getVerbosityPreference() {
                llmVM.setVerbosity(preference)
            } else {
                llmVM.setVerbosity(.brief)
            }
        }
    }

    private func selectLevel(_ level: ResponseVerbosity) {
        withAnimation {
            llmVM.setVerbosity(level)
        }
        conversationVM.saveVerbosityPreference(level)
        isPopoverPresented = false
    }

    private var foregroundColor: Color {
        switch llmVM.verbosity {
        case .brief:
            Color.blue
        case .standard:
            themeVM.activeChromeTheme.workspaceSecondaryTextColor()
        case .detailed:
            Color.purple
        }
    }

    private var backgroundColor: Color {
        switch llmVM.verbosity {
        case .brief:
            Color.blue.opacity(0.1)
        case .standard:
            themeVM.activeChromeTheme.workspaceTextColor().opacity(0.06)
        case .detailed:
            Color.purple.opacity(0.1)
        }
    }

    private var helpText: String {
        switch llmVM.verbosity {
        case .brief:
            String(localized: "Brief Verbosity Description", table: "Verbosity")
        case .standard:
            "V2 标准：包含必要说明和步骤"
        case .detailed:
            String(localized: "Detailed Verbosity Description", table: "Verbosity")
        }
    }
}

private struct VerbosityLevelPopover: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    let selectedLevel: ResponseVerbosity
    let onSelect: (ResponseVerbosity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("详细级别")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeVM.activeChromeTheme.workspaceTextColor())

            ForEach(ResponseVerbosity.allCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    VerbosityLevelRow(level: level, isSelected: level == selectedLevel)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 260)
    }
}

private struct VerbosityLevelRow: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    let level: ResponseVerbosity
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: level.iconName)
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundColor(isSelected ? themeVM.activeChromeTheme.accentColors().primary : themeVM.activeChromeTheme.workspaceSecondaryTextColor())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(level.levelCode)
                        .font(.system(size: 12, weight: .semibold))
                    Text(level.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(level.description)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeVM.activeChromeTheme.accentColors().primary)
            }
        }
        .foregroundColor(themeVM.activeChromeTheme.workspaceTextColor())
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? themeVM.activeChromeTheme.accentColors().primary.opacity(0.12) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
