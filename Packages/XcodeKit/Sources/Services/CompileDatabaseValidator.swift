import Foundation

public enum CompileDatabaseValidationDepth: Sendable, Equatable {
    case metadataOnly
    case contentHash
    case fullParse
}

public struct CompileDatabaseValidationResult: Sendable, Equatable {
    public var isValid: Bool
    public var issue: String?
    public var depthUsed: CompileDatabaseValidationDepth

    public init(isValid: Bool, issue: String? = nil, depthUsed: CompileDatabaseValidationDepth) {
        self.isValid = isValid
        self.issue = issue
        self.depthUsed = depthUsed
    }
}

/// Tiered compile database validation to avoid main-thread JSON parsing on hot paths.
public enum CompileDatabaseValidator {
    /// O(1) metadata checks suitable for MainActor / synchronous UI paths.
    public static func validateMetadataOnly(
        manifest: IndexManifest?,
        compileDatabaseURL: URL,
        scheme: String,
        configuration: String,
        destination: String,
        inputs: IndexManifest.InputFingerprints,
        toolchain: IndexManifest.ToolchainInfo
    ) -> CompileDatabaseValidationResult {
        if let reason = IndexManifestValidation.invalidationReasonMetadataOnly(
            manifest: manifest,
            compileDatabaseURL: compileDatabaseURL,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        ) {
            return CompileDatabaseValidationResult(
                isValid: false,
                issue: String(describing: reason),
                depthUsed: .metadataOnly
            )
        }
        return CompileDatabaseValidationResult(isValid: true, depthUsed: .metadataOnly)
    }

    public static func isValidForOpen(
        manifest: IndexManifest?,
        compileDatabaseURL: URL,
        scheme: String,
        configuration: String,
        destination: String,
        inputs: IndexManifest.InputFingerprints,
        toolchain: IndexManifest.ToolchainInfo
    ) async -> Bool {
        let metadata = validateMetadataOnly(
            manifest: manifest,
            compileDatabaseURL: compileDatabaseURL,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        )
        guard metadata.isValid else { return false }

        guard let manifest, manifest.compileDatabase?.contentHash != nil else {
            return await validateForPromotion(at: compileDatabaseURL, scheme: scheme) == nil
        }

        let hashResult = await validateContentHash(
            manifest: manifest,
            compileDatabaseURL: compileDatabaseURL
        )
        return hashResult.isValid
    }

    public static func validateContentHash(
        manifest: IndexManifest?,
        compileDatabaseURL: URL,
        expectedHash: String? = nil
    ) async -> CompileDatabaseValidationResult {
        await Task.detached(priority: .utility) {
            validateContentHashSync(
                manifest: manifest,
                compileDatabaseURL: compileDatabaseURL,
                expectedHash: expectedHash
            )
        }.value
    }

    static func validateContentHashSync(
        manifest: IndexManifest?,
        compileDatabaseURL: URL,
        expectedHash: String? = nil
    ) -> CompileDatabaseValidationResult {
        guard FileManager.default.fileExists(atPath: compileDatabaseURL.path) else {
            return CompileDatabaseValidationResult(
                isValid: false,
                issue: "compile database missing",
                depthUsed: .contentHash
            )
        }

        let hash = expectedHash ?? manifest?.compileDatabase?.contentHash
        guard let hash else {
            guard IndexManifest.compileDatabaseContentHash(at: compileDatabaseURL) != nil else {
                return CompileDatabaseValidationResult(
                    isValid: false,
                    issue: "unable to hash compile database",
                    depthUsed: .contentHash
                )
            }
            return CompileDatabaseValidationResult(isValid: true, depthUsed: .contentHash)
        }

        guard let computed = IndexManifest.compileDatabaseContentHash(at: compileDatabaseURL) else {
            return CompileDatabaseValidationResult(
                isValid: false,
                issue: "unable to hash compile database",
                depthUsed: .contentHash
            )
        }
        guard computed == hash else {
            return CompileDatabaseValidationResult(
                isValid: false,
                issue: "compile database content hash mismatch",
                depthUsed: .contentHash
            )
        }
        return CompileDatabaseValidationResult(isValid: true, depthUsed: .contentHash)
    }

    public static func validateForPromotion(at compileURL: URL, scheme: String) async -> String? {
        await Task.detached(priority: .utility) {
            XcodeSemanticIndexRunner.validateCompileDatabase(at: compileURL, scheme: scheme)
        }.value
    }

    public static func makeCompileDatabaseInfo(at compileURL: URL, scheme: String) async -> IndexManifest.CompileDatabaseInfo? {
        await Task.detached(priority: .utility) {
            IndexManifest.makeCompileDatabaseInfo(at: compileURL, scheme: scheme)
        }.value
    }
}
