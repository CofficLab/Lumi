import AgentToolKit
import Foundation
import LumiKernel
import LumiKernel
import LumiKernel

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
                    awaitingUserResponse: LumiAskUserMarkers.isPendingResponse(lumiResult.content)
                )
            },
            displayName: displayName
        )
    }
}

extension LumiChatMessage {
    func decodedImageAttachments() -> [LumiImageAttachment] {
        guard metadata["hasImages"] == "true",
              let json = metadata["imageAttachments"],
              let data = json.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([LumiImageAttachment].self, from: data)) ?? []
    }

    var userImageData: [Data] {
        decodedImageAttachments().compactMap { Data(base64Encoded: $0.base64Data) }
    }
}
