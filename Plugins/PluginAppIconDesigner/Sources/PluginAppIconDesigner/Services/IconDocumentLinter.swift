import Foundation

public struct IconDocumentLintIssue: Equatable, Sendable {
    public enum Severity: String, Equatable, Sendable {
        case warning
        case error
    }

    public var severity: Severity
    public var message: String
    public var layerId: String?

    public init(severity: Severity, message: String, layerId: String? = nil) {
        self.severity = severity
        self.message = message
        self.layerId = layerId
    }
}

public struct IconDocumentLintReport: Equatable, Sendable {
    public var issues: [IconDocumentLintIssue]

    public init(issues: [IconDocumentLintIssue]) {
        self.issues = issues
    }

    public var errors: [IconDocumentLintIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [IconDocumentLintIssue] {
        issues.filter { $0.severity == .warning }
    }

    public var isExportable: Bool {
        errors.isEmpty
    }
}

public struct IconDocumentLinter {
    public init() {}

    public func lint(_ document: IconDocument) -> IconDocumentLintReport {
        let document = IconDocumentSanitizer.sanitized(document)
        var issues: [IconDocumentLintIssue] = []

        if document.layers.isEmpty {
            issues.append(.init(severity: .warning, message: AppIconDesignerLocalization.string("Document has no layers. Export will contain only the background.")))
        }

        if document.width != document.height {
            issues.append(.init(severity: .warning, message: AppIconDesignerLocalization.string("Canvas is not square. App icons work best on a square canvas.")))
        }

        for layer in document.layers {
            if layer.opacity <= 0.01 {
                issues.append(.init(severity: .warning, message: AppIconDesignerLocalization.string("Layer is nearly transparent."), layerId: layer.id))
            }

            if layer.transform.scale < 0.05 {
                issues.append(.init(severity: .warning, message: AppIconDesignerLocalization.string("Layer scale is extremely small."), layerId: layer.id))
            }

            if !shapeHasUsefulSize(layer.shape) {
                issues.append(.init(severity: .error, message: AppIconDesignerLocalization.string("Layer has no useful visible size."), layerId: layer.id))
            }

            if case .text(let value, _, _, let size, _) = layer.shape {
                if value.count > 4 {
                    issues.append(.init(severity: .warning, message: AppIconDesignerLocalization.string("Text layer may be unreadable at small icon sizes."), layerId: layer.id))
                }
                if size < 64 {
                    issues.append(.init(severity: .warning, message: AppIconDesignerLocalization.string("Text size is very small for app icons."), layerId: layer.id))
                }
            }

            if case .symbol(let name, _, _, let size, _) = layer.shape {
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(severity: .error, message: AppIconDesignerLocalization.string("Symbol layer has an empty symbol name."), layerId: layer.id))
                }
                if size < 64 {
                    issues.append(.init(severity: .warning, message: AppIconDesignerLocalization.string("Symbol size is very small for app icons."), layerId: layer.id))
                }
            }
        }

        return IconDocumentLintReport(issues: issues)
    }

    private func shapeHasUsefulSize(_ shape: IconShape) -> Bool {
        switch shape {
        case .rectangle(_, _, let width, let height, _),
             .capsule(_, _, let width, let height),
             .triangle(_, _, let width, let height):
            return width >= 1 && height >= 1
        case .circle(_, _, let radius):
            return radius >= 1
        case .line(let x1, let y1, let x2, let y2):
            return hypot(x2 - x1, y2 - y1) >= 1
        case .symbol(_, _, _, let size, _),
             .text(_, _, _, let size, _):
            return size >= 1
        }
    }
}

public enum IconDocumentLintError: LocalizedError, Equatable {
    case blocked([IconDocumentLintIssue])

    public var errorDescription: String? {
        switch self {
        case .blocked(let issues):
            let messages = issues.map(\.message).joined(separator: " ")
            return AppIconDesignerLocalization.format("Icon document is not exportable. %@", messages)
        }
    }
}
