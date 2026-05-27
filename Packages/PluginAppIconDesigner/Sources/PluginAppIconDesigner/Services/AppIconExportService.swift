import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct AppIconExportService {
    public struct ExportResult: Sendable, Equatable {
        public let appIconSetURL: URL
        public let imageCount: Int
    }

    private struct IconSlot {
        let idiom: String
        let size: Int
        let scale: Int

        var filename: String {
            "icon_\(size)x\(size)@\(scale)x.png"
        }

        var pointSize: String {
            "\(size)x\(size)"
        }
    }

    private static let macSlots: [IconSlot] = [
        IconSlot(idiom: "mac", size: 16, scale: 1),
        IconSlot(idiom: "mac", size: 16, scale: 2),
        IconSlot(idiom: "mac", size: 32, scale: 1),
        IconSlot(idiom: "mac", size: 32, scale: 2),
        IconSlot(idiom: "mac", size: 128, scale: 1),
        IconSlot(idiom: "mac", size: 128, scale: 2),
        IconSlot(idiom: "mac", size: 256, scale: 1),
        IconSlot(idiom: "mac", size: 256, scale: 2),
        IconSlot(idiom: "mac", size: 512, scale: 1),
        IconSlot(idiom: "mac", size: 512, scale: 2),
    ]

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func exportAppIconSet(
        sourceImagePath: String,
        outputDirectory: URL,
        setName: String = "AppIcon"
    ) throws -> ExportResult {
        let sourceURL = URL(fileURLWithPath: sourceImagePath)
        guard let image = NSImage(contentsOf: sourceURL), let cgImage = image.normalizedSquareCGImage() else {
            throw AppIconExportError.invalidSourceImage(sourceImagePath)
        }

        let appIconSetURL = outputDirectory.appendingPathComponent("\(setName).appiconset", isDirectory: true)
        if fileManager.fileExists(atPath: appIconSetURL.path) {
            try fileManager.removeItem(at: appIconSetURL)
        }
        try fileManager.createDirectory(at: appIconSetURL, withIntermediateDirectories: true)

        for slot in Self.macSlots {
            let pixelSize = slot.size * slot.scale
            let data = try renderPNG(cgImage: cgImage, pixelSize: pixelSize)
            try data.write(to: appIconSetURL.appendingPathComponent(slot.filename))
        }

        let contents = contentsJSON(for: Self.macSlots)
        try contents.write(
            to: appIconSetURL.appendingPathComponent("Contents.json"),
            atomically: true,
            encoding: .utf8
        )

        return ExportResult(appIconSetURL: appIconSetURL, imageCount: Self.macSlots.count)
    }

    private func renderPNG(cgImage: CGImage, pixelSize: Int) throws -> Data {
        let width = pixelSize
        let height = pixelSize
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw AppIconExportError.renderFailed(pixelSize)
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let rendered = context.makeImage() else {
            throw AppIconExportError.renderFailed(pixelSize)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw AppIconExportError.renderFailed(pixelSize)
        }

        CGImageDestinationAddImage(destination, rendered, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw AppIconExportError.renderFailed(pixelSize)
        }

        return data as Data
    }

    private func contentsJSON(for slots: [IconSlot]) -> String {
        let images = slots.map { slot in
            """
                {
                  "filename" : "\(slot.filename)",
                  "idiom" : "\(slot.idiom)",
                  "scale" : "\(slot.scale)x",
                  "size" : "\(slot.pointSize)"
                }
            """
        }.joined(separator: ",\n")

        return """
        {
          "images" : [
        \(images)
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }

        """
    }
}

public enum AppIconExportError: LocalizedError, Equatable {
    case invalidSourceImage(String)
    case renderFailed(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidSourceImage(let path):
            return "Invalid source image: \(path)"
        case .renderFailed(let size):
            return "Failed to render \(size)x\(size) icon."
        }
    }
}

private extension NSImage {
    func normalizedSquareCGImage() -> CGImage? {
        guard let best = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let side = min(best.width, best.height)
        let x = (best.width - side) / 2
        let y = (best.height - side) / 2
        return best.cropping(to: CGRect(x: x, y: y, width: side, height: side))
    }
}
