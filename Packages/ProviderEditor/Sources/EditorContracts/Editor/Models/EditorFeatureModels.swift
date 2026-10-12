import Foundation

// MARK: - 插件 API 版本

/// 编辑器插件 API 版本（major.minor）。
///
/// Major 不兼容时拒绝安装 Bundle；Minor 新能力必须可选发现（见重构方案 §24）。
public struct EditorPluginAPIVersion: Equatable, Comparable, Sendable {
    public let major: Int

    public let minor: Int

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    /// 当前宿主实现的契约版本。
    ///
    /// V2 契约从 `(2, 0)` 开始；旧 `EditorPlugin` 注册路径不计入此版本。
    public static let current = EditorPluginAPIVersion(major: 2, minor: 0)

    public static func < (lhs: EditorPluginAPIVersion, rhs: EditorPluginAPIVersion) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }

    /// Bundle 声明的版本是否可与宿主共存（major 必须一致且不高于宿主）。
    public func isCompatible(with host: EditorPluginAPIVersion) -> Bool {
        major == host.major && self <= host
    }
}

// MARK: - 文档选择器

/// Provider 适用文档的声明式选择器（见重构方案 §9.4）。
///
/// 同一 `EditorDocumentSelector` 内的 filter 为 **AND** 关系；
/// 多个 selector 之间由 Provider 聚合逻辑取并集。
public struct EditorDocumentSelector: Equatable, Sendable {
    /// 匹配 language ID（如 `"swift"`）。
    public let languageID: String?

    /// 匹配 URI scheme（如 `"file"`）。
    public let scheme: String?

    /// 匹配文件名 glob（仅支持 `*` 通配，如 `"*.swift"`、`"Package@Swift-*"`）。
    public let filenameGlob: String?

    /// 匹配文件扩展名（不含点，如 `"swift"`）。
    public let fileExtension: String?

    /// 是否要求本地文件（scheme 为 `file` 且无 workspace authority）。
    public let requiresLocalFile: Bool

    public init(
        languageID: String? = nil,
        scheme: String? = nil,
        filenameGlob: String? = nil,
        fileExtension: String? = nil,
        requiresLocalFile: Bool = false
    ) {
        self.languageID = languageID
        self.scheme = scheme
        self.filenameGlob = filenameGlob
        self.fileExtension = fileExtension
        self.requiresLocalFile = requiresLocalFile
    }

    /// 匹配任意文档的空选择器。
    public static let any = EditorDocumentSelector()

    /// 是否匹配给定文档摘要。
    public func matches(_ document: EditorDocumentSummary) -> Bool {
        if let languageID, languageID != document.languageID {
            return false
        }
        if let scheme, scheme != document.uri.scheme {
            return false
        }
        if let fileExtension {
            guard document.uri.pathExtension.caseInsensitiveCompare(fileExtension) == .orderedSame else {
                return false
            }
        }
        if let filenameGlob {
            guard Self.globPattern(filenameGlob, matches: document.uri.lastPathComponent) else {
                return false
            }
        }
        if requiresLocalFile && !document.uri.isFileURL {
            return false
        }
        return true
    }

    /// 简化的 `*` 通配匹配：`*` 匹配任意（含空）字符序列，其余字符逐字比较。
    static func globPattern(_ pattern: String, matches filename: String) -> Bool {
        // 经典双指针 glob 匹配，不引入正则引擎。
        var patternIndex = pattern.startIndex
        var nameIndex = filename.startIndex
        var star: String.Index?
        var starMatch = filename.startIndex
        while nameIndex < filename.endIndex {
            if patternIndex < pattern.endIndex, pattern[patternIndex] == "*" {
                star = patternIndex
                starMatch = nameIndex
                patternIndex = pattern.index(after: patternIndex)
            } else if patternIndex < pattern.endIndex,
                pattern[patternIndex] == filename[nameIndex] {
                patternIndex = pattern.index(after: patternIndex)
                nameIndex = filename.index(after: nameIndex)
            } else if let star {
                patternIndex = pattern.index(after: star)
                starMatch = filename.index(after: starMatch)
                nameIndex = starMatch
            } else {
                return false
            }
        }
        while patternIndex < pattern.endIndex, pattern[patternIndex] == "*" {
            patternIndex = pattern.index(after: patternIndex)
        }
        return patternIndex == pattern.endIndex
    }
}

// MARK: - 信任与能力

/// Provider 对工作区信任状态的要求。
public enum EditorWorkspaceTrustRequirement: Equatable, Sendable {
    /// 任何信任状态均可用（纯本地文本处理）。
    case none

    /// 需要工作区受信任（启动进程、网络、批量文件访问）。
    case trusted
}

/// 标准语言能力种类。
public enum EditorFeature: String, Equatable, Hashable, CaseIterable, Sendable {
    case syntax
    case completion
    case hover
    case signatureHelp
    case definition
    case declaration
    case typeDefinition
    case implementation
    case references
    case rename
    case codeAction
    case formatting
    case documentSymbols
    case workspaceSymbols
    case callHierarchy
    case folding
    case inlayHints
    case semanticTokens
    case diagnostics
    case documentHighlight
    case links
    case colors
}

/// 某能力对某文档的可用性（能力缺失是正常状态，见重构方案 §4.5）。
public struct EditorFeatureAvailability: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// 能力可用。
        case available

        /// 能力存在但暂不可用（如 Language Server 启动中/重启中）。
        case temporarilyUnavailable(reason: String)

        /// 没有任何 Provider 匹配该文档。
        case noProvider

        /// 工作区未受信任被禁用。
        case disabledByTrust

        /// 大文件模式下被禁用。
        case disabledByLargeFileMode

        /// 提供该能力的插件已被禁用。
        case providerDisabled(pluginID: String)
    }

    public let state: State

    public init(_ state: State) {
        self.state = state
    }

    public var isAvailable: Bool {
        state == .available
    }
}
