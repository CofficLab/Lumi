import Foundation

// MARK: - Large File Mode
//
// Phase 8: 大文件模式。
//
// VS Code 对大文件有特殊处理策略：
// - 小文件（<1MB）：完整加载，所有功能可用
// - 中文件（1-10MB）：完整加载，但禁用部分重功能（semantic tokens、inlay hints）
// - 大文件（10-50MB）：按需加载（viewport），禁用重功能
// - 超大文件（>50MB）：只读模式，基础渲染

/// 文件大小分类。
enum LargeFileMode: Equatable, Sendable {
    /// 正常模式：所有功能可用
    case normal
    /// 中文件模式：完整加载，禁用部分重功能
    case medium
    /// 大文件模式：按需加载，禁用重功能
    case large
    /// 超大文件模式：只读，基础渲染
    case mega

    /// 文件大小阈值（字节）
    static let mediumThreshold: Int64 = 1 * 1024 * 1024       // 1MB
    static let largeThreshold: Int64 = 10 * 1024 * 1024       // 10MB
    static let megaThreshold: Int64 = 50 * 1024 * 1024        // 50MB

    /// 根据文件大小确定模式。
    static func mode(for fileSize: Int64) -> LargeFileMode {
        if fileSize >= megaThreshold {
            return .mega
        } else if fileSize >= largeThreshold {
            return .large
        } else if fileSize >= mediumThreshold {
            return .medium
        }
        return .normal
    }

    /// 是否禁用语义高亮。
    var isSemanticTokensDisabled: Bool {
        switch self {
        case .normal: return false
        case .medium, .large, .mega: return true
        }
    }

    /// 是否禁用 inlay hints。
    var isInlayHintsDisabled: Bool {
        switch self {
        case .normal: return false
        case .medium: return false
        case .large, .mega: return true
        }
    }

    /// 是否禁用折叠（folding）。
    var isFoldingDisabled: Bool {
        switch self {
        case .normal, .medium: return false
        case .large, .mega: return true
        }
    }

    /// 是否禁用 minimap。
    var isMinimapDisabled: Bool {
        switch self {
        case .normal, .medium: return false
        case .large, .mega: return true
        }
    }

    /// 是否启用长行保护。
    var isLongLineProtectionEnabled: Bool {
        switch self {
        case .normal, .medium: return false
        case .large, .mega: return true
        }
    }

    /// 最大高亮行数。
    var maxSyntaxHighlightLines: Int {
        switch self {
        case .normal: return Int.max
        case .medium: return 50_000
        case .large: return 10_000
        case .mega: return 1_000
        }
    }

    /// 是否只读。
    var isReadOnly: Bool {
        switch self {
        case .normal, .medium, .large: return false
        case .mega: return true
        }
    }
}

/// 检测到的长行信息。
struct LongestDetectedLine: Equatable, Sendable {
    let line: Int
    let length: Int
}

/// 长行检测器。
///
/// 当文档中存在超长行时（如 > 10,000 字符），
/// 语法高亮和布局计算会产生严重性能问题。
enum LongLineDetector: Sendable {
    /// 长行阈值（字符数）
    static let threshold: Int = 10_000

    /// 检测文本中是否存在超长行。
    /// 返回第一行长行的行号和内容长度。
    static func findLongestLine(in text: String, limit: Int = threshold) -> LongestDetectedLine? {
        var longestLine = 0
        var longestLength = 0
        var currentLine = 0
        var currentLength = 0

        for scalar in text.unicodeScalars {
            if scalar == "\n" {
                if currentLength > longestLength {
                    longestLength = currentLength
                    longestLine = currentLine
                    if longestLength >= limit {
                        return LongestDetectedLine(line: longestLine, length: longestLength)
                    }
                }
                currentLine += 1
                currentLength = 0
            } else {
                currentLength += 1
            }
        }

        // 检查最后一行
        if currentLength > longestLength {
            longestLength = currentLength
            longestLine = currentLine
        }

        return longestLength >= limit ? LongestDetectedLine(line: longestLine, length: longestLength) : nil
    }
}

/// Viewport 渲染控制器。
///
/// 在大文件模式下，只对可见区域内的内容进行完整渲染。
/// 不可见区域用占位符代替，大幅降低布局计算成本。
@MainActor
final class ViewportRenderController: ObservableObject {
    /// 可见区域的起始行（0-based）
    @Published var visibleStartLine: Int = 0

    /// 可见区域的结束行（exclusive）
    @Published var visibleEndLine: Int = 0

    /// 总行数
    @Published var totalLines: Int = 0

    /// 预渲染缓冲区大小（可见区域外额外渲染的行数）
    var bufferSize: Int = 50

    /// 渲染起始行（含缓冲区）
    var renderStartLine: Int {
        max(0, visibleStartLine - bufferSize)
    }

    /// 渲染结束行（含缓冲区）
    var renderEndLine: Int {
        min(totalLines, visibleEndLine + bufferSize)
    }

    /// 是否在渲染范围内。
    func isLineVisible(_ line: Int) -> Bool {
        line >= renderStartLine && line < renderEndLine
    }

    /// 更新可见区域。
    func updateVisibleRange(startLine: Int, endLine: Int, totalLines: Int) {
        visibleStartLine = startLine
        visibleEndLine = endLine
        self.totalLines = totalLines
    }

    /// 是否需要节流更新（快速滚动时）。
    func shouldDebounceUpdate(from previousStartLine: Int, previousEndLine: Int) -> Bool {
        let startDelta = abs(visibleStartLine - previousStartLine)
        let endDelta = abs(visibleEndLine - previousEndLine)
        return startDelta < 5 && endDelta < 5
    }
}
