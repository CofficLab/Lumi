import Foundation
import CryptoKit

/// Persistent metadata describing a workspace's semantic index cache validity.
public struct IndexManifest: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let fileName = "index-manifest.json"

    public struct InputFingerprints: Codable, Equatable, Sendable {
        public var pbxprojHash: String?
        public var packageResolvedHash: String?
        public var xcschemeHash: String?

        public init(
            pbxprojHash: String? = nil,
            packageResolvedHash: String? = nil,
            xcschemeHash: String? = nil
        ) {
            self.pbxprojHash = pbxprojHash
            self.packageResolvedHash = packageResolvedHash
            self.xcschemeHash = xcschemeHash
        }
    }

    public struct ToolchainInfo: Codable, Equatable, Sendable {
        public var xcodeVersion: String?
        public var xcodeBuildServerVersion: String?

        public init(xcodeVersion: String? = nil, xcodeBuildServerVersion: String? = nil) {
            self.xcodeVersion = xcodeVersion
            self.xcodeBuildServerVersion = xcodeBuildServerVersion
        }
    }

    public struct CompileDatabaseInfo: Codable, Equatable, Sendable {
        public var entryCount: Int
        public var includesSchemeModule: Bool
        public var contentHash: String?
        public var fileSizeBytes: Int64?

        public init(
            entryCount: Int,
            includesSchemeModule: Bool,
            contentHash: String? = nil,
            fileSizeBytes: Int64? = nil
        ) {
            self.entryCount = entryCount
            self.includesSchemeModule = includesSchemeModule
            self.contentHash = contentHash
            self.fileSizeBytes = fileSizeBytes
        }
    }

    public var version: Int
    public var workspacePath: String
    public var scheme: String
    public var configuration: String
    public var destination: String
    public var inputs: InputFingerprints
    public var toolchain: ToolchainInfo
    public var compileDatabase: CompileDatabaseInfo?
    public var builtAt: Date?
    public var indexingInProgress: Bool

    public init(
        version: Int = currentVersion,
        workspacePath: String,
        scheme: String,
        configuration: String,
        destination: String,
        inputs: InputFingerprints,
        toolchain: ToolchainInfo = ToolchainInfo(),
        compileDatabase: CompileDatabaseInfo? = nil,
        builtAt: Date? = nil,
        indexingInProgress: Bool = false
    ) {
        self.version = version
        self.workspacePath = workspacePath
        self.scheme = scheme
        self.configuration = configuration
        self.destination = destination
        self.inputs = inputs
        self.toolchain = toolchain
        self.compileDatabase = compileDatabase
        self.builtAt = builtAt
        self.indexingInProgress = indexingInProgress
    }

    public func matchesContext(
        scheme: String,
        configuration: String,
        destination: String,
        inputs: InputFingerprints,
        toolchain: ToolchainInfo
    ) -> Bool {
        self.scheme == scheme
            && self.configuration == configuration
            && self.destination == destination
            && self.inputs == inputs
            && toolchainMatches(toolchain)
    }

    public func toolchainMatches(_ other: ToolchainInfo) -> Bool {
        guard let stored = toolchain.xcodeVersion,
              let current = other.xcodeVersion else {
            return toolchain.xcodeVersion == other.xcodeVersion
        }
        return stored.split(separator: ".").prefix(1) == current.split(separator: ".").prefix(1)
    }

    public var hasValidCompileDatabase: Bool {
        guard let compileDatabase else { return false }
        return compileDatabase.entryCount > 0 && compileDatabase.includesSchemeModule
    }
}

public enum IndexManifestValidation {
    public enum InvalidationReason: Equatable, Sendable {
        case manifestMissing
        case compileDatabaseMissing
        case contextMismatch
        case inputFingerprintChanged
        case toolchainChanged
        case compileDatabaseInvalid
        case indexingInterrupted
    }

    public static func invalidationReasonMetadataOnly(
        manifest: IndexManifest?,
        compileDatabaseURL: URL,
        scheme: String,
        configuration: String,
        destination: String,
        inputs: IndexManifest.InputFingerprints,
        toolchain: IndexManifest.ToolchainInfo
    ) -> InvalidationReason? {
        guard let manifest else { return .manifestMissing }
        guard FileManager.default.fileExists(atPath: compileDatabaseURL.path) else {
            return .compileDatabaseMissing
        }
        if manifest.indexingInProgress { return .indexingInterrupted }
        if !manifest.matchesContext(
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        ) {
            if manifest.scheme != scheme
                || manifest.configuration != configuration
                || manifest.destination != destination {
                return .contextMismatch
            }
            if manifest.inputs != inputs { return .inputFingerprintChanged }
            return .toolchainChanged
        }
        guard manifest.hasValidCompileDatabase else { return .compileDatabaseInvalid }
        if let expectedSize = manifest.compileDatabase?.fileSizeBytes {
            let actualSize = (try? compileDatabaseURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? -1
            if actualSize != expectedSize {
                return .compileDatabaseInvalid
            }
        }
        return nil
    }

    public static func invalidationReason(
        manifest: IndexManifest?,
        compileDatabaseURL: URL,
        scheme: String,
        configuration: String,
        destination: String,
        inputs: IndexManifest.InputFingerprints,
        toolchain: IndexManifest.ToolchainInfo
    ) -> InvalidationReason? {
        invalidationReasonMetadataOnly(
            manifest: manifest,
            compileDatabaseURL: compileDatabaseURL,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        )
    }

    public static func invalidationReasonAsync(
        manifest: IndexManifest?,
        compileDatabaseURL: URL,
        scheme: String,
        configuration: String,
        destination: String,
        inputs: IndexManifest.InputFingerprints,
        toolchain: IndexManifest.ToolchainInfo
    ) async -> InvalidationReason? {
        if let metadataReason = invalidationReasonMetadataOnly(
            manifest: manifest,
            compileDatabaseURL: compileDatabaseURL,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        ) {
            return metadataReason
        }
        let isValid = await CompileDatabaseValidator.isValidForOpen(
            manifest: manifest,
            compileDatabaseURL: compileDatabaseURL,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        )
        return isValid ? nil : .compileDatabaseInvalid
    }

    public static func isCompileDatabaseValid(
        manifest: IndexManifest?,
        compileDatabaseURL: URL,
        scheme: String,
        configuration: String,
        destination: String,
        inputs: IndexManifest.InputFingerprints,
        toolchain: IndexManifest.ToolchainInfo
    ) -> Bool {
        invalidationReason(
            manifest: manifest,
            compileDatabaseURL: compileDatabaseURL,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        ) == nil
    }

    public static func isCompileDatabaseValidAsync(
        manifest: IndexManifest?,
        compileDatabaseURL: URL,
        scheme: String,
        configuration: String,
        destination: String,
        inputs: IndexManifest.InputFingerprints,
        toolchain: IndexManifest.ToolchainInfo
    ) async -> Bool {
        await invalidationReasonAsync(
            manifest: manifest,
            compileDatabaseURL: compileDatabaseURL,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        ) == nil
    }
}

extension IndexManifest {
    public static func compileDatabaseContentHash(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let digest = SHA256.hash(data: data)
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func makeCompileDatabaseInfo(
        at compileURL: URL,
        scheme: String
    ) -> CompileDatabaseInfo? {
        guard let data = try? Data(contentsOf: compileURL),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !array.isEmpty else {
            return nil
        }
        let includesSchemeModule = array.contains { entry in
            let moduleName = (entry["module_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if moduleName == scheme { return true }
            let command = (entry["command"] as? String) ?? ""
            return command.contains("-module-name \(scheme) ")
        }
        return CompileDatabaseInfo(
            entryCount: array.count,
            includesSchemeModule: includesSchemeModule,
            contentHash: compileDatabaseContentHash(at: compileURL),
            fileSizeBytes: fileSizeBytes(at: compileURL)
        )
    }

    static func fileSizeBytes(at url: URL) -> Int64? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return nil }
        return Int64(size)
    }
}
