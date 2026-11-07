import SwiftUI

/// 标题对齐方式
public enum AppSettingSectionTitleAlignment {
    case leading
    case center
    case trailing
}

/// 分组设置容器。
///
/// - macOS：`GroupBox` 卡片，分组标题位于卡片**内部**，内容为桌面风格的图标行。
/// - iOS：分组列表卡片，标题位于卡片**外部**（灰色小标题），卡片为无描边的
///   圆角底色块，行间带 iOS 风格的发丝分隔线 —— 与 Settings.app 的分组观感一致。
///
/// `footer` 用于承载分组下方的说明文案（iOS 上是分组页脚，macOS 上是卡片下方的脚注）。
public struct AppSettingSection<Content: View>: View {
    let title: String?
    let footer: String?
    let titleAlignment: AppSettingSectionTitleAlignment
    let content: Content

    public init(
        title: String? = nil,
        footer: String? = nil,
        titleAlignment: AppSettingSectionTitleAlignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.titleAlignment = titleAlignment
        self.content = content()
    }

    public var body: some View {
        #if os(iOS) || os(visionOS)
        iosBody
        #else
        macBody
        #endif
    }

    // MARK: - macOS

    private var macBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    if let title {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(
                                maxWidth: .infinity,
                                alignment: titleAlignment == .leading ? .leading : titleAlignment == .center ? .center : .trailing
                            )
                            .padding(.leading, titleAlignment == .leading ? 4 : 0)
                            .padding(.trailing, titleAlignment == .trailing ? 4 : 0)
                    }

                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - iOS

    /// iOS 分组卡片。
    ///
    /// 标题在卡片外侧，卡片内的行自带顶部发丝分隔线；卡片顶部用与卡片同色的
    /// 细条遮住第一行的分隔线，使首行不出现多余的横线。
    private var iosBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(Color.lumiSecondaryLabel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 7)
                    .frame(maxWidth: .infinity, alignment: titleAlignment == .trailing ? .trailing : .leading)
            }

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.lumiGroupedCardBackground)
            }
            .overlay(alignment: .top) {
                // 遮住首行顶部的分隔线（分隔线与标题同为 16pt 起始缩进）。
                Rectangle()
                    .fill(Color.lumiGroupedCardBackground)
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(Color.lumiSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
