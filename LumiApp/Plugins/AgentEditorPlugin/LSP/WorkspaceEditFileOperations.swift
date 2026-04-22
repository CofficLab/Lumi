import Foundation
import LanguageServerProtocol

enum WorkspaceEditFileOperations {
    static func applyCreateFile(_ operation: CreateFile) -> Bool {
        applyCreateFile(
            uri: operation.uri,
            overwrite: operation.options?.overwrite == true,
            ignoreIfExists: operation.options?.ignoreIfExists == true
        )
    }

    static func applyRenameFile(_ operation: RenameFile) -> Bool {
        applyRenameFile(
            oldURI: operation.oldUri,
            newURI: operation.newUri,
            overwrite: operation.options.overwrite == true,
            ignoreIfExists: operation.options.ignoreIfExists == true
        )
    }

    static func applyDeleteFile(_ operation: DeleteFile) -> Bool {
        applyDeleteFile(
            uri: operation.uri,
            recursive: operation.options.recursive == true,
            ignoreIfNotExists: operation.options.ignoreIfNotExists == true
        )
    }

    static func applyCreateFile(uri: String, overwrite: Bool, ignoreIfExists: Bool) -> Bool {
        guard let fileURL = fileURL(from: uri) else { return false }
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: fileURL.path)

        if exists {
            if overwrite {
                do {
                    try fm.removeItem(at: fileURL)
                } catch {
                    return false
                }
            } else if ignoreIfExists {
                return true
            } else {
                return false
            }
        }

        do {
            try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            return false
        }
        return fm.createFile(atPath: fileURL.path, contents: nil)
    }

    static func applyRenameFile(
        oldURI: String,
        newURI: String,
        overwrite: Bool,
        ignoreIfExists: Bool
    ) -> Bool {
        guard let oldURL = fileURL(from: oldURI),
              let newURL = fileURL(from: newURI) else { return false }

        let fm = FileManager.default
        let oldExists = fm.fileExists(atPath: oldURL.path)
        if !oldExists {
            return ignoreIfExists
        }

        let newExists = fm.fileExists(atPath: newURL.path)
        if newExists {
            if overwrite {
                do {
                    try fm.removeItem(at: newURL)
                } catch {
                    return false
                }
            } else if ignoreIfExists {
                return true
            } else {
                return false
            }
        }

        do {
            try fm.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: oldURL, to: newURL)
            return true
        } catch {
            return false
        }
    }

    static func applyDeleteFile(uri: String, recursive: Bool, ignoreIfNotExists: Bool) -> Bool {
        guard let targetURL = fileURL(from: uri) else { return false }
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: targetURL.path)
        if !exists {
            return ignoreIfNotExists
        }

        do {
            var isDirectory: ObjCBool = false
            fm.fileExists(atPath: targetURL.path, isDirectory: &isDirectory)

            if isDirectory.boolValue, !recursive {
                let entries = try fm.contentsOfDirectory(atPath: targetURL.path)
                if !entries.isEmpty {
                    return false
                }
            }

            try fm.removeItem(at: targetURL)
            return true
        } catch {
            return false
        }
    }

    static func fileURL(from uri: String) -> URL? {
        if uri.hasPrefix("/") {
            return URL(fileURLWithPath: uri).standardizedFileURL
        }
        guard let url = URL(string: uri) else { return nil }
        if url.isFileURL {
            return url.standardizedFileURL
        }
        return nil
    }
}
