import CoreGraphics
import Foundation
import ImageIO
import ProviderMessage
import UniformTypeIdentifiers

enum ComputerUseImageEncoder {
    struct Encoded: Sendable {
        let attachment: UserImageAttachment
        let width: Int
        let height: Int
    }

    static let maximumDimension = 1_600

    static func encode(_ image: CGImage) throws -> Encoded {
        let scaled = downscale(image, maximumDimension: maximumDimension)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ComputerUseError.captureFailed
        }
        let properties = [
            kCGImageDestinationLossyCompressionQuality: 0.82,
        ] as CFDictionary
        CGImageDestinationAddImage(destination, scaled, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw ComputerUseError.captureFailed
        }
        return Encoded(
            attachment: UserImageAttachment(
                mimeType: "image/jpeg",
                base64Data: (data as Data).base64EncodedString(),
                fileName: "computer-observation-\(UUID().uuidString).jpg"
            ),
            width: scaled.width,
            height: scaled.height
        )
    }

    static func downscale(_ image: CGImage, maximumDimension: Int) -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > maximumDimension, maximumDimension > 0 else { return image }
        let scale = CGFloat(maximumDimension) / CGFloat(longest)
        let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}
