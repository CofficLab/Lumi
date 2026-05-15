import Foundation

public extension LumiPreviewFacade {
/// 预览会话：代表一个正在运行或已完成的预览实例。
protocol PreviewSession: AnyObject, Sendable {
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
struct PreviewPerformanceMetrics: Sendable, Equatable {
    /// 最近一次编译耗时，单位秒。
    public var lastCompileDuration: TimeInterval?
    /// 最近一次宿主加载预览入口耗时，单位秒。
    public var lastLoadDuration: TimeInterval?
    /// 最近一次刷新耗时，单位秒。
    public var lastRefreshDuration: TimeInterval?
    /// 最近一次编译是否命中缓存。
    public var lastCompileUsedCache: Bool
    /// 最近一次预览入口是否命中缓存。
    public var lastEntryUsedCache: Bool

    /// 创建一组性能指标。
    ///
    /// - Parameters:
    ///   - lastCompileDuration: 最近一次编译耗时，单位秒。
    ///   - lastLoadDuration: 最近一次宿主加载预览入口耗时，单位秒。
    ///   - lastRefreshDuration: 最近一次刷新耗时，单位秒。
    ///   - lastCompileUsedCache: 最近一次编译是否命中缓存。
    ///   - lastEntryUsedCache: 最近一次预览入口是否命中缓存。
    public init(
        lastCompileDuration: TimeInterval? = nil,
        lastLoadDuration: TimeInterval? = nil,
        lastRefreshDuration: TimeInterval? = nil,
        lastCompileUsedCache: Bool = false,
        lastEntryUsedCache: Bool = false
    ) {
        self.lastCompileDuration = lastCompileDuration
        self.lastLoadDuration = lastLoadDuration
        self.lastRefreshDuration = lastRefreshDuration
        self.lastCompileUsedCache = lastCompileUsedCache
        self.lastEntryUsedCache = lastEntryUsedCache
    }
}

/// 预览会话状态。
enum PreviewSessionState: Sendable, Equatable {
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

}
