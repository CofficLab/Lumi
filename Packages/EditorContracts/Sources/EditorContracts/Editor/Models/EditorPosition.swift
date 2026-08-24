import Foundation

// MARK: - 位置、范围与文档 URI

/// 文档中的位置。
///
/// 契约统一使用 zero-based 行号 + UTF-16 `character` 偏移，
/// 与 LSP 和 Cocoa 文本索引适配成本最低（见重构方案 §7.2）。
/// UI 如需显示 one-based 行列，只在展示层转换。
public struct EditorPosition: Equatable, Hashable, Comparable, Sendable {
    /// zero-based 行号。
    public var line: Int

    /// 行内 UTF-16 code unit 偏移。
    public var character: Int

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }

    /// 文档起点 `(0, 0)`。
    public static let zero = EditorPosition(line: 0, character: 0)

    public static func < (lhs: EditorPosition, rhs: EditorPosition) -> Bool {
        if lhs.line != rhs.line {
            return lhs.line < rhs.line
        }
        return lhs.character < rhs.character
    }
}

/// 文档中的范围（闭开区间：`start` 含、`end` 不含，允许空范围）。
public struct EditorRange: Equatable, Hashable, Sendable {
    public var start: EditorPosition

    public var end: EditorPosition

    public init(start: EditorPosition, end: EditorPosition) {
        self.start = start
        self.end = end
    }

    public init(_ start: EditorPosition, _ end: EditorPosition) {
        self.init(start: start, end: end)
    }

    /// 单点（光标）范围。
    public init(at position: EditorPosition) {
        self.init(start: position, end: position)
    }

    /// 是否为规范化范围（`start <= end`）。
    public var isValid: Bool {
        start <= end
    }

    /// 是否为空范围（插入点）。
    public var isEmpty: Bool {
        start == end
    }

    /// 返回规范化后的范围（必要时交换端点）。
    public var normalized: EditorRange {
        start <= end ? self : EditorRange(start: end, end: start)
    }

    /// 判断与另一范围是否重叠（相邻不算重叠）。
    public func overlaps(_ other: EditorRange) -> Bool {
        let a = normalized
        let b = other.normalized
        return a.start < b.end && b.start < a.end
    }

    /// 判断是否包含某位置（`end` 为开区间，不包含空范围端点之后的位置）。
    public func contains(_ position: EditorPosition) -> Bool {
        let r = normalized
        return r.start <= position && position < r.end
    }
}

/// 跨文档定位：URI + 范围。
public struct EditorLocation: Equatable, Hashable, Sendable {
    public var uri: URL

    public var range: EditorRange

    public init(uri: URL, range: EditorRange) {
        self.uri = uri
        self.range = range
    }
}

// MARK: - 跨包消歧别名

/// `EditorRange`（V2 契约）的消歧别名。
///
/// `EditorService` 等包通过 `@_exported import EditorKernel` re-export 了
/// EditorKernel 的同名历史类型（NSRange 语义），这些包内未限定名会解析到
/// 历史类型一侧。需要同时引用两侧的包使用本别名指向 V2 契约类型。
public typealias EditorV2Range = EditorRange

/// `EditorSelection`（V2 契约）的消歧别名，用途同 `EditorV2Range`。
public typealias EditorV2Selection = EditorSelection
