import Foundation

public extension LumiPreviewFacade {
    /// 主进程侧的高层会话对象。
    ///
    /// 内部组合 `InlineHostExecutableResolver` + `InlineHostConnection`，
    /// 暴露最简单的"启动→订阅帧→停止"接口，给上层 ViewModel 使用。
    /// 不直接持有 UI 状态——`@Published` 由 ViewModel 自己维护。
    @MainActor
    final class InlinePreviewSession {

        // MARK: - 公开类型

        public enum SessionError: Error, LocalizedError {
            case executableNotFound
            case underlying(Error)

            public var errorDescription: String? {
                switch self {
                case .executableNotFound:
                    return "LumiPreviewHostApp executable not found. Set the LUMI_INLINE_PREVIEW_HOST_PATH environment variable or embed it in the app bundle."
                case .underlying(let e):
                    return e.localizedDescription
                }
            }
        }

        // MARK: - 私有

        private var connection: InlineHostConnection?
        private var eventTask: Task<Void, Never>?

        public var onFrame: ((IOSurfaceFrame) -> Void)?
        public var onPolicy: ((FrameStreamPolicy) -> Void)?
        public var onError: ((String) -> Void)?
        public var onTerminated: (() -> Void)?
        public var onEntryLoaded: ((_ success: Bool, _ message: String?) -> Void)?
        public var onEntryDebugState: ((String) -> Void)?
        public var onCursorChanged: ((PreviewCursorShape) -> Void)?

        public init() {}

        // MARK: - 状态

        public var isRunning: Bool {
            connection != nil
        }

        // MARK: - 公开方法

        /// 启动子进程并开始订阅事件。重复调用是 noop。
        public func start() async throws {
            guard connection == nil else { return }
            guard let executableURL = InlineHostExecutableResolver.resolve() else {
                throw SessionError.executableNotFound
            }

            let connection: InlineHostConnection
            do {
                connection = try ProcessInlineHostConnection.launch(executableURL: executableURL)
            } catch {
                throw SessionError.underlying(error)
            }
            self.connection = connection
            subscribeEvents(connection)
        }

        /// 启动一条帧流（默认 interactive 策略）。
        @discardableResult
        public func startFrameStream(width: Int, height: Int, scale: Double) async throws -> HostResponse {
            try await send(.startFrameStream(width: width, height: height, scale: scale))
        }

        /// 停止帧流（不关闭子进程）。
        @discardableResult
        public func stopFrameStream() async throws -> HostResponse {
            try await send(.stopFrameStream)
        }

        /// 调整目标 surface 像素尺寸 + scale。
        @discardableResult
        public func resize(width: Int, height: Int, scale: Double) async throws -> HostResponse {
            try await send(.resizeSurface(width: width, height: height, scale: scale))
        }

        /// 切换帧率策略。
        @discardableResult
        public func setPolicy(_ policy: FrameStreamPolicy) async throws -> HostResponse {
            try await send(.setFrameStreamPolicy(policy))
        }

        /// 让子进程加载用户编译产出的预览 dylib。
        ///
        /// `symbolName` 默认与老 `LumiPreviewKit` 约定一致（`lumi_preview_make_nsview`），
        /// 让未来接入老编译管线零成本。
        @discardableResult
        public func loadDylib(
            path: String,
            symbolName: String = "lumi_preview_make_nsview"
        ) async throws -> HostResponse {
            try await send(.loadDylib(path: path, symbolName: symbolName))
        }

        /// 卸载用户 dylib，恢复内置空白视图。
        @discardableResult
        public func unloadDylib() async throws -> HostResponse {
            try await send(.unloadDylib)
        }

        /// 请求用户 entry 可选导出的调试状态。
        @discardableResult
        public func requestEntryDebugState() async throws -> HostResponse {
            try await send(.requestEntryDebugState)
        }

        /// 把主进程捕获的输入事件转发给子进程注入到离屏窗口。
        ///
        /// 调用方应自行确保此 session 在 running 状态；非 running 时会因 `connection == nil` 抛错。
        @discardableResult
        public func forwardInputEvent(_ event: PreviewInputEvent) async throws -> HostResponse {
            try await send(.forwardInputEvent(event))
        }

        /// `forwardInputEvent` 的 fire-and-forget 版本：错误吞掉、不阻塞调用方。
        /// 适合 ViewModel 在 mouseMoved / keyDown 这类高频事件路径上调用。
        public func sendInputEventBestEffort(_ event: PreviewInputEvent) {
            guard let connection else { return }
            Task.detached {
                _ = try? await connection.send(.forwardInputEvent(event))
            }
        }

        /// 终止会话；会取消事件订阅、关闭 stdin、等待子进程退出。
        public func stop() async {
            eventTask?.cancel()
            eventTask = nil
            await connection?.terminate()
            connection = nil
        }

        // MARK: - 私有

        private func send(_ command: HostCommand) async throws -> HostResponse {
            guard let connection else { throw SessionError.executableNotFound }
            return try await connection.send(command)
        }

        private func subscribeEvents(_ connection: InlineHostConnection) {
            let stream = connection.events
            eventTask = Task { [weak self] in
                for await event in stream {
                    await self?.handle(event: event)
                }
                await self?.handleTerminated()
            }
        }

        private func handle(event: HostEvent) async {
            switch event {
            case let .frameProduced(frame):
                onFrame?(frame)
            case let .streamStateChanged(policy):
                onPolicy?(policy)
            case let .error(message):
                onError?(message)
            case let .entryLoaded(success, message):
                onEntryLoaded?(success, message)
            case let .entryDebugState(state):
                onEntryDebugState?(state)
            case let .cursorChanged(shape):
                onCursorChanged?(shape)
            }
        }

        private func handleTerminated() async {
            connection = nil
            eventTask = nil
            onTerminated?()
        }
    }
}
