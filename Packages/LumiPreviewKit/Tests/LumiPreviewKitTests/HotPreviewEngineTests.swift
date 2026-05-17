import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("HotPreviewEngine")
struct HotPreviewEngineTests {
    @Test("0.1 discoverPreviews returns empty array for missing file")
    func discoverPreviewsReturnsEmptyForMissingFile() async {
        let engine = FakeHotHostConnectionFactory.makeEngine()
        let missingURL = URL(fileURLWithPath: "/tmp/LumiPreviewKit-missing-\(UUID().uuidString).swift")
        let discoveries = await engine.discoverPreviews(in: missingURL)
        #expect(discoveries.isEmpty)
    }

    @Test("0.2 discoverPreviews matches PreviewScanner output")
    func discoverPreviewsMatchesScanner() async throws {
        let directory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("Preview.swift")
        let source = """
        import SwiftUI

        #Preview("Card") {
            Text("Hello")
        }
        """
        try source.write(to: fileURL, atomically: true, encoding: .utf8)

        let engine = FakeHotHostConnectionFactory.makeEngine()
        let discoveries = await engine.discoverPreviews(in: fileURL)
        let scanner = LumiPreviewFacade.PreviewScanner()
        let expected = scanner.scan(fileURL: fileURL, sourceText: source)

        #expect(discoveries.count == expected.count)
        #expect(discoveries.first?.title == expected.first?.title)
        #expect(discoveries.first?.lineNumber == expected.first?.lineNumber)
    }

    @Test("0.3 startPreview fails syntax preflight and marks session failed")
    func startPreviewFailsSyntaxPreflight() async throws {
        let directory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("Broken.swift")
        try "struct Broken {".write(to: fileURL, atomically: true, encoding: .utf8)

        let discovery = PreviewDiscoveryFixtures.makeDiscovery(
            fileURL: fileURL,
            bodySource: "Text(\"x\")",
            sourceText: try String(contentsOf: fileURL, encoding: .utf8)
        )
        let engine = FakeHotHostConnectionFactory.makeEngine(
            syntaxChecker: LumiPreviewFacade.SyntaxChecker(
                swiftcPath: "/usr/bin/false",
                runner: InvalidSyntaxCommandRunner()
            )
        )

        do {
            _ = try await engine.startPreview(discovery)
            Issue.record("Expected syntax preflight to fail")
        } catch let error as LumiPreviewFacade.PreviewError {
            if case .compilationFailed = error {
                #expect(Bool(true))
            } else {
                Issue.record("Unexpected PreviewError: \(error)")
            }
        }
    }

    @Test("0.5 wraps non-PreviewError from host launch as runtimeCrashed")
    func wrapsNonPreviewErrorAsRuntimeCrashed() async throws {
        let directory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (_, sourceFiles) = try TemporaryProjectFixtures.makeSPMPackage(
            in: directory,
            previewFiles: [("View", "View")]
        )
        let fileURL = try #require(sourceFiles.first)

        let discovery = PreviewDiscoveryFixtures.makeDiscovery(
            fileURL: fileURL,
            bodySource: "ViewView()",
            title: "View"
        )
        let manager = LumiPreviewFacade.HostProcessManager(
            executableURL: URL(fileURLWithPath: "/tmp/FakeHotHost"),
            launcher: { _ -> any LumiPreviewFacade.HotHostConnection in
                throw NSError(domain: "HotPreviewEngineTests", code: 42)
            },
            isRunning: { await $0.isRunning },
            terminate: { await $0.terminate() },
            identity: { connection in
                ObjectIdentifier(connection as AnyObject)
            }
        )
        let engine = LumiPreviewFacade.HotPreviewEngine(
            hostExecutableURL: URL(fileURLWithPath: "/tmp/FakeHotHost"),
            hostProcessManager: manager,
            syntaxChecker: LumiPreviewFacade.SyntaxChecker(
                swiftcPath: "/usr/bin/false",
                runner: ValidSyntaxCommandRunner()
            )
        )

        do {
            _ = try await engine.startPreview(discovery)
            Issue.record("Expected host launch failure")
        } catch let error as LumiPreviewFacade.PreviewError {
            if case .runtimeCrashed(let message) = error {
                #expect(!message.isEmpty)
            } else {
                Issue.record("Unexpected PreviewError: \(error)")
            }
        }
    }

    @Test("0.10 prewarmPreviewEntry uses cached entry without host calls")
    func prewarmUsesCachedEntry() async throws {
        let directory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (_, sourceFiles) = try TemporaryProjectFixtures.makeSPMPackage(
            in: directory,
            previewFiles: [("Cached", "Cached")]
        )
        let fileURL = try #require(sourceFiles.first)

        let cacheDirectory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let entryCache = LumiPreviewFacade.EntryCacheManager(cacheRootDirectory: cacheDirectory, maximumEntryCount: 4)
        let discovery = PreviewDiscoveryFixtures.makeDiscovery(fileURL: fileURL, bodySource: "CachedView()")
        let strategy = LumiPreviewFacade.BuildStrategy.spm(
            packageDirectory: directory,
            targetName: "App"
        )
        let dylibURL = cacheDirectory.appendingPathComponent("PreviewEntry.dylib")
        try Data("dylib".utf8).write(to: dylibURL)
        let cacheKey = await entryCache.makeCacheKey(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: strategy,
            entryVariant: "source-include"
        )
        await entryCache.storeEntryURL(dylibURL, for: cacheKey)

        let connection = FakeHotHostConnection()
        let engine = FakeHotHostConnectionFactory.makeEngine(
            connection: connection,
            entryCacheManager: entryCache
        )

        let usedCache = try await engine.prewarmPreviewEntry(discovery)
        #expect(usedCache)
        #expect(connection.loadCallCount == 0)
    }

    @Test("0.12 stopPreview releases host connection")
    func stopPreviewReleasesConnection() async throws {
        let connection = FakeHotHostConnection()
        let manager = FakeHotHostConnectionFactory.makeHostProcessManager(connection: connection)
        let engine = LumiPreviewFacade.HotPreviewEngine(
            hostExecutableURL: URL(fileURLWithPath: "/tmp/FakeHotHost"),
            hostProcessManager: manager
        )
        _ = try await manager.acquire()

        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: PreviewDiscoveryFixtures.makeDiscovery()
        )
        await session.setHostConnection(connection)
        await engine.stopPreview(session)

        #expect(await manager.managedConnectionCount == 1)
        #expect(await manager.idleConnectionCount == 1)
        #expect(await session.hostConnection() == nil)
        if case .stopped = await session.state {
            #expect(Bool(true))
        } else {
            Issue.record("Expected stopped session state")
        }
    }

    @Test("0.13 capturePreviewFrame uses capture command only")
    func capturePreviewFrameUsesCaptureCommand() async throws {
        let connection = FakeHotHostConnection()
        let engine = FakeHotHostConnectionFactory.makeEngine(connection: connection)
        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: PreviewDiscoveryFixtures.makeDiscovery()
        )
        await session.setHostConnection(connection)

        let response = try await engine.capturePreviewFrame(session)

        #expect(response.success)
        #expect(connection.captureCallCount == 1)
        #expect(connection.loadCallCount == 0)
    }

    @Test("0.14 live preview commands follow expected order")
    func livePreviewCommandOrder() async throws {
        let connection = FakeHotHostConnection()
        let engine = FakeHotHostConnectionFactory.makeEngine(connection: connection)
        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: PreviewDiscoveryFixtures.makeDiscovery()
        )
        await session.setHostConnection(connection)

        try await engine.startLivePreview(session)
        #expect(await session.displayMode == .live)
        #expect(await session.livePreviewInfo.state == .running)

        try await engine.updateLiveFrame(session, x: 1, y: 2, width: 320, height: 180, scale: 2)
        try await engine.showLivePreview(session)
        try await engine.hideLivePreview(session)
        try await engine.stopLivePreview(session)

        #expect(connection.recordedActions == [
            "startLivePreview",
            "updateLiveFrame",
            "showLivePreview",
            "hideLivePreview",
            "stopLivePreview",
        ])
    }

    @Test("0.15 warmupHost and shutdownHosts delegate to HostProcessManager")
    func warmupAndShutdownHosts() async throws {
        let connection = FakeHotHostConnection()
        let manager = FakeHotHostConnectionFactory.makeHostProcessManager(connection: connection)
        let engine = LumiPreviewFacade.HotPreviewEngine(
            hostExecutableURL: URL(fileURLWithPath: "/tmp/FakeHotHost"),
            hostProcessManager: manager
        )

        try await engine.warmupHost()
        #expect(await manager.idleConnectionCount == 1)

        await engine.shutdownHosts()
        #expect(await manager.managedConnectionCount == 0)
        #expect(connection.terminateCount == 1)
    }

    @Test("0.7 refresh after body change reloads preview entry")
    func refreshAfterBodyChangeReloadsEntry() async throws {
        let connection = FakeHotHostConnection()
        let fileURL = URL(fileURLWithPath: "/tmp/RefreshBody.swift")
        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: PreviewDiscoveryFixtures.makeDiscovery(
                fileURL: fileURL,
                bodySource: "Text(\"A\")"
            )
        )
        await session.setHostConnection(connection)
        await session.setLoadedPreviewBodySource("Text(\"A\")")
        await session.updateDiscovery(
            PreviewDiscoveryFixtures.makeDiscovery(
                fileURL: fileURL,
                bodySource: "Text(\"B\")"
            )
        )

        #expect(await session.loadedPreviewBodySource() == "Text(\"A\")")
        #expect(await session.discovery.bodySource == "Text(\"B\")")
    }
}
