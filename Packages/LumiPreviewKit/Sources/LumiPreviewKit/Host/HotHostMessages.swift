import Foundation

public extension LumiPreviewFacade {
    /// Hot 预览宿主支持的命令类型。
    ///
    /// 通过 JSON 编码发送给宿主进程，每个命令对应一种预览操作。
    enum HotHostCommand: String, Codable, Sendable {
        /// 根据源码发现结果渲染一个预览。
        case render
        /// 刷新当前预览（重新加载已编译的 dylib）。
        case refresh
        /// 捕获当前预览画面为图片，不重新编译。
        case captureFrame
        /// 动态加载已编译并签名的预览入口 dylib。
        case loadDylib
        /// 通过动态 interpose 替换已加载 dylib 中的符号实现（热更新优化）。
        case interposeDylib
        /// 启动 Live 预览：创建真实 NSHostingView/NSView。
        case startLivePreview
        /// 更新 Live 预览窗口的屏幕坐标和尺寸。
        case updateLiveFrame
        /// 显示 Live 预览窗口。
        case showLivePreview
        /// 隐藏 Live 预览窗口。
        case hideLivePreview
        /// 重新加载 Live 预览（加载新 dylib，替换 root view）。
        case reloadLivePreview
        /// 停止 Live 预览并关闭 live window。
        case stopLivePreview
    }

    /// 发送给 Hot 预览宿主进程的请求消息。
    ///
    /// 通过 stdin JSON + 换行符 协议发送给宿主进程。
    struct HotHostRequest: Codable, Sendable {
        /// 请求命令类型。
        public let command: HotHostCommand
        /// 渲染命令使用的预览发现结果。
        public let discovery: LumiPreviewFacade.PreviewDiscovery?
        /// 需要动态加载的 dylib 路径。
        public let dylibPath: String?
        /// dylib 中可选的预览入口符号名。
        public let previewEntrySymbol: String?
        /// 本次渲染使用的配置。
        public let configuration: LumiPreviewFacade.PreviewRenderConfiguration
        /// Live 预览窗口的屏幕坐标和尺寸（用于 updateLiveFrame）。
        public let liveFrame: LumiPreviewFacade.LiveFrameRequest?
        /// 捕获帧请求选项（用于 captureFrame）。
        public let captureFrame: LumiPreviewFacade.CaptureFrameRequest?

        /// 创建一个 Hot 宿主请求。
        ///
        /// - Parameters:
        ///   - command: 请求命令类型。
        ///   - discovery: 渲染用的预览发现结果。
        ///   - dylibPath: 需要动态加载的 dylib 路径。
        ///   - previewEntrySymbol: dylib 中的预览入口符号名。
        ///   - configuration: 本次渲染使用的配置。
        ///   - liveFrame: Live 预览窗口的屏幕坐标和尺寸。
        ///   - captureFrame: 捕获帧请求选项。
        public init(
            command: HotHostCommand,
            discovery: LumiPreviewFacade.PreviewDiscovery? = nil,
            dylibPath: String? = nil,
            previewEntrySymbol: String? = nil,
            configuration: LumiPreviewFacade.PreviewRenderConfiguration = .empty,
            liveFrame: LumiPreviewFacade.LiveFrameRequest? = nil,
            captureFrame: LumiPreviewFacade.CaptureFrameRequest? = nil
        ) {
            self.command = command
            self.discovery = discovery
            self.dylibPath = dylibPath
            self.previewEntrySymbol = previewEntrySymbol
            self.configuration = configuration
            self.liveFrame = liveFrame
            self.captureFrame = captureFrame
        }
    }
}
