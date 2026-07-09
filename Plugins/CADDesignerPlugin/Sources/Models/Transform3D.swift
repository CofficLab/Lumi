import Foundation

/// 3D 变换：位置、旋转（欧拉角，度）、统一缩放。
///
/// 型材长度沿 X 轴，截面在 YZ 平面；`rotationY` 控制朝向（绕 Y 轴）。
public struct Transform3D: Codable, Equatable, Sendable {
    public var positionX: Double
    public var positionY: Double
    public var positionZ: Double
    /// 绕 X 轴旋转（度）。
    public var rotationX: Double
    /// 绕 Y 轴旋转（度）。
    public var rotationY: Double
    /// 绕 Z 轴旋转（度）。
    public var rotationZ: Double
    public var scale: Double

    public init(
        positionX: Double = 0,
        positionY: Double = 0,
        positionZ: Double = 0,
        rotationX: Double = 0,
        rotationY: Double = 0,
        rotationZ: Double = 0,
        scale: Double = 1
    ) {
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.rotationZ = rotationZ
        self.scale = scale
    }

    public static let identity = Transform3D()
}
