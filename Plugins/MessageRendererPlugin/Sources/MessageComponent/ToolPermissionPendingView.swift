import AgentToolKit
import LumiUI
import SwiftUI

/// 工具调用等待授权时，在助手消息内联展示同意/拒绝按钮。
struct ToolPermissionPendingView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let toolCall: ToolCall
    let conversationId: UUID
    let assistantMessageId: UUID

    @State private var isResponding = false

    private var riskLevel: CommandRiskLevel {
        MessageRendererRuntime.evaluateToolPermissionRisk(toolCall.name, toolCall.arguments)
    }

    private var formattedArguments: String? {
        guard !toolCall.arguments.isEmpty,
              toolCall.arguments != "{}",
              let data = toolCall.arguments.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let prettyData = try? JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .sortedKeys]
        ),
        let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        return toolCall.arguments
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 28, height: 28)
                    .background(.orange.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Tool permission required", bundle: .module))
                        .font(.appCallout.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text(riskLevel.displayName)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(toolCall.displayName ?? toolCall.name)
                    .font(.appCaption.weight(.medium))
                    .foregroundStyle(theme.textPrimary)

                if let reason = riskLevel.reason {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .font(.appCaption)
                        .foregroundStyle(.orange)
                }
            }

            if let formattedArguments {
                AppCard(style: .subtle, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)) {
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(formattedArguments)
                            .font(.appMonoCaption)
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 120)
                }
            }

            HStack(spacing: 10) {
                Spacer()

                Button {
                    respond(allowed: false)
                } label: {
                    Text(String(localized: "Deny", bundle: .module))
                        .frame(minWidth: 72)
                }
                .disabled(isResponding)

                Button {
                    respond(allowed: true)
                } label: {
                    Text(String(localized: "Allow", bundle: .module))
                        .frame(minWidth: 72)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isResponding)
            }
        }
        .padding(12)
        .background(theme.textSecondary.opacity(0.06))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.orange.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func respond(allowed: Bool) {
        guard !isResponding else { return }
        isResponding = true
        Task {
            await MessageRendererRuntime.respondToToolPermission(
                conversationId,
                assistantMessageId,
                toolCall.id,
                allowed
            )
            isResponding = false
        }
    }
}
