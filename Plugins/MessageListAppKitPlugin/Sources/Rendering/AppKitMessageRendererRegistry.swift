import AppKit
import Foundation
import KernelLumi

/// Resolves the native renderer for a message row.
///
/// Priority mirrors the SwiftUI registry's semantic precedence:
/// status → error → tool → tool-group → user → assistant → system → fallback.
/// Matching is pure and cheap so it can run inside cell configuration and
/// layout-cache lookups.
@MainActor
final class AppKitMessageRendererRegistry {
    struct Environment {
        let theme: AppKitMessageTheme
        let mermaidCache: AppKitMermaidCache
        let layoutCache: AppKitMessageLayoutCache
        weak var outerScrollView: NSScrollView?
        /// Resend handler wired by the controller (V1/V2 chrome action).
        var onResend: ((LumiChatMessage) -> Void)?
        /// Used by the ask_user renderer to resume suspended turns.
        weak var messageSender: (any MessageSending)?
    }

    private let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    func renderer(for row: AppKitMessageRow) -> any AppKitMessageRenderer {
        switch row.kind {
        case .status:
            return AppKitStatusRenderer(theme: environment.theme)
        case .error:
            return AppKitErrorRenderer(theme: environment.theme)
        case .tool:
            // Suspended ask_user calls get the interactive renderer; all other
            // tool calls get the generic one.
            if Self.isPendingUserInteraction(row.message) {
                return AppKitAskUserRenderer(environment: environment)
            }
            return AppKitToolRenderer(environment: environment)
        case .toolStepGroup:
            return AppKitToolGroupRenderer(environment: environment)
        case .user:
            return AppKitUserRenderer(environment: environment)
        case .assistant, .conclusion:
            return AppKitAssistantRenderer(environment: environment)
        case .system:
            return AppKitSystemRenderer(environment: environment)
        case .streaming:
            return AppKitAssistantRenderer(environment: environment)
        case .fallback:
            return AppKitFallbackRenderer()
        }
    }

    /// True when the message carries a suspended `ask_user` tool call whose
    /// result content parses into an interactive payload.
    static func isPendingAskUser(_ message: LumiChatMessage) -> Bool {
        isPendingUserInteraction(message, restrictedToAskUser: true)
    }

    static func isPendingUserInteraction(
        _ message: LumiChatMessage,
        restrictedToAskUser: Bool = false
    ) -> Bool {
        guard let call = message.toolCalls?.first(where: {
                  (!restrictedToAskUser || $0.name == "ask_user")
                      && $0.result?.turnControl.isSuspended == true
                      && AppKitAskUserPayload.parse(from: $0.result?.content) != nil
              }),
              let result = call.result,
              !result.turnControl.isSuspended == false
        else { return false }
        // Suspended interaction: result content carries the pending payload.
        return result.turnControl.isSuspended
            && AppKitAskUserPayload.parse(from: result.content) != nil
    }
}
