import os

/// 统一公共命名空间。
///
/// 所有 LumiPreviewKit 的公开类型都挂载在这个 `enum` 下，
/// 避免全局命名冲突，同时提供统一的导入入口。
public enum LumiPreviewFacade {
    /// 包内共享 Logger，供 PreviewSurfaceCanvas 等使用。
    public static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "LumiPreviewKit"
    )
    /// 是否启用日志输出，由宿主 App 的插件 verbose 控制。
    nonisolated(unsafe) public static var verbose: Bool = true
}

typealias PreviewSession = LumiPreviewFacade.PreviewSession
typealias PreviewPerformanceMetrics = LumiPreviewFacade.PreviewPerformanceMetrics
typealias PreviewSessionState = LumiPreviewFacade.PreviewSessionState
typealias PreviewDiscovery = LumiPreviewFacade.PreviewDiscovery
typealias PreviewError = LumiPreviewFacade.PreviewError
typealias PreviewScanner = LumiPreviewFacade.PreviewScanner
typealias PreviewDisplayMode = LumiPreviewFacade.PreviewDisplayMode
typealias LivePreviewState = LumiPreviewFacade.LivePreviewState
typealias LivePreviewInfo = LumiPreviewFacade.LivePreviewInfo
typealias PreviewFileContextCache = LumiPreviewFacade.PreviewFileContextCache
typealias PreviewEntryBuilder = LumiPreviewFacade.PreviewEntryBuilder
typealias PreviewHostCommand = LumiPreviewFacade.PreviewHostCommand
typealias RenderRequest = LumiPreviewFacade.RenderRequest
typealias LiveFrameRequest = LumiPreviewFacade.LiveFrameRequest
typealias RenderResponse = LumiPreviewFacade.RenderResponse
typealias PreviewEntryDescriptor = LumiPreviewFacade.PreviewEntryDescriptor
typealias ErrorResponse = LumiPreviewFacade.ErrorResponse
typealias BuildStrategy = LumiPreviewFacade.BuildStrategy
typealias BuildPlanner = LumiPreviewFacade.BuildPlanner
typealias PreviewFrameAlignment = LumiPreviewFacade.PreviewFrameAlignment
typealias LivePreviewFrameAlignment = LumiPreviewFacade.LivePreviewFrameAlignment
typealias XcodeCompiler = LumiPreviewFacade.XcodeCompiler
typealias SPMCompiler = LumiPreviewFacade.SPMCompiler
typealias EditorPreviewRefreshSignal = LumiPreviewFacade.EditorPreviewRefreshSignal
typealias IncrementalCompiler = LumiPreviewFacade.IncrementalCompiler
typealias LiveCanvasService = LumiPreviewFacade.LiveCanvasService
typealias EditorPreviewLiveCanvasService = LumiPreviewFacade.EditorPreviewLiveCanvasService
typealias ProjectPreviewIndexService = LumiPreviewFacade.ProjectPreviewIndexService
typealias PreviewEnvironmentInjection = LumiPreviewFacade.PreviewEnvironmentInjection
typealias PreviewRenderConfiguration = LumiPreviewFacade.PreviewRenderConfiguration
typealias EditorPreviewRefreshPolicy = LumiPreviewFacade.EditorPreviewRefreshPolicy
typealias PreviewStoragePaths = LumiPreviewFacade.PreviewStoragePaths

public extension LumiPreviewFacade {
    typealias LivePreviewFrameAlignment = PreviewFrameAlignment
    typealias EditorPreviewLiveCanvasService = LiveCanvasService
}
