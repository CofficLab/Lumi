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
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text("Permission Request")
                            .font(.headline)
                        Spacer()
                    }

                    // MARK: - Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text(request.summary)
                            .font(.body)
                            .fontWeight(.medium)

                        Text("The assistant is trying to perform a sensitive action.")
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

#Preview("Permission Request") {
    PermissionRequestView(
        request: PermissionRequest(
            toolName: "write_file",
            argumentsString: "{\"path\": \"/tmp/test.txt\", \"content\": \"Hello World\"}",
            toolCallID: "call_123"
        ),
        onAllow: {},
        onDeny: {}
    )
}
