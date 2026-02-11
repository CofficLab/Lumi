import SwiftUI

// MARK: - 材质系统
extension DesignTokens {
    /// 材质令牌 - 定义背景材质和毛玻璃效果
    enum Material {
        /// 玻璃态材质 (超薄)
        static let glass = SwiftUI.Material.ultraThinMaterial
        /// 玻璃态材质 (薄)
        static let glassThick = SwiftUI.Material.thinMaterial
        /// 玻璃态材质 (极薄)
        static let glassThin = SwiftUI.Material.ultraThinMaterial

        /// 神秘氛围材质（带深色叠加）
        /// - Parameter opacity: 透明度
        /// - Returns: 形状样式
        static func mysticGlass(opacity: Double = 0.3) -> some ShapeStyle {
            SwiftUI.Color.black.opacity(opacity)
        }
    }
}
