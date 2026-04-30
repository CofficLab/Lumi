import Foundation

@MainActor
enum XcodeSemanticAvailability {
    enum Strength {
        case hard
        case soft
    }

    static func preflightError(
        uri: String?,
        operation: String,
        symbolName: String? = nil,
        strength: Strength
    ) -> XcodeLSPError? {
        let context = LSPErrorContext(uri: uri, symbolName: symbolName, operation: operation)
        let classified = XcodeLSPErrorClassifier.classifyPreflight(context: context)
        guard strength == .soft else { return classified }
        guard let classified else { return nil }
        switch classified {
        case .serverNotStarted,
             .buildContextUnavailable,
             .fileNotInTarget,
             .fileInMultipleTargets,
             .fileTargetsExcludedByActiveScheme:
            return classified
        case .serverDisconnected,
             .noProjectContext,
             .symbolNotResolved,
             .symbolNotFound,
             .indexingInProgress,
             .requestTimeout,
             .unknown:
            return nil
        }
    }

    static func preflightMessage(
        uri: String?,
        operation: String,
        symbolName: String? = nil,
        strength: Strength
    ) -> String? {
        guard let error = preflightError(uri: uri, operation: operation, symbolName: symbolName, strength: strength) else {
            return nil
        }
        return XcodeLSPErrorClassifier.userMessage(for: error, operation: operation)
    }
}
