import Foundation
import SwiftUI

/// Logo 显示场景
/// 不同的场景可能有不同的视觉要求和动画行为
public enum LogoScene: String, CaseIterable, Sendable {
    case general
    case appIcon
    case about
    /// 系统菜单栏图标：恒为单色模板图（由系统统一着色），无动画。
    case statusBar
    case custom
}