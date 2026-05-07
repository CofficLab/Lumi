import SwiftUI

/// 编辑器 gutter 装饰层。
///
/// 负责在行号区附近绘制诊断、标记、提示等 gutter 装饰元素，并将可点击
/// 的诊断装饰转发为打开问题的动作。
struct EditorGutterDecorationsOverlayView: View {
    let decorations: [EditorGutterDecoration]
    let openDiagnostic: (Int) -> Void

    var body: some View {
        if !decorations.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(decorations) { decoration in
                    gutterDecorationView(decoration)
                        .frame(width: decoration.rect.width, height: decoration.rect.height)
                        .offset(x: decoration.rect.minX, y: decoration.rect.minY)
                }
            }
        }
    }

    @ViewBuilder
    private func gutterDecorationView(_ decoration: EditorGutterDecoration) -> some View {
        let content = ZStack {
            switch decoration.style.shape {
            case .circle:
                Circle()
                    .fill(decoration.style.fillColor)
                    .overlay(
                        Circle()
                            .stroke(decoration.style.strokeColor, lineWidth: 1)
                    )
            case .roundedRect:
                RoundedRectangle(cornerRadius: decoration.style.cornerRadius)
                    .fill(decoration.style.fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: decoration.style.cornerRadius)
                            .stroke(decoration.style.strokeColor, lineWidth: 1)
                    )
            case .bar:
                Capsule()
                    .fill(decoration.style.fillColor)
                    .overlay(
                        Capsule()
                            .stroke(decoration.style.strokeColor, lineWidth: 0.75)
                    )
            }

            if let badgeText = decoration.badgeText {
                Text(badgeText)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(decoration.style.foregroundColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.horizontal, decoration.style.shape == .bar ? 0 : 1)
            } else if let symbolName = decoration.symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 5.5, weight: .bold))
                    .foregroundColor(decoration.style.foregroundColor)
            }
        }

        if case .diagnostic = decoration.kind {
            Button {
                openDiagnostic(decoration.line)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(String(localized: "Open diagnostic", table: "LumiEditor"))
        } else {
            content
                .allowsHitTesting(false)
        }
    }
}
