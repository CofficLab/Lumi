import Foundation

public extension LumiPreviewFacade {
    /// PNG 帧文件持久化存储。
    ///
    /// 将 Base64 编码的 PNG 帧数据写入磁盘文件，使 UI 层可以通过文件路径
    /// 加载图片，而非在 JSON 响应中内嵌大量 Base64 数据。
    struct FrameFileStore: @unchecked Sendable {
        private let fileManager: FileManager
        private let directory: URL

        /// 创建帧文件存储器。
        ///
        /// - Parameters:
        ///   - directory: 帧文件存储目录，默认使用 `ImageFileLoader.defaultFrameDirectory()`。
        ///   - fileManager: 文件管理器。
        public init(
            directory: URL = ImageFileLoader.defaultFrameDirectory(),
            fileManager: FileManager = .default
        ) {
            self.directory = directory
            self.fileManager = fileManager
        }

        /// 将 Base64 编码的 PNG 数据写入磁盘文件。
        ///
        /// - Parameters:
        ///   - base64EncodedPNG: Base64 编码的 PNG 数据。
        ///   - previewID: 可选的预览标识符，用于生成文件名前缀。
        /// - Returns: 写入的文件 URL。
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
