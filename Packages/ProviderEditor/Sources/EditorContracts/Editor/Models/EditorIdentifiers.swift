import Foundation

// MARK: - 强类型标识

/// 编辑器契约 V2 强类型标识。
///
/// 见 `docs/editor-kernel-plugin-rearchitecture-plan.md` §7.1：
/// 禁止继续用裸 `UUID` 同时表示窗口、Session 和文档。
/// 所有标识为 `RawRepresentable` + `Hashable` + `Sendable` 值类型，
/// 不携带任何实现信息（视图、存储或插件对象）。

/// 编辑器窗口标识。
public struct EditorWindowID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// 工作区标识。
public struct EditorWorkspaceID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// Editor Group（标签组）标识。
public struct EditorGroupID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// 编辑器会话（标签页背后的文档会话）标识。
public struct EditorSessionID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// 打开文档标识（同一文档在多个 Session/Group 中共享同一文档 Buffer）。
public struct EditorDocumentID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// 一次异步请求的标识，用于取消与 stale 结果丢弃。
public struct EditorRequestID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// 命令标识（如 `editor.file.save`）。
public struct EditorCommandID: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - 便捷构造

public extension EditorWindowID {
    /// 生成新的窗口标识。
    static func makeUnique() -> EditorWindowID {
        EditorWindowID(rawValue: UUID())
    }
}

public extension EditorWorkspaceID {
    /// 生成新的工作区标识。
    static func makeUnique() -> EditorWorkspaceID {
        EditorWorkspaceID(rawValue: UUID())
    }
}

public extension EditorGroupID {
    /// 生成新的 Group 标识。
    static func makeUnique() -> EditorGroupID {
        EditorGroupID(rawValue: UUID())
    }
}

public extension EditorSessionID {
    /// 生成新的 Session 标识。
    static func makeUnique() -> EditorSessionID {
        EditorSessionID(rawValue: UUID())
    }
}

public extension EditorDocumentID {
    /// 生成新的文档标识。
    static func makeUnique() -> EditorDocumentID {
        EditorDocumentID(rawValue: UUID())
    }
}

public extension EditorRequestID {
    /// 生成新的请求标识。
    static func makeUnique() -> EditorRequestID {
        EditorRequestID(rawValue: UUID())
    }
}
