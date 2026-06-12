import Foundation

/// 单个文件的编译上下文
public struct XcodeFileBuildContext: Sendable {
    public let fileURL: URL
    public let settings: [String: String]
    public let scheme: String
    public let workspacePath: String

    public init(
        fileURL: URL,
        settings: [String: String],
        scheme: String,
        workspacePath: String
    ) {
        self.fileURL = fileURL
        self.settings = settings
        self.scheme = scheme
        self.workspacePath = workspacePath
    }

    /// 提取 SDK 路径
    public var sdkPath: String? { settings["SDKROOT"] }

    /// 提取 toolchain 路径
    public var toolchainPath: String? { settings["TOOLCHAIN_DIR"] }

    /// 提取 target triple
    public var targetTriple: String? { settings["LLVM_TARGET_TRIPLE_SUFFIX"] }

    /// 提取 header search paths
    public var headerSearchPaths: [String] {
        (settings["HEADER_SEARCH_PATHS"] ?? "")
            .split(separator: " ")
            .map(String.init)
    }

    /// 提取 framework search paths
    public var frameworkSearchPaths: [String] {
        (settings["FRAMEWORK_SEARCH_PATHS"] ?? "")
            .split(separator: " ")
            .map(String.init)
    }

    /// 提取 active compilation conditions
    public var activeCompilationConditions: [String] {
        (settings["ACTIVE_COMPILATION_CONDITIONS"] ?? "")
            .split(separator: " ")
            .map(String.init)
    }

    /// 提取 module name
    public var moduleName: String? { settings["PRODUCT_MODULE_NAME"] }
}
