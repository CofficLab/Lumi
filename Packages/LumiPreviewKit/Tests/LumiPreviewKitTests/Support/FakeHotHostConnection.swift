import Foundation
import LumiPreviewKit

final class FakeHotHostConnection: LumiPreviewFacade.HotHostConnection, @unchecked Sendable {
    private let lock = NSLock()
    private var running = true
    private var pid: Int32
    private var terminationCount = 0

    private(set) var renderCallCount = 0
    private(set) var refreshCallCount = 0
    private(set) var captureCallCount = 0
    private(set) var loadCallCount = 0
    private(set) var startLiveCallCount = 0
    private(set) var updateLiveFrameCallCount = 0
    private(set) var showLiveCallCount = 0
    private(set) var hideLiveCallCount = 0
    private(set) var stopLiveCallCount = 0
    private(set) var recordedActions: [String] = []

    var loadThrows: (any Error)?
    var refreshThrows: (any Error)?

    init(processID: Int32 = 101) {
        self.pid = processID
    }

    var isRunning: Bool {
        get async {
            lock.withLock { running }
        }
    }

    var processID: Int32 {
        get async {
            lock.withLock { pid }
        }
    }

    var terminateCount: Int {
        lock.withLock { terminationCount }
    }

    func setRunning(_ value: Bool) {
        lock.withLock {
            running = value
        }
    }

    private func record(_ action: String) {
        lock.withLock {
            recordedActions.append(action)
        }
    }

    func requestRender(
        discovery: LumiPreviewFacade.PreviewDiscovery,
        configuration: LumiPreviewFacade.PreviewRenderConfiguration
    ) async throws -> LumiPreviewFacade.HotRenderResponse {
        record("render")
        renderCallCount += 1
        return LumiPreviewFacade.HotRenderResponse(success: true, previewID: discovery.id)
    }

    func requestRefresh() async throws -> LumiPreviewFacade.HotRenderResponse {
        record("refresh")
        refreshCallCount += 1
        if let refreshThrows {
            throw refreshThrows
        }
        return LumiPreviewFacade.HotRenderResponse(success: true)
    }

    func requestCaptureFrame(includeImageFallback: Bool = true) async throws -> LumiPreviewFacade.HotRenderResponse {
        record("captureFrame")
        captureCallCount += 1
        return LumiPreviewFacade.HotRenderResponse(
            success: true,
            previewImagePNGBase64: includeImageFallback ? "aGk=" : nil
        )
    }

    func requestLoadPreviewEntry(at dylibURL: URL, symbolName: String) async throws -> LumiPreviewFacade.HotRenderResponse {
        record("loadDylib")
        loadCallCount += 1
        if let loadThrows {
            throw loadThrows
        }
        return LumiPreviewFacade.HotRenderResponse(success: true, livePreviewEnabled: true, liveWindowNumber: 7)
    }

    func requestInterposeDylib(at dylibURL: URL, symbolName: String?) async throws -> LumiPreviewFacade.HotRenderResponse {
        record("interposeDylib")
        return LumiPreviewFacade.HotRenderResponse(success: true, livePreviewEnabled: true, liveWindowNumber: 7)
    }

    func requestStartLivePreview() async throws -> LumiPreviewFacade.HotRenderResponse {
        record("startLivePreview")
        startLiveCallCount += 1
        return LumiPreviewFacade.HotRenderResponse(success: true, livePreviewEnabled: true, liveWindowNumber: 7)
    }

    func requestUpdateLiveFrame(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        scale: Double
    ) async throws -> LumiPreviewFacade.HotRenderResponse {
        record("updateLiveFrame")
        updateLiveFrameCallCount += 1
        return LumiPreviewFacade.HotRenderResponse(success: true, livePreviewEnabled: true, liveWindowNumber: 7)
    }

    func requestShowLivePreview() async throws -> LumiPreviewFacade.HotRenderResponse {
        record("showLivePreview")
        showLiveCallCount += 1
        return LumiPreviewFacade.HotRenderResponse(success: true, livePreviewEnabled: true, liveWindowNumber: 7)
    }

    func requestHideLivePreview() async throws -> LumiPreviewFacade.HotRenderResponse {
        record("hideLivePreview")
        hideLiveCallCount += 1
        return LumiPreviewFacade.HotRenderResponse(success: true, livePreviewEnabled: true, liveWindowNumber: 7)
    }

    func requestReloadLivePreview(at dylibURL: URL, symbolName: String) async throws -> LumiPreviewFacade.HotRenderResponse {
        record("reloadLivePreview")
        return LumiPreviewFacade.HotRenderResponse(success: true, livePreviewEnabled: true, liveWindowNumber: 7)
    }

    func requestStopLivePreview() async throws -> LumiPreviewFacade.HotRenderResponse {
        record("stopLivePreview")
        stopLiveCallCount += 1
        return LumiPreviewFacade.HotRenderResponse(success: true)
    }

    func terminate() async {
        lock.withLock {
            terminationCount += 1
            running = false
        }
    }
}

enum FakeHotHostConnectionFactory {
    static func makeHostProcessManager(
        connection: FakeHotHostConnection = FakeHotHostConnection()
    ) -> LumiPreviewFacade.HostProcessManager<any LumiPreviewFacade.HotHostConnection> {
        LumiPreviewFacade.HostProcessManager(
            executableURL: URL(fileURLWithPath: "/tmp/FakeHotHost"),
            launcher: { _ -> any LumiPreviewFacade.HotHostConnection in connection },
            isRunning: { await $0.isRunning },
            terminate: { await $0.terminate() },
            identity: { connection in
                ObjectIdentifier(connection as AnyObject)
            }
        )
    }

    static func makeEngine(
        connection: FakeHotHostConnection = FakeHotHostConnection(),
        entryCacheManager: LumiPreviewFacade.EntryCacheManager? = nil,
        syntaxChecker: LumiPreviewFacade.SyntaxChecker? = nil,
        importEntryFallbackCache: LumiPreviewFacade.ImportEntryFallbackCache? = nil
    ) -> LumiPreviewFacade.HotPreviewEngine {
        LumiPreviewFacade.HotPreviewEngine(
            hostExecutableURL: URL(fileURLWithPath: "/tmp/FakeHotHost"),
            hostProcessManager: makeHostProcessManager(connection: connection),
            entryCacheManager: entryCacheManager ?? .init(),
            importEntryFallbackCache: importEntryFallbackCache ?? .init(),
            syntaxChecker: syntaxChecker ?? LumiPreviewFacade.SyntaxChecker(
                swiftcPath: "/usr/bin/false",
                runner: ValidSyntaxCommandRunner()
            )
        )
    }
}

struct ValidSyntaxCommandRunner: LumiPreviewFacade.CommandRunning {
    func run(_ command: [String]) async throws -> LumiPreviewFacade.CommandResult {
        LumiPreviewFacade.CommandResult(exitCode: 0)
    }
}

struct InvalidSyntaxCommandRunner: LumiPreviewFacade.CommandRunning {
    func run(_ command: [String]) async throws -> LumiPreviewFacade.CommandResult {
        LumiPreviewFacade.CommandResult(exitCode: 1, standardError: "syntax error")
    }
}
