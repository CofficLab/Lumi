import Foundation
import LumiCoreKit
import os
import SuperLogKit
import XcodeKit

enum EditorXcodeProjectPreloader: SuperLog {
    private static let logPrefix = "🚀 "

    public static func filterXcodeProjects(_ projects: [ProjectEntry]) async -> [ProjectEntry] {
        await Task.detached(priority: .utility) {
            projects.filter { project in
                let isXcodeProject = XcodeProjectResolver.isXcodeProjectRoot(URL(fileURLWithPath: project.path))
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(Self.t)\(logPrefix)检查最近项目：\(project.name) -> isXcodeProject=\(isXcodeProject)")
                }
                return isXcodeProject
            }
        }.value
    }

    @MainActor
    public static func preloadProject(
        _ project: ProjectEntry,
        store: XcodeBuildServerStore,
        activeProjectPath: String?
    ) async -> Bool {
        guard SemanticIndexPreloadCoordinator.shouldContinuePreloading(
            activeProjectPath: activeProjectPath,
            projectPath: project.path
        ) else {
            return false
        }
        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("\(Self.t)\(logPrefix)开始预加载项目：\(project.name)，path=\(project.path)")
        }
        guard let workspaceURL = await XcodeProjectBackgroundQuery.findWorkspace(in: project.path) else {
            return false
        }

        let configReady: Bool
        if store.validate(forWorkspace: workspaceURL.path) != nil {
            configReady = true
        } else {
            configReady = await Task.detached(priority: .background) {
                await generateBuildServer(for: workspaceURL, projectName: project.name, store: store)
            }.value
        }

        guard configReady else { return false }

        let scheme = store.load(forWorkspace: workspaceURL.path)?.scheme
        let inputs = await ProjectInputFingerprint.compute(workspaceURL: workspaceURL, schemeName: scheme)
        let toolchain = ProjectInputFingerprint.currentToolchain(
            xcodeBuildServerVersion: XcodeBuildServerLocator.detectedVersion(
                at: XcodeBuildServerLocator.locateSync() ?? ""
            )
        )
        let compileURL = store.compileDatabaseURL(forWorkspace: workspaceURL.path)
        let manifest = store.loadManifest(forWorkspace: workspaceURL.path)
        let configuration = "Debug"
        let destination = XcodeBuildContextProvider.defaultDestination().destinationQuery

        if await IndexManifestValidation.isCompileDatabaseValidAsync(
            manifest: manifest,
            compileDatabaseURL: compileURL,
            scheme: scheme ?? manifest?.scheme ?? "",
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        ) {
            return true
        }

        return await SemanticIndexBackgroundIndexer.warmIfNeeded(workspaceURL: workspaceURL, store: store)
    }

    private static func generateBuildServer(for workspaceURL: URL, projectName: String, store: XcodeBuildServerStore) async -> Bool {
        guard let serverPath = await XcodeBuildServerLocator.locate() else { return false }

        let schemes = await XcodeSchemeFetcher.fetchAvailableSchemes(for: workspaceURL)
        guard let scheme = schemes.first else { return false }

        let outputDirectory = store.ensureDirectory(forWorkspace: workspaceURL.path)
        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let workspaceArg = isProject ? "-project" : "-workspace"
        let args = ["config", workspaceArg, workspaceURL.path, "-scheme", scheme]

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: serverPath)
            process.arguments = args
            process.currentDirectoryURL = outputDirectory
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { _ in
                continuation.resume(returning: process.terminationStatus == 0)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
