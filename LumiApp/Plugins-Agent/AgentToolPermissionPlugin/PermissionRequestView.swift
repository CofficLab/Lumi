import SwiftUI

/// 权限请求视图，用于显示工具执行请求并获取用户批准
struct PermissionRequestView: View {
    @EnvironmentObject private var permissionHandlingVM: PermissionHandlingVM
    @EnvironmentObject private var permissionRequestViewModel: PermissionRequestVM

    var body: some View {
        if let request = permissionRequestViewModel.pendingPermissionRequest {
            ZStack {
                // 半透明背景
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                GlassCard {
                    VStack(spacing: 16) {
                        // MARK: - Header
                        HStack {
                            Image(systemName: request.riskLevel.iconName)
                                .font(.title2)
                                .foregroundColor(request.riskLevel.iconColor)
                            Text(String(localized: "Permission Request", table: "DevAssistant"))
                                .font(.headline)
                            Spacer()
                        }

                        // MARK: - Content
                        VStack(alignment: .leading, spacing: 8) {
                            Text(request.summary)
                                .font(.body)
                                .fontWeight(.medium)

                            Text(String(localized: "The assistant is trying to perform a \(request.riskLevel.displayName) action.", table: "DevAssistant"))
                                .font(.caption)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                            // 可折叠的详细信息
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

                            // 风险提示（如果有）
                            if let reason = request.riskLevel.reason {
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
                        }

                        // MARK: - Actions
                        HStack(spacing: 12) {
                            GlassButton(title: LocalizedStringKey("Deny"), tableName: "DevAssistant", style: .ghost) {
                                Task { await permissionHandlingVM.respondToPermissionRequest(allowed: false) }
                            }

                            GlassButton(title: LocalizedStringKey("Allow"), tableName: "DevAssistant", style: .primary) {
                                Task { await permissionHandlingVM.respondToPermissionRequest(allowed: true) }
                            }
                        }
                    }
                    .padding(20)
                    .frame(width: 400)
                }
            }
            .transition(.opacity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("权限请求")
            .accessibilityHint("请审阅操作风险并选择允许或拒绝")
        }
    }
}
