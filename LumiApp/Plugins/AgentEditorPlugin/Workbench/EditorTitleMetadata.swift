import Foundation

struct EditorTitleMetadata: Equatable {
    enum Badge: String, Equatable, CaseIterable {
        case preview
        case pinned
        case dirty
        case readOnly

        var title: String {
            switch self {
            case .preview:
                return "Preview"
            case .pinned:
                return "Pinned"
            case .dirty:
                return "Dirty"
            case .readOnly:
                return "Read-Only"
            }
        }
    }

    let title: String
    let subtitle: String?
    let languageLabel: String
    let badges: [Badge]

    static func build(
        fileURL: URL?,
        projectRootPath: String?,
        fileName: String,
        fileExtension: String,
        detectedLanguageName: String?,
        isPreview: Bool,
        isPinned: Bool,
        isDirty: Bool,
        isEditable: Bool
    ) -> EditorTitleMetadata {
        let resolvedTitle = resolvedTitle(fileURL: fileURL, fileName: fileName)
        let relativePath = resolvedRelativePath(fileURL: fileURL, projectRootPath: projectRootPath)
        let subtitle = resolvedSubtitle(relativePath: relativePath, title: resolvedTitle)

        var badges: [Badge] = []
        if isPreview { badges.append(.preview) }
        if isPinned { badges.append(.pinned) }
        if isDirty { badges.append(.dirty) }
        if !isEditable { badges.append(.readOnly) }

        return EditorTitleMetadata(
            title: resolvedTitle,
            subtitle: subtitle,
            languageLabel: resolvedLanguageLabel(
                detectedLanguageName: detectedLanguageName,
                fileExtension: fileExtension,
                fileURL: fileURL
            ),
            badges: badges
        )
    }

    private static func resolvedTitle(fileURL: URL?, fileName: String) -> String {
        if !fileName.isEmpty {
            return fileName
        }
        if let fileURL {
            return fileURL.lastPathComponent
        }
        return "Untitled"
    }

    private static func resolvedRelativePath(fileURL: URL?, projectRootPath: String?) -> String? {
        guard let fileURL else { return nil }
        guard let projectRootPath, !projectRootPath.isEmpty else {
            return fileURL.deletingLastPathComponent().path
        }

        let absolutePath = fileURL.path
        guard absolutePath.hasPrefix(projectRootPath) else {
            return fileURL.deletingLastPathComponent().path
        }

        var relative = String(absolutePath.dropFirst(projectRootPath.count))
        if relative.hasPrefix("/") {
            relative.removeFirst()
        }

        let components = relative.split(separator: "/")
        guard !components.isEmpty else { return nil }
        let parentComponents = components.dropLast()
        guard !parentComponents.isEmpty else { return nil }
        return parentComponents.joined(separator: "/")
    }

    private static func resolvedSubtitle(relativePath: String?, title: String) -> String? {
        guard let relativePath, !relativePath.isEmpty, relativePath != title else { return nil }
        return relativePath
    }

    private static func resolvedLanguageLabel(
        detectedLanguageName: String?,
        fileExtension: String,
        fileURL: URL?
    ) -> String {
        if let detectedLanguageName, !detectedLanguageName.isEmpty {
            return humanizedLanguageName(detectedLanguageName)
        }
        if !fileExtension.isEmpty {
            return fileExtension.uppercased()
        }
        if fileURL?.pathExtension.isEmpty == false {
            return fileURL?.pathExtension.uppercased() ?? "Plain Text"
        }
        return "Plain Text"
    }

    private static func humanizedLanguageName(_ name: String) -> String {
        let normalized = name
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        if normalized.lowercased() == "plaintext" || normalized.lowercased() == "plain text" {
            return "Plain Text"
        }
        return normalized
            .split(separator: " ")
            .map { segment in
                let lower = segment.lowercased()
                switch lower {
                case "jsx", "tsx", "json", "yaml", "toml", "sql", "html", "css", "md", "mdx":
                    return lower.uppercased()
                default:
                    return lower.prefix(1).uppercased() + lower.dropFirst()
                }
            }
            .joined(separator: " ")
    }
}
