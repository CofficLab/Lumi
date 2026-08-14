import SwiftUI

extension Color {
    /// 根据已用/最大 token 比例返回对应颜色：接近上限时变红。
    static func forTokenUsage(used: Int?, max: Int) -> Color {
        guard let used, max > 0 else { return .secondary }
        let ratio = Double(used) / Double(max)
        if ratio >= 0.9 {
            return .red
        } else if ratio >= 0.75 {
            return .orange
        }
        return .secondary
    }
}
