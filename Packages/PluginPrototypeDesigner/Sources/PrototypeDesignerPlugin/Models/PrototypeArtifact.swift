import Foundation

/// LLM 生成的原型产物：一个可在 `WKWebView` 中渲染的单文件 HTML。
struct PrototypeArtifact: Sendable, Equatable {
    /// 预览画框所模拟的目标设备，决定预览区的最大宽度。
    enum Device: String, CaseIterable, Sendable {
        case iphone
        case ipad
        case desktop

        /// 显示名称。
        var displayName: String {
            switch self {
            case .iphone: "iPhone"
            case .ipad: "iPad"
            case .desktop: "Desktop"
            }
        }

        /// SF Symbol 图标。
        var systemImage: String {
            switch self {
            case .iphone: "iphone"
            case .ipad: "ipad"
            case .desktop: "macwindow"
            }
        }

        /// 预览区建议最大宽度；`nil` 表示占满可用宽度（桌面端）。
        var previewWidth: CGFloat? {
            switch self {
            case .iphone: 390
            case .ipad: 768
            case .desktop: nil
            }
        }
    }

    /// 产物标题（由 LLM 在 `<artifact title="...">` 中声明）。
    let title: String
    /// 目标设备（由 LLM 在 `<artifact device="...">` 中声明，缺失时默认 iPhone）。
    var device: Device
    /// 完整的单文件 HTML（内联 CSS，可选内联 JS）。
    var html: String
}
