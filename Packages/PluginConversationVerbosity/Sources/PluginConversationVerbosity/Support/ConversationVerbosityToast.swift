import os
import KitSuperLog
import ProviderToast

@MainActor
enum ConversationVerbosityToast: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.verbosity",
        category: "ConversationVerbosityToast"
    )

    static func show(
        _ toast: (any ToastProviding)?,
        title: String,
        detail: String?
    ) {
        guard let toast else {
            let detailValue = detail ?? "nil"
            Self.logger.error(
                "\(Self.t)ToastProviding is nil; unable to show conversation preference update: title=\(title, privacy: .public), detail=\(detailValue, privacy: .public)"
            )
            return
        }
        toast.show(title, detail: detail, style: .success)
    }
}
