import Foundation

/// 预览宿主进程管理器：负责启动和管理独立的预览进程。
public final class PreviewHostProcess: Sendable {
    /// 创建预览宿主进程管理器。
    public init() {}

    /// 启动预览宿主进程。
    ///
    /// - Parameter executableURL: `LumiPreviewHostApp` 可执行文件路径。
    /// - Returns: 可用于发送渲染和刷新命令的宿主连接。
    public func launch(executableURL: URL) async throws -> HostConnection {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw PreviewError.hostLaunchFailed(message: "Host executable is not executable: \(executableURL.path)")
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
            throw PreviewError.hostLaunchFailed(message: error.localizedDescription)
        }

        guard process.isRunning else {
            let stderr = String(
                data: stderrPipe.fileHandleForReading.availableData,
                encoding: .utf8
            ) ?? ""
            throw PreviewError.hostLaunchFailed(message: stderr.isEmpty ? "Host process exited immediately." : stderr)
        }

        return ProcessHostConnection(
            process: process,
            stdin: stdinPipe.fileHandleForWriting,
            stdout: stdoutPipe.fileHandleForReading
        )
    }
}

/// 宿主进程连接。
public protocol HostConnection: AnyObject, Sendable {
    /// 宿主进程是否仍在运行。
    var isRunning: Bool { get async }

    /// 发送渲染请求。
    @discardableResult
    func requestRender(
        discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration
    ) async throws -> RenderResponse

    /// 请求刷新。
    @discardableResult
    func requestRefresh() async throws -> RenderResponse

    /// 请求宿主进程加载一个已签名 dylib。
    @discardableResult
    func requestLoadDylib(at dylibURL: URL) async throws -> RenderResponse

    /// 请求宿主进程加载 dylib 中的预览入口并替换当前视图。
    @discardableResult
    func requestLoadPreviewEntry(at dylibURL: URL, symbolName: String) async throws -> RenderResponse

    /// 请求宿主进程启动 Live 预览窗口。
    @discardableResult
    func requestStartLivePreview() async throws -> RenderResponse

    /// 请求宿主进程更新 Live 预览窗口的屏幕坐标和尺寸。
    @discardableResult
    func requestUpdateLiveFrame(x: Double, y: Double, width: Double, height: Double) async throws -> RenderResponse

    /// 请求宿主进程显示 Live 预览窗口。
    @discardableResult
    func requestShowLivePreview() async throws -> RenderResponse

    /// 请求宿主进程隐藏 Live 预览窗口。
    @discardableResult
    func requestHideLivePreview() async throws -> RenderResponse

    /// 请求宿主进程重新加载 Live 预览（加载新 dylib，替换 root view）。
    @discardableResult
    func requestReloadLivePreview(at dylibURL: URL, symbolName: String) async throws -> RenderResponse

    /// 请求宿主进程停止 Live 预览并关闭 live window。
    @discardableResult
    func requestStopLivePreview() async throws -> RenderResponse

    /// 终止宿主进程。
    func terminate() async
}

public extension HostConnection {
    /// 使用空配置发送渲染请求。
    @discardableResult
    func requestRender(discovery: PreviewDiscovery) async throws -> RenderResponse {
        try await requestRender(discovery: discovery, configuration: .empty)
    }
}

private final class ProcessHostConnection: HostConnection, @unchecked Sendable {
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
        get async {
            process.isRunning
        }
    }

    @discardableResult
    func requestRender(
        discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration
    ) async throws -> RenderResponse {
        let request = RenderRequest(
            command: .render,
            discovery: discovery,
            configuration: configuration
        )
        let response: RenderResponse = try send(request)
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Render request failed.")
        }
        return response
    }

    @discardableResult
    func requestRefresh() async throws -> RenderResponse {
        let request = RenderRequest(command: .refresh)
        let response: RenderResponse = try send(request)
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Refresh request failed.")
        }
        return response
    }

    @discardableResult
    func requestLoadDylib(at dylibURL: URL) async throws -> RenderResponse {
        let request = RenderRequest(command: .loadDylib, dylibPath: dylibURL.path)
        let response: RenderResponse = try send(request)
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Dylib load request failed.")
        }
        return response
    }

    @discardableResult
    func requestLoadPreviewEntry(at dylibURL: URL, symbolName: String) async throws -> RenderResponse {
        let request = RenderRequest(
            command: .loadDylib,
            dylibPath: dylibURL.path,
            previewEntrySymbol: symbolName
        )
        let response: RenderResponse = try send(request)
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Preview entry load request failed.")
        }
        return response
    }

    @discardableResult
    func requestStartLivePreview() async throws -> RenderResponse {
        let request = RenderRequest(command: .startLivePreview)
        let response: RenderResponse = try send(request)
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Start live preview failed.")
        }
        return response
    }

    @discardableResult
    func requestUpdateLiveFrame(x: Double, y: Double, width: Double, height: Double) async throws -> RenderResponse {
        let request = RenderRequest(
            command: .updateLiveFrame,
            liveFrame: LiveFrameRequest(x: x, y: y, width: width, height: height)
        )
        let response: RenderResponse = try send(request)
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Update live frame failed.")
        }
        return response
    }

    @discardableResult
    func requestShowLivePreview() async throws -> RenderResponse {
        let request = RenderRequest(command: .showLivePreview)
        let response: RenderResponse = try send(request)
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Show live preview failed.")
        }
        return response
    }

    @discardableResult
    func requestHideLivePreview() async throws -> RenderResponse {
        let request = RenderRequest(command: .hideLivePreview)
        let response: RenderResponse = try send(request)
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Hide live preview failed.")
        }
        return response
    }

    @discardableResult
    func requestReloadLivePreview(at dylibURL: URL, symbolName: String) async throws -> RenderResponse {
        let request = RenderRequest(
            command: .reloadLivePreview,
            dylibPath: dylibURL.path,
            previewEntrySymbol: symbolName
        )
        let response: RenderResponse = try send(request)
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Reload live preview failed.")
        }
        return response
    }

    @discardableResult
    func requestStopLivePreview() async throws -> RenderResponse {
        let request = RenderRequest(command: .stopLivePreview)
        let response: RenderResponse = try send(request)
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Stop live preview failed.")
        }
        return response
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
        }
    }

    private func send<Response: Decodable>(_ request: RenderRequest) throws -> Response {
        lock.lock()
        defer { lock.unlock() }

        guard process.isRunning else {
            throw PreviewError.hostLaunchFailed(message: "Host process is not running.")
        }

        var payload = try encoder.encode(request)
        payload.append(0x0A)

        do {
            try stdin.write(contentsOf: payload)
        } catch {
            throw PreviewError.hostLaunchFailed(message: "Failed to write to host stdin: \(error.localizedDescription)")
        }

        guard let line = try readLineData() else {
            throw PreviewError.hostLaunchFailed(message: "Host process closed stdout.")
        }

        do {
            return try decoder.decode(Response.self, from: line)
        } catch {
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: line) {
                throw PreviewError.runtimeCrashed(message: errorResponse.message)
            }
            throw PreviewError.runtimeCrashed(message: "Failed to decode host response: \(error.localizedDescription)")
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
