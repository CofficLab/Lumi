import Foundation

/// Background semantic indexing that does not mutate active `XcodeBuildContextProvider` UI state.
public enum SemanticIndexBackgroundIndexer {
    public static func warmIfNeeded(workspaceURL: URL, store: XcodeBuildServerStore) async -> Bool {
        guard let metadata = store.loadMetadata(forWorkspace: workspaceURL.path) else { return false }
        guard let serverPath = await XcodeBuildServerLocator.locate() else { return false }

        let scheme = metadata.scheme
        let configuration = "Debug"
        let destination = await MainActor.run {
            XcodeBuildContextProvider.defaultDestination().destinationQuery
        }
        let inputs = await ProjectInputFingerprint.compute(workspaceURL: workspaceURL, schemeName: scheme)
        let toolchain = ProjectInputFingerprint.currentToolchain(
            xcodeBuildServerVersion: XcodeBuildServerLocator.detectedVersion(at: serverPath)
        )
        let compileURL = URL(fileURLWithPath: metadata.compileDatabasePath)
        let manifest = store.loadManifest(forWorkspace: workspaceURL.path)

        if await CompileDatabaseValidator.isValidForOpen(
            manifest: manifest,
            compileDatabaseURL: compileURL,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        ) {
            return true
        }

        if await MainActor.run(body: { SemanticIndexJobController.shared.hasActiveWorkspaceJob }) {
            return false
        }

        let token = await MainActor.run {
            SemanticIndexJobController.shared.beginJob(priority: .preload)
        }
        let result = await Task { @MainActor in
            await SemanticIndexJobController.shared.run(
                generation: token.generation,
                priority: .preload
            ) {
                await runIndexing(
                    workspaceURL: workspaceURL,
                    store: store,
                    metadata: metadata,
                    serverPath: serverPath,
                    scheme: scheme,
                    configuration: configuration,
                    destination: destination,
                    inputs: inputs,
                    toolchain: toolchain
                )
            }
        }.value
        return result.failureReason == nil && !result.wasCancelled
    }

    private static func runIndexing(
        workspaceURL: URL,
        store: XcodeBuildServerStore,
        metadata: XcodeBuildServerStore.Metadata,
        serverPath: String,
        scheme: String,
        configuration: String,
        destination: String,
        inputs: IndexManifest.InputFingerprints,
        toolchain: IndexManifest.ToolchainInfo
    ) async -> SemanticIndexJobResult {
        let storeDirectory = store.ensureDirectory(forWorkspace: workspaceURL.path)
        let compileURL = URL(fileURLWithPath: metadata.compileDatabasePath)
        let manifest = store.loadManifest(forWorkspace: workspaceURL.path)

        store.markIndexingInProgress(
            forWorkspace: workspaceURL.path,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        )

        let derivedDataDirectory = store.derivedDataDirectory(forWorkspace: workspaceURL.path)
        try? FileManager.default.createDirectory(at: derivedDataDirectory, withIntermediateDirectories: true)

        let request = XcodeSemanticIndexRunner.Request(
            workspaceURL: workspaceURL,
            scheme: scheme,
            configuration: configuration,
            destinationQuery: destination,
            storeDirectory: storeDirectory,
            derivedDataDirectory: derivedDataDirectory,
            xcodeBuildServerPath: serverPath,
            buildRoot: metadata.buildRoot
        )

        guard SemanticIndexResourceManager.acquireXcodebuildSlot(priority: .preload) else {
            store.clearInterruptedIndexingFlag(forWorkspace: workspaceURL.path)
            return SemanticIndexJobResult(wasCancelled: true)
        }
        defer { SemanticIndexResourceManager.releaseXcodebuildSlot() }

        SemanticIndexResourceManager.markWorkspaceAccessed(workspaceURL.path)
        _ = await SemanticIndexResourceManager.enforceDiskQuotaAsync(in: store.pluginDirectoryURL)

        let rebuildStrategy = SemanticIndexRebuildPolicy.strategy(
            manifest: manifest,
            inputs: inputs,
            scheme: scheme,
            configuration: configuration,
            destination: destination
        )

        let failureReason: String?
        switch rebuildStrategy {
        case .skip:
            failureReason = nil
        case .parseFromDerivedDataOnly:
            let parsed = await XcodeSemanticIndexRunner.syncCompileDatabaseFromDerivedData(request)
            failureReason = parsed ? nil : "Unable to parse compile database from derived data"
        case .cleanBuildAndParse, .incrementalBuildAndMerge:
            failureReason = await XcodeSemanticIndexRunner.buildAndParseCompileDatabase(request)
        }

        if let failureReason {
            store.clearInterruptedIndexingFlag(forWorkspace: workspaceURL.path)
            return SemanticIndexJobResult(failureReason: failureReason)
        }

        if let buildRoot = XcodeSemanticIndexRunner.discoverBuildRoot(in: derivedDataDirectory) {
            let indexStorePath = XcodeBuildServerStore
                .defaultIndexStorePath(forDerivedDataDirectory: derivedDataDirectory)
                .path
            _ = store.syncParsedCompileDatabaseSettings(
                forWorkspace: workspaceURL.path,
                buildRoot: buildRoot,
                indexStorePath: indexStorePath
            )
        } else {
            _ = store.publishCompileDatabaseForBSP(forWorkspace: workspaceURL.path)
        }
        _ = await store.finalizeManifestAfterIndexing(
            forWorkspace: workspaceURL.path,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain,
            compileDatabaseURL: compileURL
        )
        return SemanticIndexJobResult()
    }
}
