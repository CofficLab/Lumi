import SwiftUI
import EditorService
import LumiUI

/// 编辑器内联展示层。
///
/// 负责在源码内容表面绘制内联提示卡片，例如符号状态、辅助说明或轻量提示。
/// 该视图只消费已经计算好的展示模型。
public struct EditorInlinePresentationsOverlayView: View {
    public let presentations: [EditorInlinePresentation]

    public init(presentations: [EditorInlinePresentation]) {
        self.presentations = presentations
    }

    public var body: some View {
        let style = EditorInlinePresentationStyle.standard

        if !presentations.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(presentations) { presentation in
                    HStack(spacing: 6) {
                        Image(systemName: presentation.iconName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(presentation.style.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(presentation.title)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .lineLimit(1)

                            if let detail = presentation.detail {
                                Text(detail)
                                    .font(.system(size: 9))
                                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                    .lineLimit(1)
                            }
                        }

                        if let badgeText = presentation.badgeText {
                            Text(badgeText)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(presentation.style.accentColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(presentation.style.accentColor.opacity(0.12))
                                )
                        }
                    }
                    .foregroundColor(presentation.style.foregroundColor)
                    .padding(.horizontal, style.horizontalPadding)
                    .padding(.vertical, style.verticalPadding)
                    .frame(width: presentation.size.width, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .fill(presentation.style.backgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: style.cornerRadius)
                                    .stroke(
                                        presentation.style.borderColor,
                                        lineWidth: style.borderWidth
                                    )
                            )
                    )
                    .offset(x: presentation.origin.x, y: presentation.origin.y)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                }
            }
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.14), value: presentations.map(\.id))
        }
    }
}
