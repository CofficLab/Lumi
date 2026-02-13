import SwiftUI

/// 权限请求视图，用于显示工具执行请求并获取用户批准
struct PermissionRequestView: View {
    let request: PermissionRequest
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
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
                        Text("Permission Request")
                            .font(.headline)
                        Spacer()
                    }

                    // MARK: - Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text(request.summary)
                            .font(.body)
                            .fontWeight(.medium)

                        Text("The assistant is trying to perform a \(request.riskLevel.displayName) action.")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                        // 可折叠的详细信息
                        DisclosureGroup("Details") {
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
                        GlassButton(title: "Deny", style: .ghost) {
                            onDeny()
                        }

                        GlassButton(title: "Allow", style: .primary) {
                            onAllow()
                        }
                    }
                }
                .padding(20)
                .frame(width: 400)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Preview

#Preview("Permission Request - High Risk") {
    PermissionRequestView(
        request: PermissionRequest(
            toolName: "run_command",
            argumentsString: "{\"command\": \"rm -rf /tmp\"}",
            toolCallID: "call_123",
            riskLevel: .high
        ),
        onAllow: {},
        onDeny: {}
    )
}

#Preview("Permission Request - Low Risk") {
    PermissionRequestView(
        request: PermissionRequest(
            toolName: "run_command",
            argumentsString: "{\"command\": \"ls -la\"}",
            toolCallID: "call_456",
            riskLevel: .low
        ),
        onAllow: {},
        onDeny: {}
    )
}
