import Foundation

// MARK: - Booklet Stage

/// Booklet 工具的纵向流程阶段。
///
/// 顺序固定：拼版预览 → 纸张选择 → 裁切线 → 装订效果 → 总览 → 导出。
/// 纸张选择、裁切线与装订效果的原生编辑控件在 T6 接入；T4 先打通
/// 阶段导航与拼版预览 / 总览 / 导出。
enum BookletStage: String, CaseIterable, Identifiable, Sendable {
    case printLayout
    case paperSelection
    case cuttingMarks
    case bindingEffect
    case review
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .printLayout: BookletLocalization.string("Print Layout")
        case .paperSelection: BookletLocalization.string("Paper")
        case .cuttingMarks: BookletLocalization.string("Cut Marks")
        case .bindingEffect: BookletLocalization.string("Binding")
        case .review: BookletLocalization.string("Review")
        case .export: BookletLocalization.string("Export")
        }
    }

    var systemImage: String {
        switch self {
        case .printLayout: "doc.on.doc"
        case .paperSelection: "rectangle.portrait.on.rectangle.portrait"
        case .cuttingMarks: "scissors"
        case .bindingEffect: "book.closed"
        case .review: "checkmark.circle"
        case .export: "square.and.arrow.up"
        }
    }

    /// 阶段序号（1-based），用于可访问性排序与步骤指示。
    var stepNumber: Int {
        switch self {
        case .printLayout: 1
        case .paperSelection: 2
        case .cuttingMarks: 3
        case .bindingEffect: 4
        case .review: 5
        case .export: 6
        }
    }

    func isAfter(_ other: BookletStage) -> Bool {
        stepNumber > other.stepNumber
    }
}
