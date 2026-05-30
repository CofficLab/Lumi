import LumiCoreKit
import LumiUI
import PluginToolPermission
import SwiftUI

actor ToolPermissionPlugin: SuperPlugin {
    nonisolated static let emoji = PluginToolPermission.AgentToolPermissionPlugin.emoji
    nonisolated static let verbose = PluginToolPermission.AgentToolPermissionPlugin.verbose
    static let id = PluginToolPermission.AgentToolPermissionPlugin.id
    static let displayName = PluginToolPermission.AgentToolPermissionPlugin.displayName
    static let description = PluginToolPermission.AgentToolPermissionPlugin.description
    static let iconName = PluginToolPermission.AgentToolPermissionPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginToolPermission.AgentToolPermissionPlugin.category) }
    static var order: Int { PluginToolPermission.AgentToolPermissionPlugin.order }
    static let shared = ToolPermissionPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ToolPermissionRootOverlay(content: content()))
    }
}

private struct ToolPermissionRootOverlay<Content: View>: View {
    let content: Content

    var body: some View {
        ZStack {
            content
            PermissionRequestView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PermissionRequestView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @LumiMotionPreferenceReader private var motionPreference
    @EnvironmentObject private var permissionHandlingVM: WindowPermissionHandlingVM
    @EnvironmentObject private var permissionRequestViewModel: WindowPermissionRequestVM

    var body: some View {
        if let request = permissionRequestViewModel.pendingPermissionRequest {
            ZStack {
                backgroundOverlay
                permissionCard(for: request)
            }
            .appStatusPresentationTransition(preference: motionPreference)
            .animation(
                LumiMotion.enabled(LumiMotion.statusPresentation, preference: motionPreference),
                value: permissionRequestViewModel.pendingPermissionRequest?.id
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "Accessibility Label - Permission Request", table: "AgentToolPermission"))
            .accessibilityHint(String(localized: "Accessibility Hint - Permission Request", table: "AgentToolPermission"))
        }
    }

    private var backgroundOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
    }

    private func permissionCard(for request: PermissionRequest) -> some View {
        AppCard {
            VStack(spacing: 16) {
                headerView(for: request)
                contentView(for: request)
                actionButtons
            }
            .padding(20)
            .frame(width: 400)
        }
    }

    private func headerView(for request: PermissionRequest) -> some View {
        HStack {
            Image(systemName: request.riskLevel.iconName)
                .font(.title2)
                .foregroundColor(request.riskLevel.iconColor)
            Text(String(localized: "Permission Request", table: "AgentToolPermission"))
                .font(.appBodyEmphasized)
                .foregroundColor(theme.textPrimary)
            Spacer()
        }
    }

    private func contentView(for request: PermissionRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request.summary)
                .font(.appBody)
                .fontWeight(.medium)
                .foregroundColor(theme.textPrimary)

            Text(String(localized: "The assistant is trying to perform a \(request.riskLevel.displayName) action.", table: "AgentToolPermission"))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)

            detailsDisclosure(for: request)

            if let reason = request.riskLevel.reason {
                riskHint(reason: reason)
            }
        }
    }

    private func detailsDisclosure(for request: PermissionRequest) -> some View {
        DisclosureGroup(String(localized: "Details", table: "AgentToolPermission")) {
            ScrollView {
                Text(request.details)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 100)
            .appSurface(style: .subtle, cornerRadius: 8)
        }
    }

    private func riskHint(reason: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle.fill")
                .font(.appCaption)
                .foregroundColor(theme.info)
            Text(reason)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .padding(.top, 4)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            AppButton(localized: "Deny", table: "AgentToolPermission", style: .ghost, fillsWidth: true) {
                handleDeny()
            }

            AppButton(localized: "Allow", table: "AgentToolPermission", style: .primary, fillsWidth: true) {
                handleAllow()
            }
        }
    }

    private func handleDeny() {
        Task {
            await permissionHandlingVM.respondToPermissionRequest(allowed: false)
        }
    }

    private func handleAllow() {
        Task {
            await permissionHandlingVM.respondToPermissionRequest(allowed: true)
        }
    }
}
