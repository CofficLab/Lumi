import Foundation

public extension LumiHotPreviewPackage {
    /// Persists PNG frame payloads so the UI can load them from disk instead of JSON Base64.
    struct FrameFileStore: @unchecked Sendable {
        private let fileManager: FileManager
        private let directory: URL

        public init(
            directory: URL = ImageFileLoader.defaultFrameDirectory(),
            fileManager: FileManager = .default
        ) {
            self.directory = directory
            self.fileManager = fileManager
        }

        public func writePNG(base64EncodedPNG: String, previewID: String? = nil) throws -> URL {
            guard let data = Data(base64Encoded: base64EncodedPNG) else {
                throw CocoaError(.coderInvalidValue)
            }

            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent(fileName(previewID: previewID))
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        }

        private func fileName(previewID: String?) -> String {
            let baseName = sanitized(previewID) ?? "preview"
            return "\(baseName)-\(UUID().uuidString).png"
        }

        private func sanitized(_ previewID: String?) -> String? {
            guard let previewID,
                  !previewID.isEmpty else {
                return nil
            }

            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
            let scalars = previewID.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
            let value = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            return value.isEmpty ? nil : value
        }
    }
}
