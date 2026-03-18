import SwiftUI

private enum ToolExecutionStatus {
    case requested
    case waitingPermission
    case running
    case completed
    case failed
}

private struct ToolExecutionStep: Identifiable {
    let id: String
    let name: String
    let status: ToolExecutionStatus
}

struct ToolExecutionTimelineView: View {
    let toolCalls: [ToolCall]
    let toolOutputs: [ChatMessage]
    let waitingPermissionToolCallId: String?

    private var steps: [ToolExecutionStep] {
        toolCalls.map { call in
            let output = toolOutputs.first(where: { $0.toolCallID == call.id })
            let status: ToolExecutionStatus
            if let output {
                let lower = output.content.lowercased()
                if output.isError || lower.contains("error") || lower.contains("aborted") {
                    status = .failed
                } else {
                    status = .completed
                }
            } else if waitingPermissionToolCallId == call.id {
                status = .waitingPermission
            } else if call == toolCalls.last {
                status = .running
            } else {
                status = .requested
            }
            return ToolExecutionStep(id: call.id, name: call.name, status: status)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: iconName(for: step.status))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(iconColor(for: step.status))
                        .frame(width: 14)

                    Text(step.name)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(label(for: step.status))
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                        .frame(width: 1, height: 12)
                        .padding(.leading, 6.5)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.15), lineWidth: 1)
                )
        )
        .onAppear {
            ChatPerformanceMetrics.shared.markToolTimelineRendered()
        }
    }

    private func label(for status: ToolExecutionStatus) -> String {
        switch status {
        case .requested: return "已请求"
        case .waitingPermission: return "待授权"
        case .running: return "执行中"
        case .completed: return "已完成"
        case .failed: return "失败"
        }
    }

    private func iconName(for status: ToolExecutionStatus) -> String {
        switch status {
        case .requested: return "clock"
        case .waitingPermission: return "hand.raised"
        case .running: return "bolt.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }

    private func iconColor(for status: ToolExecutionStatus) -> Color {
        switch status {
        case .requested, .waitingPermission, .running:
            return DesignTokens.Color.semantic.textSecondary
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

