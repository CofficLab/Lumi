import AppKit
import Foundation
import LumiKernel

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
            return AppKitFallbackRenderer() // Native tool rows land in Task 12.
        case .toolStepGroup:
            return AppKitFallbackRenderer()
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
}
