import Foundation
import UniformTypeIdentifiers

public enum FilePreviewKind: Equatable {
    case image
    case pdf
    case quickLook
}

public enum FilePreviewResolver {
    public static func previewKind(for fileURL: URL) -> FilePreviewKind {
        let ext = fileURL.pathExtension.lowercased()
        let utType = ext.isEmpty ? nil : UTType(filenameExtension: ext)

        if utType?.conforms(to: .image) == true {
            return .image
        }
        if utType?.conforms(to: .pdf) == true || ext == "pdf" {
            return .pdf
        }
        return .quickLook
    }
}
