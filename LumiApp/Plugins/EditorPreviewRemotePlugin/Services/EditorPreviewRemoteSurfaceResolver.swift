import IOSurface
import LumiPreviewKit

enum EditorPreviewRemoteSurfaceResolver {
    struct ResolvedSurface {
        let surface: IOSurfaceRef
        let width: Int
        let height: Int
        let scale: Double
        let pixelFormat: String
        let bytesPerRow: Int
    }

    static func canResolve(_ frame: LumiPreviewPackage.PreviewSurfaceFrame?) -> Bool {
        guard let frame else { return false }
        return resolve(frame) != nil
    }

    static func resolve(_ frame: LumiPreviewPackage.PreviewSurfaceFrame) -> ResolvedSurface? {
        guard frame.pixelFormat == "BGRA" else {
            return nil
        }
        switch frame.transport {
        case let .globalIOSurfaceID(surfaceID):
            return resolveGlobalIOSurfaceID(surfaceID, frame: frame)
        case .unsupported:
            return nil
        }
    }

    private static func resolveGlobalIOSurfaceID(
        _ surfaceID: UInt32,
        frame: LumiPreviewPackage.PreviewSurfaceFrame
    ) -> ResolvedSurface? {
        guard let surface = IOSurfaceLookup(IOSurfaceID(surfaceID)) else {
            return nil
        }
        return ResolvedSurface(
            surface: surface,
            width: frame.width,
            height: frame.height,
            scale: frame.scale,
            pixelFormat: frame.pixelFormat,
            bytesPerRow: frame.bytesPerRow
        )
    }
}
