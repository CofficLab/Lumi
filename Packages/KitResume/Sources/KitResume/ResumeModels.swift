import CoreGraphics
import Foundation

/// 简历纸张预设。
///
/// CSS 按 96dpi 像素计（HTML `.resume-page` 容器的精确尺寸），
/// PDF 输出按 72dpi 点计（WebKit 的 PDF 管线固定 1 CSS px = 0.75 pt），
/// 因此 A4 的 794 px 恰好栅格为 595.5 pt 的标准 A4 页面。
public enum ResumePaperKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case a4
    case letter

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .a4: "A4 (210 × 297 mm)"
        case .letter: "US Letter (8.5 × 11 in)"
        }
    }
}

public struct ResumePaperPreset: Codable, Equatable, Identifiable, Sendable {
    public let kind: ResumePaperKind
    /// CSS 像素宽度（96dpi），与 HTML `.resume-page` 容器一致。
    public let cssWidth: Int
    /// CSS 像素高度（96dpi）。
    public let cssHeight: Int

    public var id: String { kind.rawValue }
    public var cgSize: CGSize { CGSize(width: cssWidth, height: cssHeight) }

    /// PDF 页面宽度（72dpi 点）。
    public var pdfWidth: Double { Double(cssWidth) * 0.75 }
    /// PDF 页面高度（72dpi 点）。
    public var pdfHeight: Double { Double(cssHeight) * 0.75 }
    public var pdfSize: CGSize { CGSize(width: pdfWidth, height: pdfHeight) }

    /// 指定 DPI 下导出 PNG 的像素尺寸。
    public func pixelSize(dpi: Int) -> CGSize {
        let scale = Double(dpi) / 96.0
        return CGSize(width: (Double(cssWidth) * scale).rounded(), height: (Double(cssHeight) * scale).rounded())
    }

    public init(kind: ResumePaperKind, cssWidth: Int, cssHeight: Int) {
        self.kind = kind
        self.cssWidth = cssWidth
        self.cssHeight = cssHeight
    }
}

public enum ResumePaperSpec {
    public static let presets: [ResumePaperPreset] = [
        .init(kind: .a4, cssWidth: 794, cssHeight: 1123),
        .init(kind: .letter, cssWidth: 816, cssHeight: 1056),
    ]

    public static func preset(for kind: ResumePaperKind) -> ResumePaperPreset {
        presets.first { $0.kind == kind } ?? presets[0]
    }
}

/// 内置简历模板。
public enum ResumeTemplateKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 经典单栏黑白，ATS 友好。
    case classic
    /// 现代双栏，侧栏强调色。
    case modern
    /// 极简单栏，大量留白。
    case minimal
    /// 空白起始页，供自由定制场景从零构建。
    case blank

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .classic: "Classic (single column, ATS-friendly)"
        case .modern: "Modern (two columns with accent sidebar)"
        case .minimal: "Minimal (single column, generous spacing)"
        case .blank: "Blank (start from scratch)"
        }
    }
}

/// PNG 导出分辨率预设。
public enum ResumeExportResolution: Int, Codable, CaseIterable, Identifiable, Sendable {
    /// 屏幕预览（96dpi，与 CSS 像素 1:1）。
    case screen = 96
    /// 高清屏幕分享（150dpi）。
    case high = 150
    /// 打印质量（300dpi，A4 ≈ 2480 × 3508 px）。
    case print = 300

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .screen: "96 dpi (screen)"
        case .high: "150 dpi (high)"
        case .print: "300 dpi (print)"
        }
    }
}

/// 一份简历任务的 manifest 模型。
public struct ResumeDocument: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var title: String
    public var paper: ResumePaperKind
    public var template: ResumeTemplateKind
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = ResumeDocument.currentSchemaVersion,
        id: String,
        title: String,
        paper: ResumePaperKind,
        template: ResumeTemplateKind,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.paper = paper
        self.template = template
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 读取到内存的完整简历（manifest + HTML 源码 + 目录位置）。
public struct ResumeResolvedDocument: Equatable, Sendable {
    public let document: ResumeDocument
    public let directoryURL: URL
    public let html: String
    private let resolvedHTMLURL: URL

    public var htmlURL: URL { resolvedHTMLURL }
    public var assetsDirectoryURL: URL { directoryURL.appendingPathComponent("assets", isDirectory: true) }

    public init(
        document: ResumeDocument,
        directoryURL: URL,
        html: String,
        htmlURL: URL? = nil
    ) {
        self.document = document
        self.directoryURL = directoryURL
        self.html = html
        self.resolvedHTMLURL = htmlURL ?? directoryURL.appendingPathComponent("index.html")
    }
}
