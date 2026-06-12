import Foundation

public extension LumiPreviewFacade {
/// 预览相关错误。
enum PreviewError: Error, LocalizedError, Sendable, Equatable {
    /// 找不到文件所属的 target。
    case targetNotFound(file: String)

    /// 项目类型不支持。
    case unsupportedProjectType(path: String)

    /// 编译失败。
    case compilationFailed(message: String)

    /// 编译产物未找到。
    case buildProductNotFound

    /// 预览进程启动失败。
    case hostLaunchFailed(message: String)

    /// 预览运行时崩溃。
    case runtimeCrashed(message: String)

    /// 操作超时。
    case timedOut(seconds: TimeInterval)

    /// 视图依赖缺失，例如 `@EnvironmentObject` 未注入。
    case missingDependency(description: String)

    public var errorDescription: String? {
        switch self {
        case .targetNotFound(let file):
            return "Preview target not found for file: \(file)"
        case .unsupportedProjectType(let path):
            return "Unsupported preview project type: \(path)"
        case .compilationFailed(let message):
            return message
        case .buildProductNotFound:
            return "Preview build product was not found."
        case .hostLaunchFailed(let message):
            return "Preview host launch failed: \(message)"
        case .runtimeCrashed(let message):
            return "Preview runtime crashed: \(message)"
        case .timedOut(let seconds):
            return "Preview operation timed out after \(seconds) seconds."
        case .missingDependency(let description):
            return "Preview is missing a dependency: \(description)"
        }
    }
}

}
