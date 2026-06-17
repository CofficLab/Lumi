import Foundation

/// Semantic features available at each indexing readiness level.
public enum SemanticCapabilityLevel: Int, Codable, Sendable, Comparable {
    case syntaxOnly = 0
    case singleFileInference = 1
    case partialIndex = 2
    case fullIndex = 3

    public static func < (lhs: SemanticCapabilityLevel, rhs: SemanticCapabilityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .syntaxOnly: return "Syntax Only"
        case .singleFileInference: return "Single-File Inference"
        case .partialIndex: return "Partial Index"
        case .fullIndex: return "Full Index"
        }
    }

    public var restrictedFeatures: [String] {
        switch self {
        case .syntaxOnly:
            return ["Go to Definition", "Rename Symbol", "Find References", "Module Diagnostics"]
        case .singleFileInference:
            return ["Cross-file References", "Rename Symbol", "Reliable Module Diagnostics"]
        case .partialIndex:
            return ["Some files may have incomplete semantic data"]
        case .fullIndex:
            return []
        }
    }
}

public enum SemanticCapabilityLevelResolver {
    public static func resolve(
        isXcodeProject: Bool,
        buildServerAvailable: Bool,
        semanticIndexStatus: XcodeSemanticIndexStatus,
        manifest: IndexManifest?,
        compileDatabaseURL: URL?,
        scheme: String?
    ) -> SemanticCapabilityLevel {
        guard isXcodeProject else { return .syntaxOnly }
        guard buildServerAvailable else { return .syntaxOnly }

        switch semanticIndexStatus {
        case .ready:
            break
        case .indexing, .notStarted:
            if buildServerAvailable { return .singleFileInference }
            return .syntaxOnly
        case .failed:
            if buildServerAvailable { return .singleFileInference }
            return .syntaxOnly
        }

        guard let compileDatabaseURL,
              FileManager.default.fileExists(atPath: compileDatabaseURL.path) else {
            return .singleFileInference
        }

        if let manifest, manifest.hasValidCompileDatabase {
            return .fullIndex
        }

        if FileManager.default.fileExists(atPath: compileDatabaseURL.path) {
            return .partialIndex
        }
        return .singleFileInference
    }
}
