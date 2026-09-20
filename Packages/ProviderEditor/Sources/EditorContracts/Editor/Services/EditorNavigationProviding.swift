import Foundation

/// 打开位置时的行为选项。
public struct EditorOpenOptions: Equatable, Sendable {
    public enum FocusBehavior: Equatable, Sendable {
        /// 激活为当前标签。
        case activate
        /// 保持当前标签不变（后台打开）。
        case keepCurrent
        /// 复用预览标签。
        case preview
    }

    public let focus: FocusBehavior

    /// 打开后是否滚动到目标范围。
    public let reveal: EditorRevealPolicy

    public init(focus: FocusBehavior = .activate, reveal: EditorRevealPolicy = .minimal) {
        self.focus = focus
        self.reveal = reveal
    }
}

/// 导航能力（契约 V2，见重构方案 §8.5）。
///
/// Problems、References、Search、Outline、Call Hierarchy 都调用本协议，
/// 不各自实现打开逻辑。
@MainActor
public protocol EditorNavigationProviding: AnyObject {
    /// 打开一个位置（文件 + 范围）。
    func open(_ location: EditorLocation, options: EditorOpenOptions)

    /// 在已打开文档中滚动 reveal 一个范围。
    ///
    /// - Throws: `EditorContractError.documentNotFound`。
    func reveal(_ range: EditorRange, in documentID: EditorDocumentID)

    /// 以 Peek 形式展示一组位置（引用/符号预览）。
    func peek(_ locations: [EditorLocation], origin: EditorLocation?)

    /// 后退/前进（等价 `EditorSessionProviding.navigateBack/Forward`）。
    func goBack()

    func goForward()
}
