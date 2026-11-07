import SwiftUI

/// Image扩展 - 提供便捷的图标创建和样式配置方法
public extension Image {
    /// 创建系统图标的便捷方法
    /// - Parameter systemName: 系统图标名称
    /// - Returns: 配置了合适样式的Image
    static func system(_ systemName: String) -> Image {
        Image(systemName: systemName)
    }

    /// 创建系统图标并应用标准样式
    /// - Parameters:
    ///   - systemName: 系统图标名称
    ///   - style: 图标样式
    /// - Returns: 配置了样式的Image
    static func system(_ systemName: String, style: IconStyle) -> some View {
        Image(systemName: systemName)
            .applyIconStyle(style)
    }
}

/// 图标样式枚举
public enum IconStyle {
    /// 小图标样式 (16pt)
    case small
    /// 中等图标样式 (24pt)
    case medium
    /// 大图标样式 (32pt)
    case large
    /// 超大图标样式 (48pt)
    case xlarge
    /// 特大图标样式 (64pt)
    case xxlarge
    /// 自定义大小
    case custom(CGFloat)
}

/// 图标样式扩展
private extension Image {
    func applyIconStyle(_ style: IconStyle) -> some View {
        Group {
            switch style {
            case .small:
                self.font(.system(size: 16))
            case .medium:
                self.font(.system(size: 24))
            case .large:
                self.font(.system(size: 32))
            case .xlarge:
                self.font(.system(size: 48))
            case .xxlarge:
                self.font(.system(size: 64))
            case .custom(let size):
                self.font(.system(size: size))
            }
        }
    }
}

/// 常用图标常量
public extension Image {
    /// 成功图标
    static var successIcon: Image {
        Image(systemName: "checkmark.circle.fill")
    }

    /// 错误图标
    static var errorIcon: Image {
        Image(systemName: "xmark.circle.fill")
    }

    /// 警告图标
    static var warningIcon: Image {
        Image(systemName: "exclamationmark.triangle.fill")
    }

    /// 信息图标
    static var infoIcon: Image {
        Image(systemName: "info.circle.fill")
    }

    /// 加载中图标
    static var loadingIcon: Image {
        Image(systemName: "circle")
    }

    /// 复制图标
    static var copyIcon: Image {
        Image(systemName: "doc.on.doc")
    }

    /// 关闭图标
    static var closeIcon: Image {
        Image(systemName: "xmark.circle.fill")
    }

    /// 文本气泡图标
    static var textBubbleIcon: Image {
        Image(systemName: "text.bubble")
    }

    /// 手势点击图标
    static var handTapIcon: Image {
        Image(systemName: "hand.tap")
    }
}

/// Toast相关的图标扩展
extension Image {
    /// 根据Toast类型获取对应的图标
    /// - Parameter type: Toast类型
    /// - Returns: 对应的图标
    static func icon(for type: MagicToastType) -> Image {
        switch type {
        case .success:
            return successIcon
        case .error:
            return errorIcon
        case .warning:
            return warningIcon
        case .info:
            return infoIcon
        case .loading:
            return loadingIcon
        case .errorDetail:
            return errorIcon
        case .custom(let systemImage, _):
            return Image(systemName: systemImage)
        }
    }
}

#if DEBUG
    #Preview("图标样式预览") {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VStack {
                    Image.successIcon
                        .foregroundStyle(.green)
                    Text("成功").font(.caption)
                }

                VStack {
                    Image.errorIcon
                        .foregroundStyle(.red)
                    Text("错误").font(.caption)
                }

                VStack {
                    Image.warningIcon
                        .foregroundStyle(.orange)
                    Text("警告").font(.caption)
                }

                VStack {
                    Image.infoIcon
                        .foregroundStyle(.blue)
                    Text("信息").font(.caption)
                }
            }

            HStack(spacing: 20) {
                VStack {
                    Image.system("star.fill", style: .small)
                        .foregroundStyle(.yellow)
                    Text("小图标").font(.caption)
                }

                VStack {
                    Image.system("heart.fill", style: .medium)
                        .foregroundStyle(.pink)
                    Text("中图标").font(.caption)
                }

                VStack {
                    Image.system("moon.fill", style: .large)
                        .foregroundStyle(.purple)
                    Text("大图标").font(.caption)
                }
            }

            HStack(spacing: 20) {
                VStack {
                    Image.copyIcon
                        .foregroundStyle(.blue)
                    Text("复制").font(.caption)
                }

                VStack {
                    Image.closeIcon
                        .foregroundStyle(.gray)
                    Text("关闭").font(.caption)
                }

                VStack {
                    Image.loadingIcon
                        .foregroundStyle(.blue)
                    Text("加载").font(.caption)
                }
            }
        }
        .padding()
    }
#endif
