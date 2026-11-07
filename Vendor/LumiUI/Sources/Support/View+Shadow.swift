import SwiftUI

/// Shadow 强度级别
public enum AppShadowLevel: Equatable {
    case none      // 无阴影
    case xs        // 极轻微
    case sm        // 轻微
    case md        // 中等
    case lg        // 较强
    case xl        // 强
    case xxl       // 极强
    case xxxl      // 超强

    var color: Color {
        switch self {
        case .none: return .clear
        case .xs: return .black.opacity(0.02)
        case .sm: return .black.opacity(0.04)
        case .md: return .black.opacity(0.06)
        case .lg: return .black.opacity(0.10)
        case .xl: return .black.opacity(0.15)
        case .xxl: return .black.opacity(0.20)
        case .xxxl: return .black.opacity(0.25)
        }
    }

    var radius: CGFloat {
        switch self {
        case .none: return 0
        case .xs: return 2
        case .sm: return 4
        case .md: return 6
        case .lg: return 8
        case .xl: return 12
        case .xxl: return 16
        case .xxxl: return 20
        }
    }

    var y: CGFloat {
        switch self {
        case .none: return 0
        case .xs: return 1
        case .sm: return 2
        case .md: return 3
        case .lg: return 4
        case .xl: return 6
        case .xxl: return 8
        case .xxxl: return 10
        }
    }

    /// 承接阴影的高度：与 `radius` 成正比，覆盖阴影自然衰减的范围。
    var undershadowHeight: CGFloat {
        ceil(radius * 2.5) + y
    }
}

/// View 阴影扩展
public extension View {
    /// 应用指定级别的阴影
    func appShadow(_ level: AppShadowLevel) -> some View {
        shadow(color: level.color, radius: level.radius, y: level.y)
    }
    
    /// 无阴影
    func shadowNone() -> some View {
        appShadow(.none)
    }
    
    /// 极轻微阴影
    func shadowXs() -> some View {
        appShadow(.xs)
    }
    
    /// 轻微阴影
    func shadowSm() -> some View {
        appShadow(.sm)
    }
    
    /// 中等阴影
    func shadowMd() -> some View {
        appShadow(.md)
    }
    
    /// 较强阴影
    func shadowLg() -> some View {
        appShadow(.lg)
    }
    
    /// 强阴影
    func shadowXl() -> some View {
        appShadow(.xl)
    }
    
    /// 极强阴影
    func shadowXxl() -> some View {
        appShadow(.xxl)
    }
    
    /// 超强阴影
    func shadowXxxl() -> some View {
        appShadow(.xxxl)
    }
}
