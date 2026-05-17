import Foundation
import Darwin

public extension LumiPreviewFacade {
    /// Hot 预览宿主进程启动器。
    ///
    /// 通过 `Process` 启动 `LumiHotPreviewHostApp` 子进程，
    /// 建立 stdin/stdout 管道通信，传递帧和存储路径环境变量。
    final class HotPreviewHostProcess: Sendable {
        /// 创建宿主进程启动器。
        public init() {}

        /// 启动宿主进程并返回一个基于管道的连接。
        ///
        /// 宿主进程以 `--stdio` 模式启动，通过 stdin/stdout 交换 JSON 行协议消息。
        /// 自动注入帧目录和存储根目录环境变量。
        ///
        /// - Parameter executableURL: `LumiHotPreviewHostApp` 可执行文件路径。
        /// - Returns: 已建立的管道连接。
        /// - Throws: 可执行文件不存在、进程立即退出等错误。
        public func launch(executableURL: URL) async throws -> HotHostConnection {
            guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
                throw LumiPreviewFacade.PreviewError.hostLaunchFailed(
                    message: "Hot host executable is not executable: \(executableURL.path)"
                )
            }

            let process = Process()
            process.executableURL = executableURL
            process.arguments = ["--stdio"]
            var environment = ProcessInfo.processInfo.environment
            let storagePaths = PreviewStorage.paths
            environment[PreviewStoragePaths.framesDirectoryEnvironmentKey] = storagePaths.framesDirectory.path
            environment[PreviewStoragePaths.rootDirectoryEnvironmentKey] = storagePaths.rootDirectory.path
            process.environment = environment

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                throw LumiPreviewFacade.PreviewError.hostLaunchFailed(message: error.localizedDescription)
            }

            guard process.isRunning else {
                let stderr = String(data: stderrPipe.fileHandleForReading.availableData, encoding: .utf8) ?? ""
                throw LumiPreviewFacade.PreviewError.hostLaunchFailed(
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

    /// Hot 预览宿主进程连接协议。
    ///
    /// 定义了与宿主进程通信的所有请求方法，涵盖渲染、帧捕获、dylib 加载和 Live 预览控制。
    /// 每个方法对应一个 `HotHostCommand`，返回宿主进程的 `HotRenderResponse`。
    protocol HotHostConnection: AnyObject, Sendable {
        /// 宿主进程是否仍在运行。
        var isRunning: Bool { get async }
        /// 宿主进程 PID。
        var processID: Int32 { get async }

        /// 请求渲染一个预览。
        @discardableResult
        func requestRender(
            discovery: LumiPreviewFacade.PreviewDiscovery,
            configuration: LumiPreviewFacade.PreviewRenderConfiguration
        ) async throws -> HotRenderResponse

        /// 请求刷新当前预览。
        @discardableResult
        func requestRefresh() async throws -> HotRenderResponse

        /// 请求捕获当前预览帧。
        @discardableResult
        func requestCaptureFrame(includeImageFallback: Bool) async throws -> HotRenderResponse

        /// 请求加载预览入口 dylib。
        @discardableResult
        func requestLoadPreviewEntry(at dylibURL: URL, symbolName: String) async throws -> HotRenderResponse

        /// 请求通过 interpose 替换 dylib 中的符号（热更新优化）。
        @discardableResult
        func requestInterposeDylib(at dylibURL: URL, symbolName: String?) async throws -> HotRenderResponse

        /// 请求启动 Live 预览。
        @discardableResult
        func requestStartLivePreview() async throws -> HotRenderResponse

        /// 请求更新 Live 预览窗口的屏幕坐标和尺寸。
        @discardableResult
        func requestUpdateLiveFrame(x: Double, y: Double, width: Double, height: Double, scale: Double) async throws -> HotRenderResponse

        /// 请求显示 Live 预览窗口。
        @discardableResult
        func requestShowLivePreview() async throws -> HotRenderResponse

        /// 请求隐藏 Live 预览窗口。
        @discardableResult
        func requestHideLivePreview() async throws -> HotRenderResponse

        /// 请求重新加载 Live 预览（加载新 dylib）。
        @discardableResult
        func requestReloadLivePreview(at dylibURL: URL, symbolName: String) async throws -> HotRenderResponse

        /// 请求停止 Live 预览。
        @discardableResult
        func requestStopLivePreview() async throws -> HotRenderResponse

        /// 终止宿主进程。
        func terminate() async
    }
}

public extension LumiPreviewFacade.HotHostConnection {
    @discardableResult
    func requestCaptureFrame() async throws -> LumiPreviewFacade.HotRenderResponse {
        try await requestCaptureFrame(includeImageFallback: true)
    }
}

/// 基于 `Process` 管道的 `HotHostConnection` 实现。
///
/// 通过 stdin/stdout 管道与宿主进程交换 JSON 行协议消息。
/// 所有操作通过 `NSLock` 序列化，保证线程安全。
/// 发送请求后同步等待响应，超时时间默认 120 秒。
private final class ProcessHotHostConnection: LumiPreviewFacade.HotHostConnection, @unchecked Sendable {
    private let process: Process
    private let stdin: FileHandle
    private let stdout: FileHandle
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let responseTimeout: TimeInterval
    private var stdoutBuffer = Data()

    init(
        process: Process,
        stdin: FileHandle,
        stdout: FileHandle,
        responseTimeout: TimeInterval = 120
    ) {
        self.process = process
        self.stdin = stdin
        self.stdout = stdout
        self.responseTimeout = responseTimeout
    }

    var isRunning: Bool {
        get async { process.isRunning }
    }

    var processID: Int32 {
        get async { process.processIdentifier }
    }

    @discardableResult
    func requestRender(
        discovery: LumiPreviewFacade.PreviewDiscovery,
        configuration: LumiPreviewFacade.PreviewRenderConfiguration
    ) async throws -> LumiPreviewFacade.HotRenderResponse {
        let request = LumiPreviewFacade.HotHostRequest(
            command: .render,
            discovery: discovery,
            configuration: configuration
        )
        return try send(request)
    }

    @discardableResult
    func requestRefresh() async throws -> LumiPreviewFacade.HotRenderResponse {
        try send(LumiPreviewFacade.HotHostRequest(command: .refresh))
    }

    @discardableResult
    func requestCaptureFrame(includeImageFallback: Bool) async throws -> LumiPreviewFacade.HotRenderResponse {
        let request = LumiPreviewFacade.HotHostRequest(
            command: .captureFrame,
            captureFrame: LumiPreviewFacade.CaptureFrameRequest(includeImageFallback: includeImageFallback)
        )
        return try send(request)
    }

    @discardableResult
    func requestLoadPreviewEntry(at dylibURL: URL, symbolName: String) async throws -> LumiPreviewFacade.HotRenderResponse {
        let request = LumiPreviewFacade.HotHostRequest(
            command: .loadDylib,
            dylibPath: dylibURL.path,
            previewEntrySymbol: symbolName
        )
        return try send(request)
    }

    @discardableResult
    func requestInterposeDylib(at dylibURL: URL, symbolName: String?) async throws -> LumiPreviewFacade.HotRenderResponse {
        let request = LumiPreviewFacade.HotHostRequest(
            command: .interposeDylib,
            dylibPath: dylibURL.path,
            previewEntrySymbol: symbolName
        )
        return try send(request)
    }

    @discardableResult
    func requestStartLivePreview() async throws -> LumiPreviewFacade.HotRenderResponse {
        try send(LumiPreviewFacade.HotHostRequest(command: .startLivePreview))
    }

    @discardableResult
    func requestUpdateLiveFrame(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        scale: Double
    ) async throws -> LumiPreviewFacade.HotRenderResponse {
        let request = LumiPreviewFacade.HotHostRequest(
            command: .updateLiveFrame,
            liveFrame: LumiPreviewFacade.LiveFrameRequest(x: x, y: y, width: width, height: height, scale: scale)
        )
        return try send(request)
    }

    @discardableResult
    func requestShowLivePreview() async throws -> LumiPreviewFacade.HotRenderResponse {
        try send(LumiPreviewFacade.HotHostRequest(command: .showLivePreview))
    }

    @discardableResult
    func requestHideLivePreview() async throws -> LumiPreviewFacade.HotRenderResponse {
        try send(LumiPreviewFacade.HotHostRequest(command: .hideLivePreview))
    }

    @discardableResult
    func requestReloadLivePreview(at dylibURL: URL, symbolName: String) async throws -> LumiPreviewFacade.HotRenderResponse {
        let request = LumiPreviewFacade.HotHostRequest(
            command: .reloadLivePreview,
            dylibPath: dylibURL.path,
            previewEntrySymbol: symbolName
        )
        return try send(request)
    }

    @discardableResult
    func requestStopLivePreview() async throws -> LumiPreviewFacade.HotRenderResponse {
        try send(LumiPreviewFacade.HotHostRequest(command: .stopLivePreview))
    }

    func terminate() async {
        terminateSync()
    }

    private func terminateSync() {
        lock.lock()
        defer { lock.unlock() }
        terminateWithoutLock()
    }

    private func terminateWithoutLock() {
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

    private func send(_ request: LumiPreviewFacade.HotHostRequest) throws -> LumiPreviewFacade.HotRenderResponse {
        lock.lock()
        defer { lock.unlock() }

        guard process.isRunning else {
            throw LumiPreviewFacade.PreviewError.hostLaunchFailed(message: "Hot host process is not running.")
        }

        var payload = try encoder.encode(request)
        payload.append(0x0A)

        do {
            try stdin.write(contentsOf: payload)
        } catch {
            throw LumiPreviewFacade.PreviewError.hostLaunchFailed(
                message: "Failed to write to hot host stdin: \(error.localizedDescription)"
            )
        }

        let line: Data?
        do {
            line = try readLineData(timeout: responseTimeout)
        } catch {
            terminateWithoutLock()
            throw error
        }

        guard let line else {
            throw LumiPreviewFacade.PreviewError.hostLaunchFailed(message: "Hot host process closed stdout.")
        }

        do {
            let response = try decoder.decode(LumiPreviewFacade.HotRenderResponse.self, from: line)
            guard response.success else {
                throw LumiPreviewFacade.PreviewError.runtimeCrashed(
                    message: response.message ?? "Hot preview host request failed."
                )
            }
            return response
        } catch let error as LumiPreviewFacade.PreviewError {
            throw error
        } catch {
            if let errorResponse = try? decoder.decode(LumiPreviewFacade.ErrorResponse.self, from: line) {
                throw LumiPreviewFacade.PreviewError.runtimeCrashed(message: errorResponse.message)
            }
            throw LumiPreviewFacade.PreviewError.runtimeCrashed(
                message: "Failed to decode hot host response: \(error.localizedDescription)"
            )
        }
    }

    private func readLineData(timeout: TimeInterval) throws -> Data? {
        while true {
            if let line = popBufferedLine() {
                return line
            }

            let chunk = try readStdoutChunk(timeout: timeout)
            guard !chunk.isEmpty else {
                if stdoutBuffer.isEmpty {
                    return nil
                }
                let line = stdoutBuffer
                stdoutBuffer.removeAll(keepingCapacity: true)
                return line
            }

            stdoutBuffer.append(chunk)
        }
    }

    private func popBufferedLine() -> Data? {
        guard let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) else {
            return nil
        }

        let line = stdoutBuffer[..<newlineIndex]
        stdoutBuffer.removeSubrange(...newlineIndex)
        return Data(line)
    }

    private func readStdoutChunk(timeout: TimeInterval) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        let result = StdoutChunkReadResult()

        DispatchQueue.global(qos: .userInitiated).async { [stdout] in
            let chunk = stdout.availableData
            result.store(.success(chunk))
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw LumiPreviewFacade.PreviewError.runtimeCrashed(
                message: "Timed out waiting for hot host response after \(Int(timeout))s."
            )
        }

        return try result.load()?.get() ?? Data()
    }
}

private final class StdoutChunkReadResult: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Data, Error>?

    func store(_ result: Result<Data, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func load() -> Result<Data, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}
