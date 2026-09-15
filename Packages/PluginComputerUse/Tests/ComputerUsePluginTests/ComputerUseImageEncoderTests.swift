import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import ComputerUsePlugin

@Test func imageEncoderDownscalesAndReturnsReadableJPEGAttachment() throws {
    let image = try #require(makeTestImage(width: 2_400, height: 1_200))
    let encoded = try ComputerUseImageEncoder.encode(image)

    #expect(encoded.width == 1_600)
    #expect(encoded.height == 800)
    #expect(encoded.attachment.mimeType == "image/jpeg")
    let fileName = try #require(encoded.attachment.fileName)
    #expect(fileName.hasPrefix("computer-observation-"))
    #expect(fileName.hasSuffix(".jpg"))

    let data = try #require(Data(base64Encoded: encoded.attachment.base64Data))
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(decoded.width == encoded.width)
    #expect(decoded.height == encoded.height)
}

@Test func downscalePreservesSmallImagesAndHandlesNonPositiveLimit() throws {
    let image = try #require(makeTestImage(width: 320, height: 180))

    #expect(ComputerUseImageEncoder.downscale(image, maximumDimension: 1_600) === image)
    #expect(ComputerUseImageEncoder.downscale(image, maximumDimension: 0) === image)
}

private func makeTestImage(width: Int, height: Int) -> CGImage? {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.setFillColor(red: 0.3, green: 0.6, blue: 0.8, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
}
