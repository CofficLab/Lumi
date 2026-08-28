import Foundation
import ImageIO

public struct ResumeImportedAsset: Equatable, Sendable {
    public let fileURL: URL
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

public enum ResumeAssetError: LocalizedError, Equatable {
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

public struct ResumeAssetImporter: Sendable {
    public init() {}

    public func importImage(
        sourceURL: URL,
        destinationDirectory: URL,
        preferredFileName: String? = nil,
        fileManager: FileManager = .default
    ) throws -> ResumeImportedAsset {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw ResumeAssetError.sourceNotFound(sourceURL.path)
        }
        let values = try sourceURL.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = Int64(values.fileSize ?? 0)
        guard fileSize <= 50 * 1024 * 1024 else { throw ResumeAssetError.fileTooLarge(fileSize) }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw ResumeAssetError.unsupportedImage(sourceURL.path)
        }

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let requested = Self.safeFileName(preferredFileName ?? sourceURL.lastPathComponent)
        let destination = Self.availableURL(named: requested, in: destinationDirectory, fileManager: fileManager)
        try fileManager.copyItem(at: sourceURL, to: destination)
        return ResumeImportedAsset(
            fileURL: destination,
            relativePath: "./assets/\(destination.lastPathComponent)",
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
