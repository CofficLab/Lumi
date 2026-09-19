import Foundation
import ImageIO

/// 导入到项目级 `assets/` 目录后的素材信息。
public struct PrototypeImportedAsset: Equatable, Sendable {
    public let fileURL: URL
    /// 供 HTML 引用的相对路径（屏幕在子目录，因此用 `../assets/`）。
    public let relativePath: String
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(fileURL: URL, relativePath: String, pixelWidth: Int, pixelHeight: Int) {
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public enum PrototypeAssetError: LocalizedError, Equatable {
    case sourceNotFound(String)
    case unsupportedImage(String)
    case fileTooLarge(Int64)

    public var errorDescription: String? {
        switch self {
        case .sourceNotFound(let path): "Asset does not exist: \(path)"
        case .unsupportedImage(let path): "Asset is not a supported image: \(path)"
        case .fileTooLarge(let bytes): "Asset exceeds the 50 MB limit (\(bytes) bytes)."
        }
    }
}

/// 把本地图片复制进原型项目的共享素材目录。
///
/// 素材放在项目级 `assets/` 而不是每屏各一份：原型里同一张产品截图
/// 常出现在多屏，共享目录避免重复占空间，也让替换素材一次生效。
public struct PrototypeAssetImporter: Sendable {
    public init() {}

    public func importImage(
        sourceURL: URL,
        destinationDirectory: URL,
        preferredFileName: String? = nil,
        fileManager: FileManager = .default
    ) throws -> PrototypeImportedAsset {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw PrototypeAssetError.sourceNotFound(sourceURL.path)
        }
        let values = try sourceURL.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = Int64(values.fileSize ?? 0)
        guard fileSize <= 50 * 1024 * 1024 else { throw PrototypeAssetError.fileTooLarge(fileSize) }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw PrototypeAssetError.unsupportedImage(sourceURL.path)
        }

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let requested = Self.safeFileName(preferredFileName ?? sourceURL.lastPathComponent)
        let destination = Self.availableURL(named: requested, in: destinationDirectory, fileManager: fileManager)
        try fileManager.copyItem(at: sourceURL, to: destination)
        return PrototypeImportedAsset(
            fileURL: destination,
            relativePath: "../assets/\(destination.lastPathComponent)",
            pixelWidth: width,
            pixelHeight: height
        )
    }

    private static func safeFileName(_ raw: String) -> String {
        let last = URL(fileURLWithPath: raw).lastPathComponent
        let safe = last.replacingOccurrences(of: #"[^A-Za-z0-9._-]+"#, with: "-", options: .regularExpression)
        return safe.isEmpty ? "asset.png" : safe
    }

    private static func availableURL(named name: String, in directory: URL, fileManager: FileManager) -> URL {
        let original = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: original.path) else { return original }
        let stem = original.deletingPathExtension().lastPathComponent
        let ext = original.pathExtension
        for index in 2...999 {
            let candidateName = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        return directory.appendingPathComponent("\(UUID().uuidString)-\(name)")
    }
}
