import AgentToolKit
import Foundation
import KernelLumi
import KernelLumi
import KernelLumi

extension LumiToolCall {
    /// Bridges `LumiToolCall` to AgentToolKit's registry-facing `ToolCall` model.
    var agentToolCall: ToolCall {
        ToolCall(
            id: id,
            name: name,
            arguments: arguments,
            result: result.map { lumiResult in
                ToolCallResult(
                    content: lumiResult.content,
                    isError: lumiResult.isError,
                    duration: lumiResult.duration,
                    awaitingUserResponse: lumiResult.turnControl.isSuspended,
                    interactionState: Self.interactionState(for: lumiResult.turnControl)
                )
            },
            displayDescription: displayDescription
        )
    }

    private static func interactionState(for control: AgentTurnControl) -> ToolCallInteractionState? {
        switch control {
        case .continueTurn:
            return nil
        case .suspend:
            return .waiting
        case let .resumed(_, answer):
            return .answered(answer)
        }
    }
}

extension LumiChatMessage {
    func decodedImageAttachments() -> [LumiImageAttachment] {
        LumiImageAttachmentMetadata.decode(from: metadata)
    }

    var userImageData: [Data] {
        decodedImageAttachments().compactMap { Data(base64Encoded: $0.base64Data) }
    }

    /// 该消息携带的文件附件(解码自 metadata["fileAttachments"])。
    var decodedFileAttachments: [LumiFileAttachment] {
        LumiFileAttachmentMetadata.decode(from: metadata)
    }
}
