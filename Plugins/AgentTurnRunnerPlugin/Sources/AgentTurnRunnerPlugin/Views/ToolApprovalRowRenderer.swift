import AgentToolKit
import SwiftUI

struct ToolApprovalRowRenderer: ToolCallRowRenderer {
    static let id = "agent-turn-tool-approval-row"
    static let priority = 110

    func canRender(toolCall: ToolCall) -> Bool {
        guard toolCall.result?.interactionState != nil,
              let payload = ToolApprovalPayload.parse(from: toolCall.result?.content)
        else { return false }
        return payload.isToolApproval
    }

    @MainActor
    func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let payload = ToolApprovalPayload.parse(from: toolCall.result?.content),
              payload.isToolApproval
        else {
            return AnyView(Text("无法解析工具授权请求"))
        }
        return AnyView(ToolApprovalView(payload: payload))
    }
}

private struct ToolApprovalView: View {
    let payload: ToolApprovalPayload
    @State private var submittedAnswer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("工具执行授权", systemImage: "exclamationmark.shield.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(payload.question)
                .font(.callout)
                .textSelection(.enabled)

            if let submittedAnswer {
                Text(submittedAnswer == "允许" ? "已允许执行" : "已拒绝执行")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    Button("允许") { submit("允许") }
                        .buttonStyle(.borderedProminent)
                    Button("拒绝", role: .destructive) { submit("拒绝") }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func submit(_ answer: String) {
        guard submittedAnswer == nil else { return }
        submittedAnswer = answer
        ToolApprovalBridge.shared.respond(to: payload, answer: answer)
    }
}
