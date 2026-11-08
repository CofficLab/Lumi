import Foundation
import SwiftUI

// MARK: - Output Status

/// Lifecycle states for a converted PDF item.
enum PDFOutputStatus: Equatable {
    case pending
    case processing
    case done(URL)
    case failed(String)

    var isTerminal: Bool {
        switch self {
        case .done, .failed: return true
        case .pending, .processing: return false
        }
    }

    var outputURL: URL? {
        if case .done(let url) = self { return url }
        return nil
    }
}

// MARK: - PDF Output Item

/// Represents one PDF produced (or pending) for an input image.
struct PDFOutputItem: Identifiable, Equatable {
    let id: UUID
    let source: ImageItem
    /// 实际写出的 PDF 文件名；同名输入会由 ViewModel 分配唯一名字。
    let outputName: String
    var status: PDFOutputStatus
    var progress: Double

    init(source: ImageItem, outputName: String? = nil) {
        self.id = UUID()
        self.source = source
        self.outputName = outputName ?? source.suggestedPDFName
        self.status = .pending
        self.progress = 0
    }

    /// 是否展示行内进度条。
    ///
    /// 只有 `processing` 才是进行中状态：进入 `failed` / `done` 后，
    /// 残留的中间进度不能继续渲染，否则界面会同时显示"失败"和"进行中"。
    var showsProgress: Bool {
        guard case .processing = status else { return false }
        return progress > 0 && progress < 1
    }

    /// Label shown in the UI based on status.
    var displayStatus: String {
        switch status {
        case .pending:
            return ImageToPDFLocalization.string("Pending")
        case .processing:
            return ImageToPDFLocalization.string("Processing…")
        case .done:
            return ImageToPDFLocalization.string("Done")
        case .failed:
            return ImageToPDFLocalization.string("Failed")
        }
    }
}