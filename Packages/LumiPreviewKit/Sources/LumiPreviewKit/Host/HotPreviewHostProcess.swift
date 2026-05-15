import Foundation
import Darwin

public extension LumiPreviewPackage {
    final class HotPreviewHostProcess: Sendable {
        public init() {}

        public func launch(executableURL: URL) async throws -> HotHostConnection {
            guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
                throw LumiPreviewPackage.PreviewError.hostLaunchFailed(
                    message: "Hot host executable is not executable: \(executableURL.path)"
                )
            }

            let process = Process()
            process.executableURL = executableURL
            process.arguments = ["--stdio"]

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                throw LumiPreviewPackage.PreviewError.hostLaunchFailed(message: error.localizedDescription)
            }

            guard process.isRunning else {
                let stderr = String(data: stderrPipe.fileHandleForReading.availableData, encoding: .utf8) ?? ""
                throw LumiPreviewPackage.PreviewError.hostLaunchFailed(
                    message: stderr.isEmpty ? "Hot host process exited immediately." : stderr
                )
            }

            return ProcessHotHostConnection(
                process: process,
                stdin: stdinPipe.fileHandleForWriting,
                stdout: stdoutPipe.fileHandleForReading
            )
        }
    }

    protocol HotHostConnection: AnyObject, Sendable {
        var isRunning: Bool { get async }
        var processID: Int32 { get async }

        @discardableResult
        func requestRender(
            discovery: LumiPreviewPackage.PreviewDiscovery,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration
        ) async throws -> HotRenderResponse

        @discardableResult
        func requestRefresh() async throws -> HotRenderResponse

        @discardableResult
        func requestCaptureFrame(includeImageFallback: Bool) async throws -> HotRenderResponse

        @discardableResult
        func requestLoadPreviewEntry(at dylibURL: URL, symbolName: String) async throws -> HotRenderResponse

        @discardableResult
        func requestInterposeDylib(at dylibURL: URL, symbolName: String?) async throws -> HotRenderResponse

        @discardableResult
        func requestStartLivePreview() async throws -> HotRenderResponse

        @discardableResult
        func requestUpdateLiveFrame(x: Double, y: Double, width: Double, height: Double, scale: Double) async throws -> HotRenderResponse

        @discardableResult
        func requestShowLivePreview() async throws -> HotRenderResponse

        @discardableResult
        func requestHideLivePreview() async throws -> HotRenderResponse

        @discardableResult
        func requestReloadLivePreview(at dylibURL: URL, symbolName: String) async throws -> HotRenderResponse

        @discardableResult
        func requestStopLivePreview() async throws -> HotRenderResponse

        func terminate() async
    }
}

public extension LumiPreviewPackage.HotHostConnection {
    @discardableResult
    func requestCaptureFrame() async throws -> LumiPreviewPackage.HotRenderResponse {
        try await requestCaptureFrame(includeImageFallback: true)
    }
}

private final class ProcessHotHostConnection: LumiPreviewPackage.HotHostConnection, @unchecked Sendable {
    private let process: Process
    private let stdin: FileHandle
    private let stdout: FileHandle
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(process: Process, stdin: FileHandle, stdout: FileHandle) {
        self.process = process
        self.stdin = stdin
        self.stdout = stdout
    }

    var isRunning: Bool {
        get async { process.isRunning }
    }

    var processID: Int32 {
        get async { process.processIdentifier }
    }

    @discardableResult
    func requestRender(
        discovery: LumiPreviewPackage.PreviewDiscovery,
        configuration: LumiPreviewPackage.PreviewRenderConfiguration
    ) async throws -> LumiPreviewPackage.HotRenderResponse {
        let request = LumiPreviewPackage.HotHostRequest(
            command: .render,
            discovery: discovery,
            configuration: configuration
        )
        return try send(request)
    }

    @discardableResult
    func requestRefresh() async throws -> LumiPreviewPackage.HotRenderResponse {
        try send(LumiPreviewPackage.HotHostRequest(command: .refresh))
    }

    @discardableResult
    func requestCaptureFrame(includeImageFallback: Bool) async throws -> LumiPreviewPackage.HotRenderResponse {
        let request = LumiPreviewPackage.HotHostRequest(
            command: .captureFrame,
            captureFrame: LumiPreviewPackage.CaptureFrameRequest(includeImageFallback: includeImageFallback)
        )
        return try send(request)
    }

    @discardableResult
    func requestLoadPreviewEntry(at dylibURL: URL, symbolName: String) async throws -> LumiPreviewPackage.HotRenderResponse {
        let request = LumiPreviewPackage.HotHostRequest(
            command: .loadDylib,
            dylibPath: dylibURL.path,
            previewEntrySymbol: symbolName
        )
        return try send(request)
    }

    @discardableResult
    func requestInterposeDylib(at dylibURL: URL, symbolName: String?) async throws -> LumiPreviewPackage.HotRenderResponse {
        let request = LumiPreviewPackage.HotHostRequest(
            command: .interposeDylib,
            dylibPath: dylibURL.path,
            previewEntrySymbol: symbolName
        )
        return try send(request)
    }

    @discardableResult
    func requestStartLivePreview() async throws -> LumiPreviewPackage.HotRenderResponse {
        try send(LumiPreviewPackage.HotHostRequest(command: .startLivePreview))
    }

    @discardableResult
    func requestUpdateLiveFrame(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        scale: Double
    ) async throws -> LumiPreviewPackage.HotRenderResponse {
        let request = LumiPreviewPackage.HotHostRequest(
            command: .updateLiveFrame,
            liveFrame: LumiPreviewPackage.LiveFrameRequest(x: x, y: y, width: width, height: height, scale: scale)
        )
        return try send(request)
    }

    @discardableResult
    func requestShowLivePreview() async throws -> LumiPreviewPackage.HotRenderResponse {
        try send(LumiPreviewPackage.HotHostRequest(command: .showLivePreview))
    }

    @discardableResult
    func requestHideLivePreview() async throws -> LumiPreviewPackage.HotRenderResponse {
        try send(LumiPreviewPackage.HotHostRequest(command: .hideLivePreview))
    }

    @discardableResult
    func requestReloadLivePreview(at dylibURL: URL, symbolName: String) async throws -> LumiPreviewPackage.HotRenderResponse {
        let request = LumiPreviewPackage.HotHostRequest(
            command: .reloadLivePreview,
            dylibPath: dylibURL.path,
            previewEntrySymbol: symbolName
        )
        return try send(request)
    }

    @discardableResult
    func requestStopLivePreview() async throws -> LumiPreviewPackage.HotRenderResponse {
        try send(LumiPreviewPackage.HotHostRequest(command: .stopLivePreview))
    }

    func terminate() async {
        terminateSync()
    }

    private func terminateSync() {
        lock.lock()
        defer { lock.unlock() }
        try? stdin.close()
        if process.isRunning {
            process.terminate()
            waitForExit(timeout: 1)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            waitForExit(timeout: 1)
        }
    }

    private func waitForExit(timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    private func send(_ request: LumiPreviewPackage.HotHostRequest) throws -> LumiPreviewPackage.HotRenderResponse {
        lock.lock()
        defer { lock.unlock() }

        guard process.isRunning else {
            throw LumiPreviewPackage.PreviewError.hostLaunchFailed(message: "Hot host process is not running.")
        }

        var payload = try encoder.encode(request)
        payload.append(0x0A)

        do {
            try stdin.write(contentsOf: payload)
        } catch {
            throw LumiPreviewPackage.PreviewError.hostLaunchFailed(
                message: "Failed to write to hot host stdin: \(error.localizedDescription)"
            )
        }

        guard let line = try readLineData() else {
            throw LumiPreviewPackage.PreviewError.hostLaunchFailed(message: "Hot host process closed stdout.")
        }

        do {
            let response = try decoder.decode(LumiPreviewPackage.HotRenderResponse.self, from: line)
            guard response.success else {
                throw LumiPreviewPackage.PreviewError.runtimeCrashed(
                    message: response.message ?? "Hot preview host request failed."
                )
            }
            return response
        } catch let error as LumiPreviewPackage.PreviewError {
            throw error
        } catch {
            if let errorResponse = try? decoder.decode(LumiPreviewPackage.ErrorResponse.self, from: line) {
                throw LumiPreviewPackage.PreviewError.runtimeCrashed(message: errorResponse.message)
            }
            throw LumiPreviewPackage.PreviewError.runtimeCrashed(
                message: "Failed to decode hot host response: \(error.localizedDescription)"
            )
        }
    }

    private func readLineData() throws -> Data? {
        var line = Data()

        while true {
            let chunk = stdout.readData(ofLength: 1)
            guard !chunk.isEmpty else {
                return line.isEmpty ? nil : line
            }

            if chunk[0] == 0x0A {
                return line
            }

            line.append(chunk)
        }
    }
}
