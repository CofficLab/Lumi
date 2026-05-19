import AppKit
import Foundation
import LumiInlinePreviewKit

/// 子进程的 stdio 主控。
///
/// - 通过 stdin 按行读取 `HostRequest`。
/// - 派发给 `HotPreviewRenderer` / `HotPreviewRenderLoop`。
/// - 把响应（同步）和帧事件（异步）以 `HostOutbound` envelope 形式按行写出 stdout。
@MainActor
final class HotStdioPreviewHost {

    // MARK: - 私有属性

    private let renderer: HotPreviewRenderer
    private let renderLoop: HotPreviewRenderLoop
    private let eventDispatcher: HotPreviewEventDispatcher
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stdoutLock = NSLock()
    private var stdinReader: DispatchSourceRead?
    private var stdinBuffer = Data()
    private var lastCursorShape: LumiInlinePreviewFacade.PreviewCursorShape = .arrow

    // MARK: - 初始化

    init() {
        let renderer = HotPreviewRenderer()
        self.renderer = renderer
        self.renderLoop = HotPreviewRenderLoop(renderer: renderer)
        self.eventDispatcher = HotPreviewEventDispatcher(renderer: renderer)
        wireRenderLoopCallbacks()
    }

    // MARK: - 启动

    /// 安装 stdin 读取器；调用方应在此后进入 `NSApplication.shared.run()`。
    func start() {
        let stdinFD: Int32 = 0
        let source = DispatchSource.makeReadSource(fileDescriptor: stdinFD, queue: .main)
        source.setEventHandler { [weak self] in
            self?.readAvailableStdin(fd: stdinFD)
        }
        source.setCancelHandler { [weak self] in
            self?.handleStdinEOF()
        }
        source.resume()
        stdinReader = source
    }

    // MARK: - stdin 读取

    private func readAvailableStdin(fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let n = read(fd, &buffer, buffer.count)
        if n <= 0 {
            stdinReader?.cancel()
            return
        }
        stdinBuffer.append(buffer, count: n)
        drainBuffer()
    }

    private func drainBuffer() {
        while let newlineIndex = stdinBuffer.firstIndex(of: 0x0A) {
            let lineData = stdinBuffer.prefix(upTo: newlineIndex)
            stdinBuffer.removeSubrange(...newlineIndex)
            if !lineData.isEmpty {
                handleLine(Data(lineData))
            }
        }
    }

    private func handleLine(_ data: Data) {
        do {
            let request = try decoder.decode(LumiInlinePreviewFacade.HostRequest.self, from: data)
            let response = dispatch(request.command)
            sendResponse(requestID: request.requestID, payload: response)
        } catch {
            sendEvent(.error(message: "Invalid request: \(error.localizedDescription)"))
        }
    }

    private func handleStdinEOF() {
        // 主进程关闭 stdin 视为退出信号。
        renderLoop.stop()
        Task { @MainActor in
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - 命令派发

    private func dispatch(_ command: LumiInlinePreviewFacade.HostCommand) -> LumiInlinePreviewFacade.HostResponse {
        switch command {
        case .ping:
            return .init(success: true, message: "pong")

        case let .startFrameStream(width, height, scale):
            renderer.resize(width: width, height: height, scale: CGFloat(scale))
            renderLoop.startInteractiveBurst()
            return .init(success: true, message: "stream started")

        case .stopFrameStream:
            renderLoop.stop()
            return .init(success: true, message: "stream stopped")

        case let .setFrameStreamPolicy(policy):
            renderLoop.setPolicy(policy)
            return .init(success: true)

        case let .resizeSurface(width, height, scale):
            renderer.resize(width: width, height: height, scale: CGFloat(scale))
            return .init(success: true)

        case let .loadDylib(path, symbolName):
            do {
                try renderer.loadDylib(path: path, symbolName: symbolName)
                renderLoop.startInteractiveBurst()
                sendEvent(.entryLoaded(success: true, message: nil))
                return .init(success: true, message: "dylib loaded")
            } catch {
                let message = String(describing: error)
                sendEvent(.entryLoaded(success: false, message: message))
                return .init(success: false, message: message)
            }

        case .unloadDylib:
            renderer.unloadDylib()
            sendCursorChanged(.arrow)
            sendEvent(.entryLoaded(success: true, message: "dylib unloaded"))
            return .init(success: true, message: "dylib unloaded")

        case .requestEntryDebugState:
            guard let state = renderer.entryDebugState() else {
                return .init(success: false, message: "entry debug state unavailable")
            }
            sendEvent(.entryDebugState(state))
            return .init(success: true, message: state)

        case let .forwardInputEvent(inputEvent):
            eventDispatcher.dispatch(inputEvent)
            publishCurrentCursorIfNeeded()
            renderer.markDirty()
            renderLoop.noteInteractiveActivity()
            return .init(success: true)
        }
    }

    // MARK: - 出站

    private func wireRenderLoopCallbacks() {
        renderLoop.onFrameReady = { [weak self] frame in
            self?.sendEvent(.frameProduced(frame))
        }
        renderLoop.onPolicyChanged = { [weak self] policy in
            self?.sendEvent(.streamStateChanged(policy))
        }
    }

    private func sendResponse(requestID: UInt64, payload: LumiInlinePreviewFacade.HostResponse) {
        write(.response(requestID: requestID, payload: payload))
    }

    private func sendEvent(_ event: LumiInlinePreviewFacade.HostEvent) {
        write(.event(event))
    }

    private func publishCurrentCursorIfNeeded() {
        sendCursorChanged(LumiInlinePreviewFacade.PreviewCursorShape(appKit: NSCursor.current))
    }

    private func sendCursorChanged(_ shape: LumiInlinePreviewFacade.PreviewCursorShape) {
        guard lastCursorShape != shape else { return }
        lastCursorShape = shape
        sendEvent(.cursorChanged(shape))
    }

    private func write(_ outbound: LumiInlinePreviewFacade.HostOutbound) {
        guard var data = try? encoder.encode(outbound) else { return }
        data.append(0x0A)
        stdoutLock.lock()
        defer { stdoutLock.unlock() }
        FileHandle.standardOutput.write(data)
    }
}
