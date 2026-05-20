import Foundation

public extension LumiPreviewFacade {
    /// 跨进程帧描述符：承载 `IOSurfaceID` + 像素元信息 + 单调递增序号。
    ///
    /// - `surfaceID`：32 位全局 ID，主进程通过 `IOSurfaceLookup(_:)` 即可拿到 `IOSurfaceRef`。
    /// - `seq`：用于丢弃过期帧；任何更小的 seq 都应忽略。
    struct IOSurfaceFrame: Codable, Sendable, Equatable {

        // MARK: - 属性

        public let surfaceID: UInt32
        public let width: Int
        public let height: Int
        public let scale: Double
        public let seq: UInt64

        // MARK: - 初始化

        public init(
            surfaceID: UInt32,
            width: Int,
            height: Int,
            scale: Double,
            seq: UInt64
        ) {
            self.surfaceID = surfaceID
            self.width = width
            self.height = height
            self.scale = scale
            self.seq = seq
        }
    }
}
