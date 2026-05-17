import Foundation

public extension LumiInlinePreviewFacade {

    // MARK: - 命令

    /// 主进程发往子进程的命令。
    ///
    /// 使用 Swift 自动合成的 Codable，每个 case 编码为 `{caseName: {associatedValues}}` 形式。
    enum HostCommand: Codable, Sendable, Equatable {
        case ping
        case startFrameStream(width: Int, height: Int, scale: Double)
        case stopFrameStream
        case setFrameStreamPolicy(FrameStreamPolicy)
        case resizeSurface(width: Int, height: Int, scale: Double)

        /// 加载用户编译产出的预览 dylib，并把其导出的 `NSView` 挂为 `previewView`。
        ///
        /// `symbolName` 必须指向一个 `@_cdecl` 函数：
        /// `() -> UnsafeMutableRawPointer?`，返回 `Unmanaged.passRetained(view).toOpaque()`。
        case loadDylib(path: String, symbolName: String)

        /// 卸载当前用户 dylib，恢复到内置 demo 视图。
        case unloadDylib

        /// 把主进程捕获的输入事件注入到子进程离屏窗口。
        ///
        /// 坐标必须是子进程当前 hosting view 内的 point 值（bottom-left 原点）；
        /// 主进程通过 `resizeSurface` 与子进程同步 point 尺寸后可直接传 view-local 坐标。
        case forwardInputEvent(PreviewInputEvent)
    }

    // MARK: - 请求 / 响应

    /// 一条 stdin 行内承载的请求。
    struct HostRequest: Codable, Sendable, Equatable {
        public let requestID: UInt64
        public let command: HostCommand

        public init(requestID: UInt64, command: HostCommand) {
            self.requestID = requestID
            self.command = command
        }
    }

    /// 子进程对单条请求的同步回执。
    ///
    /// 仅承载"命令是否被成功调度"，**不**包含帧像素——那是异步事件流的工作。
    struct HostResponse: Codable, Sendable, Equatable {
        public let success: Bool
        public let message: String?

        public init(success: Bool, message: String? = nil) {
            self.success = success
            self.message = message
        }
    }

    // MARK: - 事件

    /// 子进程异步推送给主进程的事件。
    enum HostEvent: Codable, Sendable, Equatable {
        case frameProduced(IOSurfaceFrame)
        case streamStateChanged(FrameStreamPolicy)
        case error(message: String)

        /// 用户 dylib 加载结果。`success == false` 时 `message` 描述失败原因。
        case entryLoaded(success: Bool, message: String?)
    }

    // MARK: - 出站 envelope

    /// 子进程通过 stdout 写出的统一信封。
    ///
    /// 每条 stdout 行恰好编码一个 `HostOutbound`，主进程按行解析。
    enum HostOutbound: Codable, Sendable, Equatable {
        case response(requestID: UInt64, payload: HostResponse)
        case event(HostEvent)
    }
}
