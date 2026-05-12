import Foundation

/// 预览会话：代表一个正在运行或已完成的预览实例。
public protocol PreviewSession: AnyObject, Sendable {
    /// 唯一标识。
    var id: String { get }

    /// 当前状态。
    var state: PreviewSessionState { get async }

    /// 预览渲染的 NSView 宿主（由宿主进程提供）。
    /// 在进程外预览模式下，这是一个远程视图的本地代理。
    var hostingView: (any Sendable)? { get async }

    /// 最近一次编译和刷新性能指标。
    var performanceMetrics: PreviewPerformanceMetrics { get async }

    /// 当前会话使用的渲染配置。
    var configuration: PreviewRenderConfiguration { get async }

    /// 宿主进程最近一次渲染或刷新返回的响应。
    var lastRenderResponse: RenderResponse? { get async }

    /// 当前显示模式：image 或 live。
    var displayMode: PreviewDisplayMode { get async }

    /// Live 预览的详细状态信息。
    var livePreviewInfo: LivePreviewInfo { get async }
}

/// 预览性能指标。
public struct PreviewPerformanceMetrics: Sendable, Equatable {
    /// 最近一次编译耗时，单位秒。
    public var lastCompileDuration: TimeInterval?
    /// 最近一次宿主加载预览入口耗时，单位秒。
    public var lastLoadDuration: TimeInterval?
    /// 最近一次刷新耗时，单位秒。
    public var lastRefreshDuration: TimeInterval?
    /// 最近一次编译是否命中缓存。
    public var lastCompileUsedCache: Bool

    /// 创建一组性能指标。
    ///
    /// - Parameters:
    ///   - lastCompileDuration: 最近一次编译耗时，单位秒。
    ///   - lastLoadDuration: 最近一次宿主加载预览入口耗时，单位秒。
    ///   - lastRefreshDuration: 最近一次刷新耗时，单位秒。
    ///   - lastCompileUsedCache: 最近一次编译是否命中缓存。
    public init(
        lastCompileDuration: TimeInterval? = nil,
        lastLoadDuration: TimeInterval? = nil,
        lastRefreshDuration: TimeInterval? = nil,
        lastCompileUsedCache: Bool = false
    ) {
        self.lastCompileDuration = lastCompileDuration
        self.lastLoadDuration = lastLoadDuration
        self.lastRefreshDuration = lastRefreshDuration
        self.lastCompileUsedCache = lastCompileUsedCache
    }
}

/// 预览会话状态。
public enum PreviewSessionState: Sendable, Equatable {
    /// 正在规划编译。
    case planning
    /// 正在编译。
    case compiling(progress: Double)
    /// 正在启动预览进程。
    case launching
    /// 预览运行中。
    case running
    /// 编译或运行时出错。
    case failed(PreviewError)
    /// 已停止。
    case stopped
}

/// `PreviewEngine` 默认使用的预览会话实现。
public actor LivePreviewSession: PreviewSession {
    /// 唯一标识。
    public nonisolated let id: String

    /// 该会话对应的源码预览发现结果。
    private var currentDiscovery: PreviewDiscovery

    private var currentState: PreviewSessionState
    private var currentHostingView: (any Sendable)?
    private var currentBuildStrategy: BuildStrategy?
    private var currentHostConnection: HostConnection?
    private var currentPerformanceMetrics = PreviewPerformanceMetrics()
    private var currentConfiguration: PreviewRenderConfiguration
    private var currentLastRenderResponse: RenderResponse?
    private var currentDisplayMode: PreviewDisplayMode = .image
    private var currentLivePreviewInfo = LivePreviewInfo()

    /// 当前状态。
    public var state: PreviewSessionState {
        currentState
    }

    /// 预览渲染的宿主视图或远程视图代理。
    public var hostingView: (any Sendable)? {
        currentHostingView
    }

    /// 最近一次编译和刷新性能指标。
    public var performanceMetrics: PreviewPerformanceMetrics {
        currentPerformanceMetrics
    }

    /// 当前会话使用的渲染配置。
    public var configuration: PreviewRenderConfiguration {
        currentConfiguration
    }

    /// 宿主进程最近一次渲染或刷新返回的响应。
    public var lastRenderResponse: RenderResponse? {
        currentLastRenderResponse
    }

    /// 当前显示模式：image 或 live。
    public var displayMode: PreviewDisplayMode {
        currentDisplayMode
    }

    /// Live 预览的详细状态信息。
    public var livePreviewInfo: LivePreviewInfo {
        currentLivePreviewInfo
    }

    /// 创建一个预览会话。
    ///
    /// - Parameters:
    ///   - id: 稳定标识符，默认生成 UUID。
    ///   - discovery: 该会话对应的 `#Preview`。
    ///   - state: 初始状态。
    ///   - configuration: 初始渲染配置。
    public init(
        id: String = UUID().uuidString,
        discovery: PreviewDiscovery,
        state: PreviewSessionState = .planning,
        configuration: PreviewRenderConfiguration = .empty
    ) {
        self.id = id
        self.currentDiscovery = discovery
        self.currentState = state
        self.currentConfiguration = configuration
    }

    public var discovery: PreviewDiscovery {
        currentDiscovery
    }

    public func updateDiscovery(_ discovery: PreviewDiscovery) {
        currentDiscovery = discovery
    }

    func setState(_ state: PreviewSessionState) {
        currentState = state
    }

    func setBuildStrategy(_ strategy: BuildStrategy) {
        currentBuildStrategy = strategy
    }

    public func buildStrategy() -> BuildStrategy? {
        currentBuildStrategy
    }

    func setHostConnection(_ connection: HostConnection) {
        currentHostConnection = connection
    }

    public func hostConnection() -> HostConnection? {
        currentHostConnection
    }

    func recordCompile(duration: TimeInterval, usedCache: Bool) {
        currentPerformanceMetrics.lastCompileDuration = duration
        currentPerformanceMetrics.lastCompileUsedCache = usedCache
    }

    func recordLoad(duration: TimeInterval) {
        currentPerformanceMetrics.lastLoadDuration = duration
    }

    func recordRefresh(duration: TimeInterval) {
        currentPerformanceMetrics.lastRefreshDuration = duration
    }

    func setConfiguration(_ configuration: PreviewRenderConfiguration) {
        currentConfiguration = configuration
    }

    func setLastRenderResponse(_ response: RenderResponse) {
        currentLastRenderResponse = response
    }

    func setDisplayMode(_ mode: PreviewDisplayMode) {
        currentDisplayMode = mode
    }

    func setLivePreviewInfo(_ info: LivePreviewInfo) {
        currentLivePreviewInfo = info
    }

    /// 当宿主进程成功加载真实 NSView entry 后，标记 Live 模式可用。
    func markLivePreviewAvailable(windowNumber: Int? = nil, hostProcessID: Int32? = nil) {
        let state: LivePreviewState = if currentLivePreviewInfo.state == .running {
            .running
        } else {
            .available
        }
        currentLivePreviewInfo = LivePreviewInfo(
            state: state,
            hostWindowNumber: windowNumber,
            hostProcessID: hostProcessID ?? currentLivePreviewInfo.hostProcessID
        )
    }

    /// 当 Live 模式启动失败时，降级到图片模式并记录原因。
    func fallbackToImageMode(reason: String) {
        currentDisplayMode = .image
        currentLivePreviewInfo = LivePreviewInfo(
            state: .failed,
            unavailableReason: reason
        )
    }

    func terminateHost() async {
        await currentHostConnection?.terminate()
        currentHostConnection = nil
    }
}
