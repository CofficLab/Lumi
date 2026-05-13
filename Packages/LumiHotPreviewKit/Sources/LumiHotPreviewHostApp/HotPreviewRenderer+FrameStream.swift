import CoreGraphics
import Foundation
import LumiHotPreviewKit

extension HotPreviewRenderer {
    func snapshotToSharedMemory(
        using channel: LumiHotPreviewPackage.SharedMemoryFrameChannel
    ) -> LumiHotPreviewPackage.SharedMemoryFrameChannel.FrameDescriptor? {
        guard let previewView,
              let snapshot = snapshotBitmap(for: previewView),
              let sharedBytes = bgraFrameBytes(for: snapshot.image) else {
            return nil
        }

        return try? channel.writeFrame(
            bytes: sharedBytes.data,
            width: sharedBytes.width,
            height: sharedBytes.height,
            bytesPerRow: sharedBytes.bytesPerRow
        )
    }

    private func bgraFrameBytes(
        for image: CGImage
    ) -> (data: Data, width: Int, height: Int, bytesPerRow: Int)? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerRow = width * 4
        var data = Data(count: bytesPerRow * height)
        let rendered = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
                  ) else {
                return false
            }
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }
        return (data, width, height, bytesPerRow)
    }
}
