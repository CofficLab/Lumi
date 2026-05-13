import Foundation
import LumiPreviewKit
import Testing
@testable import LumiHotPreviewKit

@Suite("HostProcessManager")
struct HostProcessManagerTests {
    @Test("warmup creates a reusable idle connection")
    func warmupCreatesReusableIdleConnection() async throws {
        let tracker = LaunchTracker()
        let manager = LumiHotPreviewPackage.HostProcessManager(
            executableURL: URL(fileURLWithPath: "/tmp/FakeHost"),
            launcher: tracker.launcher,
            isRunning: { await $0.isRunning },
            terminate: { await $0.terminate() },
            identity: { ObjectIdentifier($0) }
        )

        try await manager.warmup()

        #expect(await tracker.launchCount == 1)
        #expect(await manager.managedConnectionCount == 1)
        #expect(await manager.idleConnectionCount == 1)

        let connection = try await manager.acquire()

        #expect(await tracker.launchCount == 1)
        #expect(await manager.managedConnectionCount == 1)
        #expect(await manager.idleConnectionCount == 0)

        await manager.release(connection)
        #expect(await manager.idleConnectionCount == 1)
    }

    @Test("acquire launches when no idle connection is available")
    func acquireLaunchesWhenNoIdleConnectionExists() async throws {
        let tracker = LaunchTracker()
        let manager = LumiHotPreviewPackage.HostProcessManager(
            executableURL: URL(fileURLWithPath: "/tmp/FakeHost"),
            launcher: tracker.launcher,
            isRunning: { await $0.isRunning },
            terminate: { await $0.terminate() },
            identity: { ObjectIdentifier($0) }
        )

        _ = try await manager.acquire()
        _ = try await manager.acquire()

        #expect(await tracker.launchCount == 2)
        #expect(await manager.managedConnectionCount == 2)
    }

    @Test("release trims excess idle connections")
    func releaseTrimsExcessIdleConnections() async throws {
        let tracker = LaunchTracker()
        let manager = LumiHotPreviewPackage.HostProcessManager(
            executableURL: URL(fileURLWithPath: "/tmp/FakeHost"),
            maximumIdleConnections: 1,
            launcher: tracker.launcher,
            isRunning: { await $0.isRunning },
            terminate: { await $0.terminate() },
            identity: { ObjectIdentifier($0) }
        )

        let first = try await manager.acquire()
        let second = try await manager.acquire()

        await manager.release(first)
        await manager.release(second)

        #expect(await manager.managedConnectionCount == 1)
        #expect(await manager.idleConnectionCount == 1)
        let connections = await tracker.connections
        #expect(connections[1].terminateCount == 1)
    }

    @Test("shutdown terminates every managed connection")
    func shutdownTerminatesEveryManagedConnection() async throws {
        let tracker = LaunchTracker()
        let manager = LumiHotPreviewPackage.HostProcessManager(
            executableURL: URL(fileURLWithPath: "/tmp/FakeHost"),
            launcher: tracker.launcher,
            isRunning: { await $0.isRunning },
            terminate: { await $0.terminate() },
            identity: { ObjectIdentifier($0) }
        )

        _ = try await manager.acquire()
        _ = try await manager.acquire()

        await manager.shutdown()

        #expect(await manager.managedConnectionCount == 0)
        let connections = await tracker.connections
        #expect(connections[0].terminateCount == 1)
        #expect(connections[1].terminateCount == 1)
    }

    @Test("stopped idle connections are pruned before acquire")
    func stoppedIdleConnectionsArePrunedBeforeAcquire() async throws {
        let tracker = LaunchTracker()
        let manager = LumiHotPreviewPackage.HostProcessManager(
            executableURL: URL(fileURLWithPath: "/tmp/FakeHost"),
            launcher: tracker.launcher,
            isRunning: { await $0.isRunning },
            terminate: { await $0.terminate() },
            identity: { ObjectIdentifier($0) }
        )

        let first = try await manager.acquire()
        await manager.release(first)
        let connections = await tracker.connections
        connections[0].setRunning(false)

        _ = try await manager.acquire()

        #expect(await tracker.launchCount == 2)
        #expect(await manager.managedConnectionCount == 1)
    }

    @Test("discard removes and terminates a broken connection")
    func discardRemovesAndTerminatesBrokenConnection() async throws {
        let tracker = LaunchTracker()
        let manager = LumiHotPreviewPackage.HostProcessManager(
            executableURL: URL(fileURLWithPath: "/tmp/FakeHost"),
            launcher: tracker.launcher,
            isRunning: { await $0.isRunning },
            terminate: { await $0.terminate() },
            identity: { ObjectIdentifier($0) }
        )

        let connection = try await manager.acquire()

        await manager.discard(connection)

        #expect(await manager.managedConnectionCount == 0)
        let connections = await tracker.connections
        #expect(connections[0].terminateCount == 1)
    }
}

private actor LaunchTracker {
    private(set) var launchCount = 0
    private var nextPID: Int32 = 100
    private(set) var connections: [FakeHostConnection] = []

    func launcher(_ executableURL: URL) async throws -> LumiPreviewPackage.HostConnection {
        launchCount += 1
        nextPID += 1
        let connection = FakeHostConnection(processID: nextPID)
        connections.append(connection)
        return connection
    }
}

private final class FakeHostConnection: LumiPreviewPackage.HostConnection, @unchecked Sendable {
    private let lock = NSLock()
    private var running = true
    private var pid: Int32
    private var terminationCount = 0

    init(processID: Int32) {
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

    func requestRender(
        discovery: LumiPreviewPackage.PreviewDiscovery,
        configuration: LumiPreviewPackage.PreviewRenderConfiguration
    ) async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestRefresh() async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestCaptureFrame(includeImageFallback: Bool) async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestLoadDylib(at dylibURL: URL) async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestLoadPreviewEntry(at dylibURL: URL, symbolName: String) async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestStartLivePreview() async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestUpdateLiveFrame(x: Double, y: Double, width: Double, height: Double, scale: Double) async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestShowLivePreview() async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestHideLivePreview() async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestReloadLivePreview(at dylibURL: URL, symbolName: String) async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestStopLivePreview() async throws -> LumiPreviewPackage.RenderResponse {
        LumiPreviewPackage.RenderResponse(success: true)
    }

    func terminate() async {
        lock.withLock {
            terminationCount += 1
            running = false
        }
    }
}
