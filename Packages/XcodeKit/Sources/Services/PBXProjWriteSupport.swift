import Foundation
import XcodeProj

/// Work around XcodeProj encoder crashes when writing projects with incomplete file metadata.
enum PBXProjWriteSupport {
    /// Ensures file elements referenced during encoding have stable names.
    ///
    /// XcodeProj's `sortProjectReferences` force-unwraps `PBXFileElement.name`, which crashes
    /// when sub-project references only define `path` (a valid Xcode project shape).
    static func prepareForWriting(_ pbxproj: PBXProj) {
        for fileReference in pbxproj.fileReferences {
            ensureDisplayName(for: fileReference)
        }

        for project in pbxproj.projects {
            let sanitizedReferences = project.projects.compactMap { reference -> [String: PBXFileElement]? in
                guard let projectRef = reference["ProjectRef"] else {
                    return nil
                }
                ensureDisplayName(for: projectRef)
                return reference
            }

            if sanitizedReferences.count != project.projects.count {
                project.projects = sanitizedReferences
            }
        }
    }

    static func write(_ xcodeProj: XcodeProj, pathString: String, override: Bool = true) throws {
        prepareForWriting(xcodeProj.pbxproj)
        try xcodeProj.write(pathString: pathString, override: override)
    }

    private static func ensureDisplayName(for element: PBXFileElement) {
        guard element.name == nil else { return }

        if let path = element.path, !path.isEmpty {
            element.name = (path as NSString).lastPathComponent
            return
        }

        element.name = "Unknown"
    }
}
