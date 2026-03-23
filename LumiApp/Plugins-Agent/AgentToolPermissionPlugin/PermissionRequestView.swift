import SwiftUI

/// 权限请求视图，用于显示工具执行请求并获取用户批准
struct PermissionRequestView: View {
    @EnvironmentObject private var permissionHandlingVM: PermissionHandlingVM
    @EnvironmentObject private var permissionRequestViewModel: PermissionRequestVM

    var body: some View {
        if let request = permissionRequestViewModel.pendingPermissionRequest {
            ZStack {
                backgroundOverlay
                permissionCard(for: request)
            }
            .transition(.opacity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("权限请求")
            .accessibilityHint("请审阅操作风险并选择允许或拒绝")
        }
    }
}

// MARK: - View
extension PermissionRequestView {
    private var backgroundOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
    }

    private func permissionCard(for request: PermissionRequest) -> some View {
        GlassCard {
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
            Text(String(localized: "Permission Request", table: "DevAssistant"))
                .font(.headline)
            Spacer()
        }
    }

    private func contentView(for request: PermissionRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request.summary)
                .font(.body)
                .fontWeight(.medium)

            Text(String(localized: "The assistant is trying to perform a \(request.riskLevel.displayName) action.", table: "DevAssistant"))
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            detailsDisclosure(for: request)

            if let reason = request.riskLevel.reason {
                riskHint(reason: reason)
            }
        }
    }

    private func detailsDisclosure(for request: PermissionRequest) -> some View {
        DisclosureGroup(String(localized: "Details", table: "DevAssistant")) {
            ScrollView {
                Text(request.details)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 100)
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func riskHint(reason: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundColor(.blue)
            Text(reason)
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .padding(.top, 4)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            GlassButton(title: LocalizedStringKey("Deny"), tableName: "DevAssistant", style: .ghost) {
                handleDeny()
            }

            GlassButton(title: LocalizedStringKey("Allow"), tableName: "DevAssistant", style: .primary) {
                handleAllow()
            }
        }
    }
}

// MARK: - Action
extension PermissionRequestView {
    func handleDeny() {
        Task {
            await permissionHandlingVM.respondToPermissionRequest(allowed: false)
        }
    }

    func handleAllow() {
        Task {
            await permissionHandlingVM.respondToPermissionRequest(allowed: true)
        }
    }
}

// MARK: - Preview
#Preview {
    PermissionRequestView()
        .environmentObject(PermissionHandlingVM())
        .environmentObject(PermissionRequestVM())
}