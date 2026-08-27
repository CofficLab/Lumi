import KitSuperLog
import os
import ProviderToast

@MainActor
enum ConversationModeToast: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-mode",
        category: "ConversationModeToast"
    )

    static func show(
        _ toast: (any ToastProviding)?,
        title: String,
        detail: String?
    ) {
        guard let toast else {
            let detailValue = detail ?? "nil"
            Self.logger.error(
                "\(Self.t)ToastProviding is nil; unable to show automation level update: title=\(title, privacy: .public), detail=\(detailValue, privacy: .public)"
            )
            return
        }
        toast.show(title, detail: detail, style: .success)
    }
}
